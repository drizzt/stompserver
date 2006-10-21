
require 'rubygems'
require 'lockfile'

class FileQueue

  def initialize(directory='.stompserver')
    @directory = directory
    @queues = Hash.new
    @active = Hash.new
    @frame_index = 0
    @system_id = nil
    @sfr = StompFrameRecognizer.new
    @lockfile = @directory + '/' + 'file.lock'
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
    @queues[dest][:queue_dir] = queue_dir
    Dir.mkdir(queue_dir) unless File.directory?(queue_dir)
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
      p "Removing queue #{dest}" if $DEBUG
    else
      p "Closing queue #{dest} with #{qsize} saved messages" if $DEBUG
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    p frame
    dest = queuename(dest)
    open_queue(dest) unless @queues.has_key?(dest)
    Lockfile.new(@lockfile) do
      if file_id = @queues[dest][:files].last
        p "file_id=#{file_id.class}"
        file_id += 1
        msgid = @system_id + (@frame_index +=1).to_s + file_id.to_s
      else
        msgid = @system_id + (@frame_index +=1).to_s + '1'
        file_id = 1
      end
      frame.headers['message-id'] = msgid
      file = "#{@queues[dest][:queue_dir]}/#{file_id.to_s}"
      File.open(file, "wb") {|f| f.syswrite(frame)}
      @queues[dest][:files].push(file_id)
      return true
    end
  end

  def dequeue(dest)
    dest = queuename(dest)
    return false unless @queues.has_key?(dest) and @queues[dest][:files].size > 0
    frame = nil
    frame_text = nil
    Lockfile.new(@lockfile) do
      file_id = @queues[dest][:files].first
      file = "#{@queues[dest][:queue_dir]}/#{file_id.to_s}"
      File.open(file, "rb") {|f| frame_text = f.read}
      @sfr << frame_text
      if frame = @sfr.frames.shift
        if File.delete(file)
          @queues[dest][:files].shift
          return frame
        else
          raise "Dequeue error: cannot delete frame file #{file}"
        end
      else
        raise "Dequeue error: frame parsing failed"
      end
    end
  end


end

