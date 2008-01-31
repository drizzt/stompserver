
module StompServer
class MemoryQueue
  attr_accessor :checkpoint_interval

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
    assign_id(frame, dest)
    requeue(dest, frame)
  end

  def requeue(dest,frame)
    @messages[dest] += [frame]
  end

  def message_for?(dest)
    !@messages[dest].empty?
  end

  def assign_id(frame, dest)
    frame.headers['message-id'] = @stompid[@frame_index]
  end
end
end
