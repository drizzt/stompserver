
class MemoryQueue

  def initialize
    @msgid = 0
    @messages = Hash.new { Array.new }
  end

  def stop
  end

  def open_queue(dest)
    true
  end

  def close_queue(dest)
    true
  end

  def dequeue(dest)
    @messages[dest].shift
  end

  def enqueue(dest,frame)
    @msgid += 1
    frame.headers['message-id'] = @msgid.to_s
    @messages[dest] += [frame]
  end
end
