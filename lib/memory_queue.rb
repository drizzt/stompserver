
class MemoryQueue

  def initialize
    @msgid = 0
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

  def add_message(dest,frame)
    @msgid += 1
  end

  def get_next_message(dest)
    false
  end

end
