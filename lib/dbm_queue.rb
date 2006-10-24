

require 'rubygems'
require 'dbm'

class DBMQueue

  def initialize(directory='.stompserver')
    @directory = directory
    @stompid = StompId.new
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @sfr = StompFrameRecognizer.new
    @active = DBM.open("#{@directory}/queues")
    @queues = Hash.new
    @active.keys.each {|dest| open_queue(dest)}
    p "DBMQueue initialized in #{@directory}"
  end

  def stop
    p "Shutting down DBMQueue"
    @active.keys.each {|dest| close_queue(dest)}
    @active.close
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
    @queues[dest]['queue'] = DBM.open("#{dbname}")
    @queues[dest]['dbname'] = dbname
    unless @queues[dest]['queue']['in_idx'] 
      @queues[dest]['queue']['in_idx'] = 0
    end
    unless @queues[dest]['queue']['out_idx'] 
      @queues[dest]['queue']['out_idx'] = 1
    end
    @active[dest] = true
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
      File.delete("#{@queues[dest]['dbname']}.db") if File.exists?("#{@queues[dest]['dbname']}.db")
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
    @queues[dest]['queue']['in_idx'] = in_idx
    msgid = @stompid[in_idx]
    frame.headers['message-id'] = msgid
    @queues[dest]['queue'][in_idx] = frame
  end

  def dequeue(dest)
    open_queue(dest) unless @queues.has_key?(dest)
    out_idx = @queues[dest]['queue']['out_idx']
    if frame_text = @queues[dest]['queue'][out_idx]
      @sfr << frame_text
      if frame = @sfr.frames.shift
        @queues[dest]['queue'].delete(out_idx)
        @queues[dest]['queue']['out_idx'] = @queues[dest]['queue']['out_idx'].to_i + 1
        return frame
      else
       return false
      end
    else
      return false
    end
  end

end

