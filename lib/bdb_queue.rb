
require 'rubygems'
require 'bdb'

class BDBQueue

  def initialize(directory='.stompserver')
    @directory = directory
    @system_id = nil
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @sfr = StompFrameRecognizer.new
    @active = BDB::Hash.open("#{@directory}/queues.db", nil, "a")
    @queues = Hash.new
    @active.keys.each {|dest| open_queue(dest)}
  end

  def stop
    p "Shutting down BDBQueue.  #{@active.size} active queues"
    @active.keys.each {|dest| close_queue(dest)}
    @active.close
  end

  def set_system_id(id)
    @system_id = id
  end

  def open_queue(dest)
    @queues[dest] = Hash.new
    queue_name = dest.gsub('/', '_')
    queue_dbname = @directory + '/' + queue_name + '_queue.db'
    store_dbname = @directory + '/' + queue_name + '_store.db'
    @queues[dest][:queue] = BDB::Queue.new("#{queue_dbname}", nil, "a")
    @queues[dest][:store] = BDB::Hash.new("#{store_dbname}", nil, "a")
    @queues[dest][:queue_dbname] = queue_dbname
    @queues[dest][:store_dbname] = store_dbname
    @active[dest] = true
  end


  def close_queue(dest)
    qsize = @queues[dest][:queue].size
    @queues[dest][:queue].close
    @queues[dest][:store].close
    if qsize == 0
      File.delete(@queues[dest][:queue_dbname]) if File.exists?(@queues[dest][:queue_dbname])
      File.delete(@queues[dest][:store_dbname]) if File.exists?(@queues[dest][:store_dbname])
      @active.delete(dest)
      p "Removing queue #{dest}" if $DEBUG
    else
      p "Closing queue #{dest} with #{qsize} saved messages" if $DEBUG
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    id = @queues[dest][:queue].push dest
    msgid = @system_id + id.to_s
    frame.headers['message-id'] = msgid
    @queues[dest][:store][id[0]] = frame
  end

  def dequeue(dest)
    open_queue(dest) unless @queues.has_key?(dest)
    if queue = @queues[dest][:queue].shift
      frame_text = @queues[dest][:store][queue[0]]
      @queues[dest][:store].delete(queue[0])
      @sfr << frame_text
      @sfr.frames.shift
    else
      return false
    end
  end

end

