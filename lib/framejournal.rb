# Simple Journal File(s) Manager
# You select the directory, and it will collect the messages
# The journal file format is:
#
# Status Byte: 0 - pending, 1 - processed
# Frame Size: 4 byte long (network endian - yes I limit my messages to 4G)
# Message 
#
# Repeat
#
# When the size of a journal file exceeds its limit
class FrameJournal
  def initialize(directory, size_limit = 20 * 2**)
  end
  
  def journal(msg)
  end
  
  def release(msg)
  end
  
  def pending
  end
  
  def rollover
  end
end
