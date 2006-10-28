
module StompServer
class FileQueue

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

    puts "FileQueue initialized in #{@directory}"
    EventMachine::add_periodic_timer 1800, proc {@queues.keys.each {|dest| close_queue(dest)} }
  end

  def stop
    puts "Shutting down FileQueue"

    @queues.keys.each {|dest| close_queue(dest)}
    @queues.keys.each do |dest|
      puts "Queue #{dest} size=#{@queues[dest][:size]} enqueued=#{@queues[dest][:enqueued]} dequeued=#{@queues[dest][:dequeued]}" if $DEBUG
    end

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
      Dir.delete(@queues[dest][:queue_dir]) if File.directory?(@queues[dest][:queue_dir])
      @queues.delete(dest)
      @frames.delete(dest)
      puts "Queue #{dest} removed." if $DEBUG
    end
  end

  def create_queue(dest)
    @queues[dest] = Hash.new
    @frames[dest] = Hash.new
    queue_name = dest.gsub('/','_')
    queue_dir = @directory + '/' + queue_name
    @queues[dest][:queue_dir] = queue_dir
    Dir.mkdir(queue_dir) unless File.directory?(queue_dir)
    @queues[dest][:size] = 0
    @queues[dest][:frames] = Array.new
    @queues[dest][:msgid] = 1
    @queues[dest][:enqueued] = 0
    @queues[dest][:dequeued] = 0
    @queues[dest][:exceptions] = 0
    puts "Created queue #{dest}" if $DEBUG
  end

  def requeue(dest,frame)
    create_queue(dest) unless @queues.has_key?(dest)
    msgid = frame.headers['message-id']
    if frame.headers['max-exceptions'] and @frames[dest][msgid][:exceptions] >= frame.headers['max-exceptions'].to_i
      enqueue("/queue/deadletter",frame)
      return
    end
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    writeframe(frame,filename)
    @queues[dest][:frames].unshift(msgid)
    @frames[dest][msgid][:exceptions] += 1
    @queues[dest][:dequeued] -= 1
    @queues[dest][:exceptions] += 1
    @queues[dest][:size] += 1
    return true
  end

  def enqueue(dest,frame)
    create_queue(dest) unless @queues.has_key?(dest)
    msgid = @stompid[@queues[dest][:msgid]]
    frame.headers['message-id'] = msgid
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    writeframe(frame,filename)
    @queues[dest][:frames].push(msgid)
    @frames[dest][msgid] = Hash.new
    @frames[dest][msgid][:exceptions] =0
    @frames[dest][msgid][:client_id] = frame.headers['client-id']
    @frames[dest][msgid][:expires] = frame.headers['expires']
    @queues[dest][:msgid] += 1
    @queues[dest][:enqueued] += 1
    @queues[dest][:size] += 1
    return true
  end

  def dequeue(dest)
    return false unless @queues.has_key?(dest) and @queues[dest][:size] > 0
    msgid = @queues[dest][:frames].first
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    if frame = readframe(filename)
      @queues[dest][:frames].shift
      @queues[dest][:size] -= 1
      @queues[dest][:dequeued] += 1
      return frame
    else
      raise "Dequeue error: cannot delete frame file #{filename}"
    end
  end

  def writeframe(frame,filename)
    frame_body = frame.body.to_s
    frame.body = ''
    frame_image = Marshal.dump(frame)
    file = File.open(filename,'w+')
    file.binmode
    file.sysseek 0, IO::SEEK_SET
    file.syswrite sprintf("%08x", frame_image.length)
    file.syswrite sprintf("%08x", frame_body.length)
    file.syswrite(frame_image)
    file.syswrite(frame_body)
    file.close
    return true
  end
  
  def readframe(filename)
    file = File.open(filename,'r+')
    file.binmode
    file.sysseek 0, IO::SEEK_SET
    frame_len = file.sysread(8).hex
    body_len = file.sysread(8).hex
    frame = Marshal::load file.sysread(frame_len)
    frame_body = file.sysread(body_len)
    file.close
    frame.body = frame_body
    if File.delete(filename)
      return frame
    else
      return false
    end
  end
end
end

