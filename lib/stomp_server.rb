require 'rubygems'
require 'eventmachine'
require 'dbm'
require 'stomp_frame'
require 'stomp_id'
require 'stomp_auth'
require 'topic_manager'
require 'queue_manager'
require 'memory_queue'
require 'file_queue'
require 'dbm_queue'

module StompServer
  VERSION = '0.9.3'
  VALID_COMMANDS = [:connect, :send, :subscribe, :unsubscribe, :begin, :commit, :abort, :ack, :disconnect]
  trap("INT") { p "INT signal received.";stop }

  def self.setup(qs = MemoryQueue.new, auth_required=false,  tm = TopicManager.new, qm = QueueManager.new(qs))
    @@auth_required = auth_required
    @@queue_storage = qs
    @@topic_manager = tm
    @@queue_manager = qm
    if @@auth_required
      @@auth = StompAuth.new
    end
  end

  def self.stop
    @@queue_manager.stop
    p "Stompserver shutting down" if $DEBUG
    EventMachine::stop_event_loop
  end

  def post_init
    @sfr = StompFrameRecognizer.new
    @transactions = {}
    @connected = false
  end
  
  def receive_data(data)
    begin
      puts "receive_data: #{data.inspect}" if $DEBUG
      @sfr << data
      process_frames
    rescue Exception => e
      puts "err: #{e} #{e.backtrace.join("\n")}"
      send_error(e.to_s)
      close_connection_after_writing
    end
  end
  
  def process_frames
    frame = nil
    process_frame(frame) while frame = @sfr.frames.shift
  end
  
  def process_frame(frame)
    cmd = frame.command.downcase.to_sym
    raise "Unhandled frame: #{cmd}" unless VALID_COMMANDS.include?(cmd)
    raise "Not connected" if !@connected && cmd != :connect

    # I really like this code, but my needs are a little trickier
    # 

    if trans = frame.headers['transaction']
      handle_transaction(frame, trans, cmd)
    else
      cmd = :sendmsg if cmd == :send
      send(cmd, frame) 
    end
    
    send_receipt(frame.headers['receipt']) if frame.headers['receipt']
  end
  
  def handle_transaction(frame, trans, cmd)
    if [:begin, :commit, :abort].include?(cmd)
      send(cmd, frame, trans)
    else
      raise "transaction does not exist" unless @transactions.has_key?(trans)
      @transactions[trans] << frame
    end    
  end
  
  def connect(frame)
    if @@auth_required
      unless frame.headers['login'] and frame.headers['passcode'] and  @@auth.authorized[frame.headers['login']] == frame.headers['passcode']
        raise "Invalid Login"
      end
    end
    puts "Connecting" if $DEBUG
    response = StompFrame.new("CONNECTED", {'session' => 'wow'})
    send_data(response.to_s)
    @connected = true
  end
  
  def sendmsg(frame)
    # set message id
    if frame.dest.match(%r|^/queue|)
      @@queue_manager.sendmsg(frame)
    else
      frame.headers['message-id'] = "msg-#stompcma-#{@@topic_manager.next_index}"
      @@topic_manager.sendmsg(frame)
    end
  end
  
  def subscribe(frame)
    if frame.dest =~ %r|^/queue|
      @@queue_manager.subscribe(frame.dest, self)
    else
      @@topic_manager.subscribe(frame.dest, self)
    end
  end
  
  def unsubscribe(frame)
    if frame.dest =~ %r|^/queue|
      @@queue_manager.unsubscribe(frame.dest,self)
    else
      @@topic_manager.unsubscribe(frame.dest,self)
    end
  end
  
  def begin(frame, trans=nil)
    raise "Missing transaction" unless trans
    raise "transaction exists" if @transactions.has_key?(trans)
    @transactions[trans] = []
  end
  
  def commit(frame, trans=nil)
    raise "Missing transaction" unless trans
    raise "transaction does not exist" unless @transactions.has_key?(trans)
    
    (@transactions[trans]).each do |frame|
      frame.headers.delete('transaction')
      process_frame(frame)
    end
    @transactions.delete(trans)
  end
  
  def abort(frame, trans=nil)
    raise "Missing transaction" unless trans
    raise "transaction does not exist" unless @transactions.has_key?(trans)
    @transactions.delete(trans)
  end
  
  def ack(frame)
    @@queue_manager.ack(self, frame)
  end
  
  def disconnect(frame)
    puts "Polite disconnect" if $DEBUG
    close_connection_after_writing
  end

  def unbind
    p "Unbind called" if $DEBUG
    @@queue_manager.disconnect(self)
    @@topic_manager.disconnect(self)
  end
  
  def send_message(msg)
    msg.command = "MESSAGE"
    send_data(msg.to_s)
  end
    
  def send_receipt(id)
    send_frame("RECEIPT", { 'receipt-id' => id})
  end
  
  def send_error(msg)
    send_frame("ERROR",{'message' => 'See below'},msg)
  end
  
  def send_frame(command, headers={}, body='')
    headers['content-length'] = body.size.to_s
    response = StompFrame.new(command, headers, body)
    send_data(response.to_s)
    p "send_frame #{response.to_s}" if $DEBUG
  end

end

if $0 == __FILE__
  StompServer.setup
  EventMachine::run do
    EventMachine.start_server "0.0.0.0", 61613, StompServer
  end
end
