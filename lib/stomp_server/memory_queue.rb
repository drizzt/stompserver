
module StompServer
class MemoryQueue

  def initialize
    @frame_index =0
    @stompid = StompServer::StompId.new
    @stats = Hash.new
    @messages = Hash.new { Array.new }
    puts "MemoryQueue initialized"
  end

  def stop
  end

  def monitor
    stats = Hash.new
    @messages.keys.each do |dest|
     stats[dest] = {'size' => @messages[dest].size, 'enqueued' => @stats[dest][:enqueued], 'dequeued' => @stats[dest][:dequeued]}
    end
    stats
  end

  def dequeue(dest)
    if frame = @messages[dest].shift
      @stats[dest][:dequeued] += 1
      return frame
    else
      return false
    end
  end

  def enqueue(dest,frame)
    @frame_index += 1
    if @stats[dest]
      @stats[dest][:enqueued] += 1
    else
      @stats[dest] = Hash.new
      @stats[dest][:enqueued] = 1
      @stats[dest][:dequeued] = 0
    end
    msgid = @stompid[@frame_index]
    frame.headers['message-id'] = msgid
    @messages[dest] += [frame]
  end
end
end
