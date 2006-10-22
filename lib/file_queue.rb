
require 'rubygems'
require 'thread'

class FileQueue

  def initialize(directory='.stompserver')
    @directory = directory
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @queues = Hash.new
    @active = Hash.new
    @frame_index = 0
    @system_id = nil
    @sfr = StompFrameRecognizer.new
    dirs = Dir.entries(@directory)
    dirs.delete_if {|x| ['stat','.','..'].include?(x)}.sort
    dirs.each do |f|
      f.gsub!('_queue_','/queue/')
      @active[f] = true
    end
    @active.keys.each {|dest| open_queue(dest)}
    p "FileQueue initialized"
  end

  def stop
    p "Shutting down FileQueue"
    @active.keys.each {|dest| close_queue(dest)}
  end

  def set_system_id(id)
    @system_id = id
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
      stat = Marshal.load(File.read("#{queue_dir}/.stat"))
      @queues[dest][:enqueued] = stat['enqueued']
      @queues[dest][:dequeued] = stat['dequeued']
    else
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
      stat = {'enqueued' => @queues[dest][:enqueued], 'dequeued' => @queues[dest][:dequeued]}
      File.open("#{@queues[dest][:queue_dir]}/.stat", "wb") { |f| f.write Marshal.dump(stat)}
      p "Queue #{dest} closed with #{qsize} saved messages" if $DEBUG
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    open_queue(dest) unless @queues.has_key?(dest)
    if file_id = @queues[dest][:files].last
      file_id = (file_id.to_i + 1).to_s
      msgid = @system_id + (@frame_index +=1).to_s + file_id
    else
      file_id = '1'
      msgid = @system_id + (@frame_index +=1).to_s + file_id
    end
    frame.headers['message-id'] = msgid
    file = "#{@queues[dest][:queue_dir]}/#{file_id}"
    File.open(file, "wb") {|f| f.syswrite(frame)}
    @queues[dest][:files].push(file_id)
    @queues[dest][:enqueued] += 1
    @queues[dest][:size] += 1
    return true
  end

  def dequeue(dest)
    return false unless @queues.has_key?(dest) and @queues[dest][:files].size > 0
    frame = nil
    frame_text = nil
    file_id = @queues[dest][:files].first
    file = "#{@queues[dest][:queue_dir]}/#{file_id}"
    File.open(file, "rb") {|f| frame_text = f.read}
    @sfr << frame_text
    if frame = @sfr.frames.shift
      if File.delete(file)
        @queues[dest][:files].shift
        @queues[dest][:size] -= 1
        @queues[dest][:dequeued] += 1
        return frame
      else
        raise "Dequeue error: cannot delete frame file #{file}"
      end
    else
      raise "Dequeue error: frame parsing failed"
    end
  end


end

