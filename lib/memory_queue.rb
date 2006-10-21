
require 'rubygems'

class MemoryQueue

  def initialize
    @frame_index =0
    @system_id = nil
    @messages = Hash.new { Array.new }
  end

  def stop
  end

  def set_system_id(id)
    @system_id = id
  end

  def dequeue(dest)
    @messages[dest].shift || false
  end

  def enqueue(dest,frame)
    @frame_index += 1
    msgid = @system_id + @frame_index.to_s
    frame.headers['message-id'] = msgid
    @messages[dest] += [frame]
  end
end
