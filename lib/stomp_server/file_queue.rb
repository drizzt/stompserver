
module StompServer
class FileQueue

  def initialize(directory='.stompserver', delete_empty=true)
    @stompid = StompServer::StompId.new
    @delete_empty = delete_empty
    @directory = directory
    Dir.mkdir(@directory) unless File.directory?(@directory)
    if File.exists?("#{@directory}/queues.info")
      File.open("#{@directory}/queues.info", "rb") { |f| @queues = Marshal.load(f.read)}
    else
      @queues = Hash.new
    end
    @queues.keys.each do |dest| 
      puts "Queue #{dest} open with #{@queues[dest][:size]} messages.  #{@queues[dest][:enqueued]} enqueued, #{@queues[dest][:dequeued]} dequeued"
    end
    puts "FileQueue initialized in #{@directory}"
  end

  def stop
    puts "Shutting down FileQueue"
    @queues.keys.each do |dest| 
      if @queues[dest][:size] == 0 and @queues[dest][:frames].size == 0 and @delete_empty
        puts "Queue #{dest} is empty, removing."
        Dir.delete(@queues[dest][:queue_dir]) if File.directory?(@queues[dest][:queue_dir])
        @queues.delete(dest)
      else
        puts "Queue #{dest} closed with #{@queues[dest][:size]} messages.  #{@queues[dest][:enqueued]} enqueued, #{@queues[dest][:dequeued]} dequeued"
      end
    end
    File.open("#{@directory}/queues.info", "wb") { |f| f.write Marshal.dump(@queues)}
  end

  def monitor
    stats = Hash.new
    @queues.keys.each do |dest| 
      stats[dest] = {'size' => @queues[dest][:size], 'enqueued' => @queues[dest][:enqueued], 'dequeued' => @queues[dest][:dequeued]}
    end
    stats
  end

  def open_queue(dest)
    @queues[dest] = Hash.new
    queue_name = dest.gsub('/','_')
    queue_dir = @directory + '/' + queue_name
    @queues[dest][:queue_dir] = queue_dir
    Dir.mkdir(queue_dir) unless File.directory?(queue_dir)
    @queues[dest][:size] = 0
    @queues[dest][:frames] = Array.new
    @queues[dest][:frameinfo] = Hash.new
    @queues[dest][:frameinfo][:exceptions] = 0
    @queues[dest][:msgid] = 1
    @queues[dest][:enqueued] = 0
    @queues[dest][:dequeued] = 0
    @queues[dest][:exceptions] = 0
    puts "Opened queue #{dest} enqueued=#{@queues[dest][:enqueued]} dequeued=#{@queues[dest][:dequeued]} size=#{@queues[dest][:size]}" if $DEBUG
  end

  def requeue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    msgid = frame.headers['message-id']
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    writeframe(frame,filename)
    @queues[dest][:frames].unshift(msgid)
    @queues[dest][:frameinfo][:exceptions] += 1
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
    writeframe(frame,filename)
    @queues[dest][:frames].push(msgid)
    @queues[dest][:frameinfo][:msgid] = msgid
    @queues[dest][:frameinfo][:client_id] = frame.headers['client-id'] if frame.headers['client-id']
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
    frame_body_len = file.sysread(8).hex
    frame = Marshal::load file.sysread(frame_len)
    frame_body = file.sysread(frame_body_len)
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

