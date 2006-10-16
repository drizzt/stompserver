require 'stomp_server'
require 'test/unit'

class TestStompServer < Test::Unit::TestCase
  
  # Is it a mock? it is what we are testing, but of 
  # course I am really testing the module, so I say
  # yes it is a mock :-)
  class MockStompServer
    include StompServer
    attr_accessor :sent, :connected
    
    def initialize
      @sent = ''
      @connected = true
    end
    
    def send_data(data)
      @sent += data
    end
    
    def close_connection_after_writing
      @connected = false
    end
    alias close_connection close_connection_after_writing
  end
  
  def setup
    @ss = MockStompServer.new
    @ss.post_init
  end  

  def test_version
    assert(StompServer.const_defined?(:VERSION))
  end
  
  def test_invalid_command
    sf = StompFrame.new('INVALID')
    assert_nothing_raised do
      @ss.receive_data(sf.to_s)
    end
    assert_match(/ERROR/, @ss.sent)
    assert(!@ss.connected)
  end
  
  def test_unconnected_command
    sf = StompFrame.new('SEND',{}, 'body')
    assert_nothing_raised do
      @ss.receive_data(sf.to_s)
    end
    assert_match(/ERROR/, @ss.sent)
    assert(!@ss.connected)
  end
  
  def test_connect
    sf = StompFrame.new('CONNECT')
    assert_nothing_raised do
      @ss.receive_data(sf.to_s)
    end
    assert_match(/CONNECTED/, @ss.sent)
    assert(@ss.connected)
  end
  
  def test_disconnect
    test_connect # get connected
    
    sf = StompFrame.new('DISCONNECT')
    assert_nothing_raised do
      @ss.receive_data(sf.to_s)
    end
    assert(!@ss.connected)
  end
  
  def test_receipt
    sf = StompFrame.new('CONNECT')
    assert_nothing_raised do
      @ss.receive_data(sf.to_s)
    end
    assert_match(/CONNECTED/, @ss.sent)
    assert(@ss.connected)
    
    sf.command = 'SUBSCRIBE'
    sf.headers['receipt'] = 'foobar'
    assert_nothing_raised do
      @ss.receive_data(sf.to_s)
    end
    
    assert_match(/RECEIPT/, @ss.sent)
    assert_match(/receipt-id:foobar/, @ss.sent)
    
    assert(@ss.connected)    
  end
  
end