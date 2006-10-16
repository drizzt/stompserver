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

require 'madeleine'
require 'madeleine/automatic'

class MadFrameJournal
  include Madeleine::Automatic::Interceptor
  attr_reader :frames
  automatic_read_only :frames

  def initialize
    @frames = {}
  end

  def add(msgid, frame)
    @frames[msgid] = frame
  end

  def delete(msgid, frame)
    @frames.delete(msgid)
  end

  def clear
    @frames.clear
  end
  
  automatic_read_only :lookup
  def lookup(msgid)
    @frames[msgid]
  end
end

class FrameJournal
  def initialize(directory='frame-journal', snap_freq = 60 * 5)
    @mad = AutomaticSnapshotMadeleine.new(directory) do
      MadFrameJournal.new
    end
    
    # always snap on startup, in case we had an previous failure
    @modified = true
    Thread.new(@mad, snap_freq) do |mad, freq|
      puts "0. Autosnap #{freq}/#{@modified}"
      while true
        sleep(freq)
        puts "Autosnap #{freq}/#{@modified}"
        mad.take_snapshot if @modified
        @modified = false
      end
    end
  end
  
  def []=(msgid, frame)
    @modified = true
    @mad.system.add(msgid, frame)
  end
  
  def [](msgid)
    @mad.system.lookup(msgid)
  end
  
  def delete(msgid)
    @modified = true
    @mad.system.delete(msgid)
  end
  
  def keys
    @mad.system.frames.keys
  end
  
  def clear
    @modified = true
    @mad.system.clear
  end
end

fj = FrameJournal.new('fj', 3)
until ARGV.empty?
  case cmd = ARGV.shift
  when "keys"
    puts fj.keys.inspect
  when "dump"
    fj.keys.each do |key|
      puts "#{key}: #{fj[key]}"
    end
  when "show"
    key = ARGV.shift
    puts "#{key}: #{fj[key]}"
  when "add"
    key = ARGV.shift
    val = ARGV.shift
    fj[key] = val
  when "sleep"
    sleep ARGV.shift.to_i
  when "delete"
    fj.delete(ARGV.shift)
  end
end
