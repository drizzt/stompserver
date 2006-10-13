require 'eventmachine'
require 'lib/stompframe'

module StompServer
  VERSION = '1.0.0'
  
  def post_init
    @sfr = StompFrameRecognizer.new
  end
  
  def receive_data(data)
    puts "receive_data: #{data.inspect}"
    @sfr << data
    process_frame until @sfr.frames.empty?
  end
  
  def process_frame
    frame = @sfr.frames.shift
    case frame.command
    when "CONNECT"
      connect(frame)
    else
      puts "Unhandled frame: #{frame.command}"
    end
  end
  
  def connect(frame)
    puts "Connecting"
    response = StompFrame.new("CONNECTED", {'session' => 'wow'})
    send_data(response.to_s)
  end
end

if $0 == __FILE__
  EventMachine::run do
    EventMachine.start_server "0.0.0.0", 61613, StompServer
  end
end
