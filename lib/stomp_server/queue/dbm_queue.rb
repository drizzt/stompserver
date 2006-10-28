
module StompServer
class DBMQueue < Queue

  def initialize *args
    super
    # Please don't use dbm files for storing large frames, it's problematic at best and uses large amounts of memory.
    # dbm isn't available on windows, and sdbm croaks on marshalled data that contains certain characters.
    @dbm = false
    if RUBY_PLATFORM =~/linux|bsd/
      types = ['bdb','dbm','gdbm']
    else
      types = ['bdb','gdbm']
    end
    types.each do |dbtype|
      begin
        require dbtype
        @dbm = dbtype
        break
      rescue LoadError => e
      end
    end
    raise "No DBM library found. Tried bdb,dbm,sdbm,gdbm" unless @dbm
    @db = Hash.new
    @queues.keys.each {|q| _open_queue(q)}
  end

  def dbmopen(dbname)
    if @dbm == 'bdb'
      BDB::Hash.new(dbname, nil, "a")
    elsif @dbm == 'dbm'
      DBM.open(dbname)
    elsif @dbm == 'sdbm'
      SDBM.open(dbname)
    elsif @dbm == 'gdbm'
      GDBM.open(dbname)
    end
  end


  def _open_queue(dest)
    queue_name = dest.gsub('/', '_')
    dbname = @directory + '/' + queue_name
    @db[dest] = Hash.new
    @db[dest][:dbh] = dbmopen(dbname)
    @db[dest][:dbname] = dbname
  end


  def _close_queue(dest)
    @db[dest][:dbh].close
    dbname = @db[dest][:dbname]
    File.delete(dbname) if File.exists?(dbname)
    File.delete("#{dbname}.db") if File.exists?("#{dbname}.db")
    File.delete("#{dbname}.pag") if File.exists?("#{dbname}.pag")
    File.delete("#{dbname}.dir") if File.exists?("#{dbname}.dir")
  end

  def _writeframe(dest,frame,msgid)
    @db[dest][:dbh][msgid] = Marshal::dump(frame)
  end

  def _readframe(dest,msgid)
    frame_image = @db[dest][:dbh][msgid]
    Marshal::load(frame_image)
  end

end
end
