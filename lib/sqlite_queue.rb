
require 'rubygems'
require 'sqlite3'

class SqliteQueue

  def initialize(directory='.stompserver')
    @msgid = 0
    @system_id = 'stompcma'
    @directory = directory
    Dir.mkdir(@directory) unless File.directory?(@directory)
    @sfr = StompFrameRecognizer.new
    @dbh = SQLite3::Database.new("#{@directory}/queues.db" )
    found = @dbh.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'queues'")
    if found.empty?
      p "Creating queues.db" if $DEBUG
      if @dbh.execute("CREATE TABLE queues ( id integer PRIMARY KEY AUTOINCREMENT, msgid TEXT, queue TEXT, frame BLOB )")
        p "queues table created" if $DEBUG
      end
    end
    @queues = Hash.new
    @frames = Array.new
  end

  def stop
    p "Shutting down Sqlite3Queue"
    @dbh.close
  end

  def next_msgid
    @msgid += 1
    @msgid.to_s + '-' + @system_id
  end

  def enqueue(dest,frame)
    msgid = next_msgid
    frame.headers['message-id'] = msgid
    @dbh.execute("INSERT INTO queues(id,msgid,queue,frame) VALUES (NULL,?,?,?)",msgid,dest,SQLite3::Blob.new(frame.to_s))
  end

  def dequeue(dest)
    if @frames.empty?
      @dbh.execute("SELECT id,frame FROM queues where queue = '#{dest}' order by id") do |r|
        p "Frame found" if $DEBUG
        @frames << r[1]
      end
    end

    return false if @frames.empty?
    @sfr << @frames.shift
    if frame = @sfr.frames.shift
      @dbh.execute("DELETE FROM queues where msgid = '#{frame.headers['message-id']}'")
      return frame
    else
      return false
    end
  end

end

