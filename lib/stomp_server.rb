require 'eventmachine'
require 'stompframe'
require 'topics'
require 'queues'

module StompServer
  VERSION = '1.0.0'
  VALID_COMMANDS = %W(CONNECT SEND SUBSCRIBE UNSUBSCRIBE BEGIN COMMIT ABORT ACK DISCONNECT)
  @@queues = {}
  @@delivered = []
  @@subscriptions = {}
  
  # subscription ack/auto
    
  def post_init
    @sfr = StompFrameRecognizer.new
  end
  
  def receive_data(data)
    begin
      puts "receive_data: #{data.inspect}" if $DEBUG
      @sfr << data
      process_frames
    rescue Exception => e
      puts "err: #{e} #{e.backtrace.join("\n")}" if $DEBUG
      send_error(e.to_s)
      close_connection_after_writing
    end
  end
  
  def process_frames
    frame = nil
    process_frame(frame) while frame = @sfr.frames.shift
  end
  
  def process_frame(frame)
    if VALID_COMMANDS.include?(frame.command)
      __send__ frame.command.downcase, frame
      send_receipt(frame.headers['receipt']) if frame.headers['receipt']
    else
      raise "Unhandled frame: #{frame.command}"
    end
  end
  
  def connect(frame)
    puts "Connecting" if $DEBUG
    response = StompFrame.new("CONNECTED", {'session' => 'wow'})
    send_data(response.to_s)
  end
  
  def send(frame)
    dest = frame.headers['destination']
    if @@queues.key?(dest)
      @@queues[frame.headers['destination']] << frame.body
    else
      @@queues[frame.headers['destination']] = [frame.body]
    end
    p @@queues
  end
  
  def subscribe(frame)
  end
  
  def unsubscribe(frame)
  end
  
  def begin(frame)
  end
  
  def commit(frame)
  end
  
  def abort(frame)
  end
  
  def ack(frame)
  end
  
  def disconnect(frame)
    puts "Polite disconnect" if $DEBUG
    close_connection_after_writing
  end

  def send_message(msg)
    msg.command = "MESSAGE"
    send_data(msg.to_s)
  end
    
  def send_receipt(id)
    send_frame("RECEIPT", { 'receipt-id' => id})
  end
  
  def send_error(msg)
    send_frame("ERROR",{},msg)
  end
  
  def send_frame(command, headers={}, body='')
    response = StompFrame.new(command, headers, body)
    send_data(response.to_s)
  end  
end

if $0 == __FILE__
  EventMachine::run do
    EventMachine.start_server "0.0.0.0", 61613, StompServer
  end
end
