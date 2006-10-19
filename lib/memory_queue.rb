
class MemoryQueue
  attr_accessor :memory_cache

  def initialize
    @msgid = 0
    @memory_cache = true
  end

  def open_queue(dest)
    true
  end

  def close_queue(dest)
    true
  end

  def delete_message(dest,msgid)
    true
  end

  def dequeue(dest,msgid)
    true
  end

  def enqueue(dest,frame)
    @msgid += 1
  end

  def get_next_message(dest)
    false
  end

end
