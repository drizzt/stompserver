
require 'rubygems'
require 'bdb'

class BDBQueue

  def initialize(directory='bdbstore')
    @directory = directory
    @bdb_env = @directory + '/bdb_env'
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @sfr = StompFrameRecognizer.new
    @active = BDB::Hash.open("#{@directory}/queues.db", nil, "a")
    @queues = Hash.new
    @active.keys.each {|dest| open_queue(dest)}
  end

  def stop
    @active.keys.each {|dest| close_queue(dest)}
    @active.close
  end

  def open_queue(dest)
    unless @queues.has_key?(dest)
      @queues[dest] = Hash.new
      queue_name = dest.gsub('/', '_')
      queue_files = @directory + '/' + queue_name
      queue_bdb = @directory + '/' + queue_name + '.db'
      Dir.mkdir(queue_files) unless File.directory?(queue_files)
      @queues[dest][:dbh] = BDB::Queue.new("#{queue_bdb}", nil, "a")
      @queues[dest][:queue_files] = queue_files
      @queues[dest][:queue_bdb] = queue_bdb
      @active[dest] = true
      p "Queue #{dest} opened files=#{@queues[dest][:queue_files]} dbfile=#{@queues[dest][:queue_bdb]}" if $DEBUG
    end
  end


  def close_queue(dest)
    qsize = @queues[dest][:dbh].size
    @queues[dest][:dbh].close
    if qsize == 0
      File.directory?(@queues[dest][:queue_files]) if  Dir.delete(@queues[dest][:queue_files])
      File.delete(@queues[dest][:queue_bdb]) if File.exists?(@queues[dest][:queue_bdb])
      @active.delete(dest)
      p "Queue #{dest} has no messages, removing.." if $DEBUG
    else
      p "Queue #{dest} has #{qsize} saved messages" if $DEBUG
    end
    @queues.delete(dest)
  end

  def enqueue(dest,frame)
    msgid = @queues[dest][:dbh].push dest
    file = @queues[dest][:queue_files] + '/' + msgid.to_s
    frame.headers['message-id'] = msgid.to_s
    File.open(file,'w') {|f| f.write(frame)}
  end

  def dequeue(dest)
    if qitem = @queues[dest][:dbh].shift
      file = @queues[dest][:queue_files] + '/' + qitem[0].to_s
      frame_text = File.read(file)
      File.delete(file)
      @sfr << frame_text
      @sfr.frames.shift
    else
      return false
    end
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
