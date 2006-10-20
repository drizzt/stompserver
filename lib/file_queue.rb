
require 'lockfile'

class FileQueue

  def initialize(directory='.stompserver')
    @directory = directory
    @queues = Hash.new
    @active = Hash.new
    @system_id = nil
    @sfr = StompFrameRecognizer.new
    @lockfile = @directory + 'file.lock'
    Dir.mkdir(@directory) unless File.directory?(@directory)
    files = Dir.entries(@directory)
    files.delete_if {|x| ['.','..'].include?(x)}.sort
    files.each {|f| @active[f] = true}
    @active.keys.each {|dest| open_queue(dest)}
  end

  def stop
    p "Shutting down FileQueue"
    @active.keys.each {|dest| close_queue(dest)}
  end

  def set_system_id(id)
    @system_id = id
  end

  def queuename(dest)
    dest.gsub('/', '_')
  end

  def open_queue(dest)
    @queues[dest] = Hash.new
    queue_dir = @directory + '/' + dest
    Dir.mkdir(queue_dir) unless File.directory?(queue_dir)
    @queues[dest][:queue_dir] = queue_dir
    files = Dir.entries(queue_dir)
    files.delete_if {|x| x.to_i == 0  }.sort
    @queues[dest][:files] = files
    @active[dest] = true
    p "Opened queue #{@queues.keys} size=#{@queues[dest][:files].size}" if $DEBUG
  end


  def close_queue(dest)
    qsize = @queues[dest][:files].size
    p "Closing queue #{dest} size=#{qsize}" if $DEBUG
    if qsize == 0
      Dir.delete(@queues[dest][:queue_dir]) if File.directory?(@queues[dest][:queue_dir])
      @active.delete(dest)
      p "Removing queue #{dest}"
    else
      p "Closing queue #{dest} with #{qsize} saved messages"
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    dest = queuename(dest)
    open_queue(dest) unless @queues.has_key?(dest)
    Lockfile.new(@lockfile) do
      if file_id = @queues[dest][:files].last
        file_id += 1
        msgid = @system_id + file_id.to_s
      else
        msgid = @system_id + '1'
        file_id = 1
      end
      frame.headers['message-id'] = msgid
      file = "#{@queues[dest][:queue_dir]}/#{file_id.to_s}"
      write_file(file,frame)
      @queues[dest][:files].push(file_id)
    end
  end

  def dequeue(dest)
    dest = queuename(dest)
    return false unless @queues.has_key?(dest) and @queues[dest][:files].size > 0
    frame = nil
    Lockfile.new(@lockfile) do
      file_id = @queues[dest][:files].first
      file = "#{@queues[dest][:queue_dir]}/#{file_id.to_s}"
      if frame_text = read_file(file)
        @sfr << frame_text
        if frame = @sfr.frames.shift
          File.delete(file)
          @queues[dest][:files].shift
          return frame
        else
          return false
        end
      else
        return false
      end
    end
  end


  def write_file(path,content)
    p "write_file #{path}" if $DEBUG
    begin
      f = File.open(path, "wb")
    rescue Errno::EINTR
    retry
    else
      f.syswrite(content)
    ensure
      f.close
    end
  end

  def read_file(path)
    p "read_file #{path}" if $DEBUG
    content = false
    begin
      f = File.open(path, "rb")
    rescue Errno::EINTR
    retry
    else
      content = f.read
    ensure
      f.close
    end
    return content
  end


end

