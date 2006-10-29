
module StompServer
module StompServer::Protocols
VALID_COMMANDS = [:connect, :send, :subscribe, :unsubscribe, :begin, :commit, :abort, :ack, :disconnect]

class Stomp < EventMachine::Connection

  def initialize *args
    super
  end

  def post_init
    @sfr = StompServer::StompFrameRecognizer.new
    @transactions = {}
    @connected = false
  end

  def receive_data(data)
    stomp_receive_data(data)
  end
 
  def stomp_receive_data(data)
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
 
  def stomp_receive_frame(frame)
    begin
      puts "receive_frame: #{frame.inspect}" if $DEBUG
      process_frame(frame)
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
      unless frame.headers['login'] and frame.headers['passcode'] and  @@stompauth.authorized[frame.headers['login']] == frame.headers['passcode']
        raise "Invalid Login"
      end
    end
    puts "Connecting" if $DEBUG
    response = StompServer::StompFrame.new("CONNECTED", {'session' => 'wow'})
    stomp_send_data(response)
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
    use_ack = false
    use_ack = true  if frame.headers['ack'] == 'client'
    if frame.dest =~ %r|^/queue|
      @@queue_manager.subscribe(frame.dest, self,use_ack)
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
    @connected = false
    @@queue_manager.disconnect(self)
    @@topic_manager.disconnect(self)
  end
 
  def connected?
    @connected
  end
 
  def send_message(msg)
    msg.command = "MESSAGE"
    stomp_send_data(msg)
  end
    
  def send_receipt(id)
    send_frame("RECEIPT", { 'receipt-id' => id})
  end
  
  def send_error(msg)
    send_frame("ERROR",{'message' => 'See below'},msg)
  end
 
  def stomp_send_data(frame)
    send_data(frame.to_s)
    puts "Sending frame #{frame.to_s}" if $DEBUG
  end

  def send_frame(command, headers={}, body='')
    headers['content-length'] = body.size.to_s
    response = StompServer::StompFrame.new(command, headers, body)
    stomp_send_data(response)
  end
end

end
end
