require 'stomp_server'
require 'fileutils'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST
require 'tesly'

#$DEBUG = true

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
    
    def stomp(cmd, headers={}, body='', flush_prev = true)
      @sent = '' if flush_prev
      sf = StompFrame.new(cmd, headers, body)
      receive_data(sf.to_s)
    end
    
    def do_connect(flush = true)
      stomp('CONNECT')
      @sent = '' if flush
    end
    
    def self.make_client(start_connection=true, flush=true)
      ss = MockStompServer.new
      ss.post_init
      ss.do_connect(flush) if start_connection
      ss
    end    
    
  end

  def assert_stomp_error(ss=@ss, match = nil)
    assert_match(/ERROR/, ss.sent)
    assert_match(match, ss.sent) if match
    assert(!ss.connected)
  end
  
  
  def setup
    @ss = MockStompServer.make_client
  end  
  
  def test_version
    assert(StompServer.const_defined?(:VERSION))
  end
  
  def test_invalid_command
    assert_nothing_raised do
      @ss.stomp('INVALID')
    end
    assert_stomp_error
  end
  
  def test_unconnected_command
    ss = MockStompServer.make_client(false)
    assert_nothing_raised do
      ss.stomp('SEND')
    end
    assert_stomp_error(ss)
  end
  
  def test_connect
    ss = MockStompServer.make_client(false)
    assert(!ss.connected)    
    assert_nothing_raised do
      ss.connect(false)
    end
    assert_match(/CONNECTED/, ss.sent)
    assert(ss.connected)
  end
  
  def test_disconnect
    assert_nothing_raised do
      @ss.stomp('DISCONNECT')
    end
    assert(!@ss.connected)
  end
  
  def test_receipt
    assert_nothing_raised do
      @ss.stomp('SUBSCRIBE', {'receipt' => 'foobar'})
    end
    
    assert_match(/RECEIPT/, @ss.sent)
    assert_match(/receipt-id:foobar/, @ss.sent)
    
    assert(@ss.connected)    
  end
  
  def test_topic
    assert_equal('', @ss.sent)
    
    # setup two clients (@ss and this one)
    ss2 = MockStompServer.make_client
    assert_equal('', ss2.sent)

    @ss.stomp('SEND', {'destination' => '/topic/foo'}, 'Hi Pat')
    @ss.stomp('SEND', {'destination' => '/topic/foo'}, 'Hi Sue')
    
    assert_equal('', @ss.sent)
    assert_equal('', ss2.sent)
    
    ss2.stomp("SUBSCRIBE", {'destination' => '/topic/foo'})
    assert_equal('', ss2.sent)
    
    @ss.stomp('SEND', {'destination' => '/topic/foo'}, 'Hi Pat')    
    assert_match(/Hi Pat/, ss2.sent)
    assert_equal('', @ss.sent)
  end
  
  def test_bad_topic
    assert_equal('', @ss.sent)
    
    # setup two clients (@ss and this one)
    ss2 = MockStompServer.make_client
    assert_equal('', ss2.sent)

    ss2.stomp("SUBSCRIBE", {'destination' => '/badtopic/foo'})
    assert_equal('', ss2.sent)
    
    @ss.stomp('SEND', {'destination' => '/badtopic/foo'}, 'Hi Pat')    
    assert_match(/Hi Pat/, ss2.sent)
    assert_equal('', @ss.sent)
  end
  
  def test_multiple_subscriber_topic
    assert_equal('', @ss.sent)
    
    # setup two clients (@ss and this one)
    ss2 = MockStompServer.make_client
    assert_equal('', ss2.sent)

    @ss.stomp("SUBSCRIBE", {'destination' => '/topic/foo'})
    ss2.stomp("SUBSCRIBE", {'destination' => '/topic/foo'})
    
    assert_equal('', @ss.sent)
    assert_equal('', ss2.sent)
    
    @ss.stomp('SEND', {'destination' => '/topic/foo'}, 'Hi Pat')
        
    assert_match(/Hi Pat/, ss2.sent)
    assert_match(/Hi Pat/, @ss.sent)
  end
 
  def test_invalid_transaction
    @ss.stomp("SEND", {'transaction' => 't'})
    assert_stomp_error
  end
  
  def test_simple_transaction
    ss1 = MockStompServer.make_client
    ss2 = MockStompServer.make_client
    
    ss2.stomp("SUBSCRIBE", {"destination" => '/topic/foo'})
    assert_equal('', ss2.sent)
        
    ss1.stomp("BEGIN", {"transaction" => 'simple'})
    ss1.stomp("SEND", {"transaction" => 'simple', 'destination' => '/topic/foo'}, 'Hi Pat')
    assert_equal('', ss2.sent)
    assert_equal('', ss1.sent)

    ss1.stomp("COMMIT", {"transaction" => 'simple'})    
    assert_equal('', ss1.sent)
    assert_match(/Hi Pat/, ss2.sent)
  end
  
  def test_simple_transaction2
    ss1 = MockStompServer.make_client
    ss2 = MockStompServer.make_client
    
    ss2.stomp("BEGIN", {"transaction" => 'simple'})
    ss2.stomp("SUBSCRIBE", {"transaction" => 'simple', "destination" => '/topic/foo'})
    assert_equal('', ss2.sent)
        
    ss1.stomp("SEND", {'destination' => '/topic/foo'}, 'Hi Pat')
    assert_equal('', ss2.sent)
    assert_equal('', ss1.sent)

    ss2.stomp("COMMIT", {"transaction" => 'simple'})    
    assert_equal('', ss1.sent)
    assert_equal('', ss2.sent)

    ss1.stomp("SEND", {'destination' => '/topic/foo'}, 'Hi Pat')
    assert_match(/Hi Pat/, ss2.sent)
  end

  def test_simple_abort_transaction
    ss1 = MockStompServer.make_client
    ss2 = MockStompServer.make_client
    
    ss2.stomp("BEGIN", {"transaction" => 'simple'})
    ss2.stomp("SUBSCRIBE", {"transaction" => 'simple', "destination" => '/topic/foo'})
    assert_equal('', ss2.sent)
        
    ss1.stomp("SEND", {'destination' => '/topic/foo'}, 'Hi Pat')
    assert_equal('', ss2.sent)
    assert_equal('', ss1.sent)

    ss2.stomp("ABORT", {"transaction" => 'simple'})    
    assert_equal('', ss1.sent)
    assert_equal('', ss2.sent)
    
    ss1.stomp("SEND", {'destination' => '/topic/foo'}, 'Hi Pat')
    assert_match('', ss2.sent)
  end
  
  def test_simple_queue_message
    ss1 = MockStompServer.make_client
    ss1.stomp("SEND", {'destination' => '/queue/foo'}, 'Hi Pat')
    ss1.stomp("DISCONNECT")

    ss2 = MockStompServer.make_client
    ss2.stomp("SUBSCRIBE", {"destination" => '/queue/foo'})
    assert_match(/Hi Pat/, ss2.sent)
  end
end
