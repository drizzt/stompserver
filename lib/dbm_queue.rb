

require 'rubygems'


class DBMQueue

  def initialize(directory='.stompserver')

    # Please don't use dbm files for storing large frames, it's problematic at best and uses large amounts of memory.
    # dbm isn't available on windows, and sdbm croaks on marshalled data that contains certain characters.
    @dbm = false
    if RUBY_PLATFORM =~/linux|bsd/
      types = ['bdb','dbm','gdbm']
    else
      types = ['bdb','gdbm']
    end
    types.each do |dbtype|
      begin
        require dbtype
        @dbm = dbtype
        break
      rescue LoadError => e
      end
    end
    raise "No DBM library found. Tried bdb,dbm,sdbm,gdbm" unless @dbm

    @directory = directory
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @qindex = @directory + '/queues'
    @stompid = StompId.new
    @active = dbmopen(@qindex)
    @queues = Hash.new
    p "DBMQueue type=#{@dbm} directory=#{@directory}"
    @active.keys.each {|dest| open_queue(dest)}
  end

  def stop
    p "Shutting down DBMQueue"
    @active.keys.each {|dest| close_queue(dest)}
    size = @active.size
    @active.close
    dbmremove(@qindex) if size == 0
  end

  def dbmremove(dbname)
      File.delete(dbname) if File.exists?(dbname)
      File.delete("#{dbname}.db") if File.exists?("#{dbname}.db")
      File.delete("#{dbname}.pag") if File.exists?("#{dbname}.pag")
      File.delete("#{dbname}.dir") if File.exists?("#{dbname}.dir")
  end

  def dbmopen(dbname)
    if @dbm == 'bdb'
      BDB::Hash.new(dbname, nil, "a")
    elsif @dbm == 'dbm'
      DBM.open(dbname)
    elsif @dbm == 'sdbm'
      SDBM.open(dbname)
    elsif @dbm == 'gdbm'
      GDBM.open(dbname)
    end
  end


  def monitor
    stats = Hash.new
    @active.keys.each do |dest|
      qsize,dequeued,enqueued = getstats(dest)
      stats[dest] = {'size' => qsize, 'enqueued' => enqueued, 'dequeued' => dequeued}
    end
    stats
  end

  def open_queue(dest)
    queue_name = dest.gsub('/', '_')
    raise "Queuename #{dest} is reserved" if queue_name =~/in_idx|out_idx/
    @queues[dest] = Hash.new
    dbname = @directory + '/' + queue_name
    @queues[dest]['queue'] = dbmopen(dbname)
    @queues[dest]['dbname'] = dbname
    unless @queues[dest]['queue']['in_idx'] 
      @queues[dest]['queue']['in_idx'] = '0'
    end
    unless @queues[dest]['queue']['out_idx'] 
      @queues[dest]['queue']['out_idx'] = '1'
    end
    @active[dest] = '1'
    qsize,dequeued,enqueued = getstats(dest)
    p "Opened queue #{dest} size=#{qsize}  enqueued=#{enqueued} dequeued=#{dequeued}" if $DEBUG
  end

  def getstats(dest)
    size = @queues[dest]['queue'].size
    size -= 2
    dequeued = @queues[dest]['queue']['out_idx'].to_i - 1
    enqueued = @queues[dest]['queue']['in_idx'].to_i
    return size,dequeued,enqueued
  end

  def close_queue(dest)
    qsize,dequeued,enqueued = getstats(dest)
    p "Closing queue #{dest} size=#{qsize}  enqueued=#{enqueued} dequeued=#{dequeued}" if $DEBUG
    @queues[dest]['queue'].close
    if qsize == 0
      dbmremove(@queues[dest]['dbname'])
      @active.delete(dest)
      p "Removed queue #{dest}" if $DEBUG
    else
      p "Closed queue #{dest}" if $DEBUG
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    in_idx = @queues[dest]['queue']['in_idx'].to_i + 1
    in_idx = in_idx.to_s
    @queues[dest]['queue']['in_idx'] = in_idx
    msgid = @stompid[in_idx]
    frame.headers['message-id'] = msgid
    @queues[dest]['queue'][in_idx] = Marshal::dump(frame)
  end

  def dequeue(dest)
    open_queue(dest) unless @queues.has_key?(dest)
    out_idx = @queues[dest]['queue']['out_idx']
    if frame_text = @queues[dest]['queue'][out_idx]
      frame = Marshal::load(frame_text)
      @queues[dest]['queue'].delete(out_idx)
      out_idx = @queues[dest]['queue']['out_idx'].to_i + 1
      out_idx = out_idx.to_s
      @queues[dest]['queue']['out_idx'] = out_idx
      return frame
    else
      return false
    end
  end

end

