
class FileQueue

  def initialize(directory='.stompserver')
    @directory = directory
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @queues = Hash.new
    @active = Hash.new
    @stompid = StompId.new
    dirs = Dir.entries(@directory)
    dirs.delete_if {|x| ['stat','.','..'].include?(x)}.sort
    dirs.each do |f|
      f.gsub!('_queue_','/queue/')
      @active[f] = true
    end
    @active.keys.each {|dest| open_queue(dest)}
    p "FileQueue initialized in #{@directory}"
  end

  def stop
    p "Shutting down FileQueue"
    @active.keys.each {|dest| close_queue(dest)}
  end

  def monitor
    stats = Hash.new
    @active.keys.each do |dest| 
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
    files = Dir.entries(queue_dir)
    files.delete_if {|x| x.to_i == 0  }.sort
    @queues[dest][:files] = files
    @queues[dest][:size] = files.size
    if File.exists?("#{queue_dir}/.stat")
      stat = Marshal::load(File.read("#{queue_dir}/.stat"))
      @queues[dest][:enqueued] = stat['enqueued']
      @queues[dest][:dequeued] = stat['dequeued']
      @queues[dest][:msgid] = stat['msgid']
    else
      @queues[dest][:msgid] = 1
      @queues[dest][:enqueued] = 0
      @queues[dest][:dequeued] = 0
    end
    @active[dest] = true
    p "Opened queue #{dest} enqueued=#{@queues[dest][:enqueued]} dequeued=#{@queues[dest][:dequeued]} size=#{@queues[dest][:size]}" if $DEBUG
  end


  def close_queue(dest)
    qsize = @queues[dest][:files].size
    p "Closing queue #{dest} size=#{qsize}" if $DEBUG
    if qsize == 0
      File.delete("#{@queues[dest][:queue_dir]}/.stat") if File.exists?("#{@queues[dest][:queue_dir]}/.stat")
      Dir.delete(@queues[dest][:queue_dir]) if File.directory?(@queues[dest][:queue_dir])
      @active.delete(dest)
      p "Queue #{dest} removed" if $DEBUG
    else
      stat = {'msgid' => @queues[dest][:msgid], 'enqueued' => @queues[dest][:enqueued], 'dequeued' => @queues[dest][:dequeued]}
      File.open("#{@queues[dest][:queue_dir]}/.stat", "wb") { |f| f.write Marshal.dump(stat)}
      p "Queue #{dest} closed with #{qsize} saved messages" if $DEBUG
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    if file_id = @queues[dest][:files].last
      file_id = (file_id.to_i + 1).to_s
    else
      file_id = '1'
    end
    msgid = @stompid[@queues[dest][:msgid]]
    frame.headers['message-id'] = msgid
    filename = "#{@queues[dest][:queue_dir]}/#{file_id}"
    writeframe(frame,filename)
    @queues[dest][:files].push(file_id)
    @queues[dest][:msgid] += 1
    @queues[dest][:enqueued] += 1
    @queues[dest][:size] += 1
    return true
  end

  def dequeue(dest)
    return false unless @queues.has_key?(dest) and @queues[dest][:files].size > 0
    file_id = @queues[dest][:files].first
    filename = "#{@queues[dest][:queue_dir]}/#{file_id}"
    if frame = readframe(filename)
      @queues[dest][:files].shift
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

