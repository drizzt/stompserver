require 'rubygems'
require 'eventmachine'
require 'stomp_server/stomp_frame'
require 'stomp_server/stomp_id'
require 'stomp_server/stomp_auth'
require 'stomp_server/topic_manager'
require 'stomp_server/queue_manager'
require 'stomp_server/queue'
require 'stomp_server/queue/memory_queue'
require 'stomp_server/queue/file_queue'
require 'stomp_server/queue/dbm_queue'
require 'stomp_server/protocols/stomp'

module StompServer
  VERSION = '0.9.9'

  class Configurator
    attr_accessor :opts

    def initialize
      @opts = nil
      @defaults = {
        :port => 61613,
        :host => "127.0.0.1",
        :debug => false,
        :queue => 'memory',
        :auth => false,
        :working_dir => Dir.getwd,
        :storage => ".stompserver",
        :logdir => 'log',
        :configfile => 'stompserver.conf',
        :logfile => 'stompserver.log',
        :pidfile => 'stompserver.pid',
        :checkpoint => 0
      }
      @opts = getopts
      if opts[:debug]
        $DEBUG=true
      end

    end

    def getopts
      copts = OptionParser.new
      copts.on("-C", "--config=CONFIGFILE", String, "Configuration File (default: stompserver.conf)") {|c| @defaults[:configfile] = c}
      copts.on("-p", "--port=PORT", Integer, "Change the port (default: 61613)") {|p| @defaults[:port] = p}
      copts.on("-b", "--host=ADDR", String, "Change the host (default: localhost)") {|a| @defaults[:host] = a}
      copts.on("-q", "--queuetype=QUEUETYPE", String, "Queue type (memory|dbm|activerecord|file) (default: memory)") {|q| @defaults[:queue] = q}
      copts.on("-w", "--working_dir=DIR", String, "Change the working directory (default: current directory)") {|s| @defaults[:working_dir] = s}
      copts.on("-s", "--storage=DIR", String, "Change the storage directory (default: .stompserver, relative to working_dir)") {|s| @defaults[:storage] = s}
      copts.on("-d", "--debug", String, "Turn on debug messages") {|d| @defaults[:debug] = true}
      copts.on("-a", "--auth", String, "Require client authorization") {|a| @defaults[:auth] = true}
      copts.on("-c", "--checkpoint=SECONDS", Integer, "Time between checkpointing the queues in seconds (default: 0)") {|c| @defaults[:checkpoint] = c}
      copts.on("-h", "--help", "Show this message") do
        puts copts
        exit
      end
      puts copts.parse(ARGV)

      if File.exists?(@defaults[:configfile])
        opts = @defaults.merge(YAML.load_file(@defaults[:configfile]))
      else
        opts = @defaults
      end

      opts[:etcdir] = File.join(opts[:working_dir],'etc')
      opts[:storage] = File.join(opts[:working_dir],opts[:storage])
      opts[:logdir] = File.join(opts[:working_dir],opts[:logdir])
      opts[:logfile] = File.join(opts[:logdir],opts[:logfile])
      opts[:pidfile] = File.join(opts[:logdir],opts[:pidfile])
      if opts[:auth]
        opts[:passwd] = File.join(opts[:etcdir],'.passwd')
      end

      return opts
    end
  end


  class Run
    attr_accessor :queue_manager, :auth_required, :stompauth, :topic_manager

    def initialize(opts)
      @opts = opts
      @queue_manager = nil
      @auth_required = nil
      @stompauth = nil
      @topic_manager = nil
    end

    def stop(pidfile)
      @queue_manager.stop
      puts "Stompserver shutting down" if $DEBUG
      EventMachine::stop_event_loop
      File.delete(pidfile)
    end

    def start
      begin
        if @opts[:group]
          puts "Changing group to #{@opts[:group]}."
          Process::GID.change_privilege(Etc.getgrnam(@opts[:group]).gid)
        end

        if @opts[:user]
          puts "Changing user to #{@opts[:user]}."
          Process::UID.change_privilege(Etc.getpwnam(@opts[:user]).uid)
        end
      rescue Errno::EPERM
        puts "FAILED to change user:group #{@opts[:user]}:#{@opts[:group]}: #$!"
        exit 1
      end

      Dir.mkdir(@opts[:working_dir]) unless File.directory?(@opts[:working_dir])
      Dir.mkdir(@opts[:logdir]) unless File.directory?(@opts[:logdir])
      Dir.mkdir(@opts[:etcdir]) unless File.directory?(@opts[:etcdir])

      if @opts[:daemon]
        Daemonize.daemonize(log_file=@opts[:logfile])
        # change back to the original starting directory
        Dir.chdir(@opts[:working_dir])
      end

      # Write pidfile
      open(@opts[:pidfile],"w") {|f| f.write(Process.pid) }

      if @opts[:queue] == 'dbm'
        qstore=StompServer::DBMQueue.new(@opts[:storage])
      elsif @opts[:queue] == 'file'
        qstore=StompServer::FileQueue.new(@opts[:storage])
      elsif @opts[:queue] == 'activerecord'
        require 'stomp_server/queue/activerecord_queue'
        qstore=StompServer::ActiveRecordQueue.new(@opts[:etcdir], @opts[:storage])
      else
        qstore=StompServer::MemoryQueue.new
      end
      qstore.checkpoint_interval = @opts[:checkpoint]
      puts "Checkpoing interval is #{qstore.checkpoint_interval}" if $DEBUG
      @topic_manager = StompServer::TopicManager.new
      @queue_manager = StompServer::QueueManager.new(qstore)
      @auth_required = @opts[:auth]

      if @auth_required
        @stompauth = StompServer::StompAuth.new(@opts[:passwd])
      end

      trap("INT") { puts "INT signal received.";stop(@opts[:pidfile]) }
    end
  end
end

