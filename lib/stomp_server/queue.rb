
module StompServer
class Queue

  def initialize(directory='.stompserver', delete_empty=true)
    @stompid = StompServer::StompId.new
    @delete_empty = delete_empty
    @directory = directory
    Dir.mkdir(@directory) unless File.directory?(@directory)
    if File.exists?("#{@directory}/qinfo")
      qinfo = Hash.new
      File.open("#{@directory}/qinfo", "rb") { |f| qinfo = Marshal.load(f.read)}
      @queues = qinfo[:queues]
      @frames = qinfo[:frames]
    else
      @queues = Hash.new
      @frames = Hash.new
    end

    @queues.keys.each do |dest| 
      puts "Queue #{dest} size=#{@queues[dest][:size]} enqueued=#{@queues[dest][:enqueued]} dequeued=#{@queues[dest][:dequeued]}" if $DEBUG
    end

    puts "Queue initialized in #{@directory}"

    # Cleanup dead queues and save the state of the queues every so often.  Alternatively we could save the queue state every X number
    # of frames that are put in the queue.  Should probably also read it after saving it to confirm integrity.
    EventMachine::add_periodic_timer 1800, proc {@queues.keys.each {|dest| close_queue(dest)};save_queue_state }
  end

  def stop
    puts "Shutting down Queue"

    @queues.keys.each {|dest| close_queue(dest)}
    @queues.keys.each do |dest|
      puts "Queue #{dest} size=#{@queues[dest][:size]} enqueued=#{@queues[dest][:enqueued]} dequeued=#{@queues[dest][:dequeued]}" if $DEBUG
    end
    save_queue_state
  end

  def save_queue_state
    puts "Saving Queue State" if $DEBUG
    qinfo = {:queues => @queues, :frames => @frames}
    File.open("#{@directory}/qinfo", "wb") { |f| f.write Marshal.dump(qinfo)}
  end

  def monitor
    stats = Hash.new
    @queues.keys.each do |dest| 
      stats[dest] = {'size' => @queues[dest][:size], 'enqueued' => @queues[dest][:enqueued], 'dequeued' => @queues[dest][:dequeued]}
    end
    stats
  end

  def close_queue(dest)
    if @queues[dest][:size] == 0 and @queues[dest][:frames].size == 0 and @delete_empty
      _close_queue(dest)
      @queues.delete(dest)
      @frames.delete(dest)
      puts "Queue #{dest} removed." if $DEBUG
    end
  end

  def open_queue(dest)
    @queues[dest] = Hash.new
    @frames[dest] = Hash.new
    @queues[dest][:size] = 0
    @queues[dest][:frames] = Array.new
    @queues[dest][:msgid] = 1
    @queues[dest][:enqueued] = 0
    @queues[dest][:dequeued] = 0
    @queues[dest][:exceptions] = 0
    _open_queue(dest)
    puts "Created queue #{dest}" if $DEBUG
  end

  def requeue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    msgid = frame.headers['message-id']
    if frame.headers['max-exceptions'] and @frames[dest][msgid][:exceptions] >= frame.headers['max-exceptions'].to_i
      enqueue("/queue/deadletter",frame)
      return
    end
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    writeframe(dest,frame,msgid)
    @queues[dest][:frames].unshift(msgid)
    @frames[dest][msgid][:exceptions] += 1
    @queues[dest][:dequeued] -= 1
    @queues[dest][:exceptions] += 1
    @queues[dest][:size] += 1
    return true
  end

  def enqueue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    msgid = @stompid[@queues[dest][:msgid]]
    frame.headers['message-id'] = msgid
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    writeframe(dest,frame,msgid)
    @queues[dest][:frames].push(msgid)
    @frames[dest][msgid] = Hash.new
    @frames[dest][msgid][:exceptions] =0
    @frames[dest][msgid][:client_id] = frame.headers['client-id'] if frame.headers['client-id']
    @frames[dest][msgid][:expires] = frame.headers['expires'] if frame.headers['expires']
    @queues[dest][:msgid] += 1
    @queues[dest][:enqueued] += 1
    @queues[dest][:size] += 1
    return true
  end

  def dequeue(dest)
    return false unless @queues.has_key?(dest) and @queues[dest][:size] > 0
    msgid = @queues[dest][:frames].first
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    if frame = readframe(dest,msgid)
      @queues[dest][:frames].shift
      @queues[dest][:size] -= 1
      @queues[dest][:dequeued] += 1
      return frame
    else
      raise "Dequeue error: cannot delete frame file #{filename}"
    end
  end
  
  def writeframe(dest,frame,msgid)
    _writeframe(dest,frame,msgid)
  end

  def readframe(dest,msgid)
    _readframe(dest,msgid)
  end

end
end

