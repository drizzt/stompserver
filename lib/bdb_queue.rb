
require 'rubygems'
require 'bdb'

class BDBQueue
  attr_accessor :memory_cache

  def initialize(directory='bdbstore',memory_cache=false)
    @directory = directory
    @memory_cache = memory_cache
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @sfr = StompFrameRecognizer.new
    @active = BDB::Hash.open("#{@directory}/queues.db", nil, "a")
    @queues = Hash.new
    @active.keys.each {|dest| open_queue(dest)}
  end

  def open_queue(dest)
    unless @queues.has_key?(dest)
      @queues[dest] = Hash.new
      dbname = dest.gsub('/', '_')
      dbdir = get_dbdir(dbname)
      dbfile = dbdir + '/' + dbname
      if File.directory?(dbdir)
        p "Queue #{dest} exists" if $DEBUG
      else
        p "Creating new queue #{dest}" if $DEBUG
        Dir.mkdir(dbdir)
      end
      @queues[dest][:dbh] = BDB::Queue.new("#{dbfile}.db", nil, "a")
      @queues[dest][:dbdir] = dbdir
      @active[dest] = true
      p "Queue #{dest} opened" if $DEBUG
    end
  end

  def remove_queue(dest)
    # Todo
  end

  def close_queue(dest)
    @queues[dest][:dbh].close
    @queues.delete(dest)
    p "Queue #{dest} closed" if $DEBUG
  end

  def get_dbdir(dest)
    @directory + '/' + dest
  end

  def delete_message(dest,msgid)
    return true
    p "Delete message #{dest} #{msgid}" if $DEBUG
    @queues[dest][:dbh].delete(msgid.to_i)
    file = @queues[dest][:dbdir] + '/' + msgid
    File.delete(file)
  end

  def enqueue(dest,frame)
    msgid = @queues[dest][:dbh].push dest
    file = @queues[dest][:dbdir] + '/' + msgid.to_s
    frame.headers['message-id'] = msgid.to_s
    File.open(file,'w') {|f| f.write(frame)}
    msgid
  end

  def dequeue(dest)
    if qitem = @queues[dest][:dbh].shift
      file = @queues[dest][:dbdir] + '/' + qitem[0].to_s
      p "Reading message #{file}" if $DEBUG
      frame_text = File.read(file)
      File.delete(file)
      @sfr << frame_text
      @sfr.frames.shift
    else
      return false
    end
  end

  def get_message_by_msgid(dest,msgid)
    file = @queues[dest][:dbdir] + '/' + msgid
    File.read(file)
  end

end

if __FILE__ == $0
  fj = BDBQueue.new('fj', 3)
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
end
