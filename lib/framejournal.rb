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

require 'mockfs'

class FrameJournal
  Struct.new("FJHeader", :status, :expires, :file)
    
  def initialize(directory, size_limit = 2**21)
    @index = {}
    @dir = directory
    MockFS.file_utils.mkpath(@dir) unless MockFS.file.directory?(@dir)

    recover    
  end
  
  def journal(msgid, expires, msg)
    
  end
  
  def release(msg)
  end
  
  def pending
  end
  
  def rollover
  end

  def recover  
    @jnum = -1
    MockFS.dir.glob(File.join(@dir, 'fjf*.dat')).each do |jf|
      if jf =~ /fjf(\d*).dat/
        # todo process these records, collecting headers
        # delete "empty" files
        @jnum = [@jnum, $1.to_i].max
      end
    end
    
    @jnum += 1
    @journal = MockFS.file.new(File.join(@dir, "fjf%04d.dat" % @jnum), 'wb')
  end
end
