require 'queue_manager'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST
require 'tesly'

class TestQueues < Test::Unit::TestCase
  
  class UserMock
    attr_accessor :data
    def initialize ; @data = '' ; end
    def send_data(data); @data += data ; end
  end
  
  class MessageMock
    attr_accessor :headers, :data, :command
    def initialize(dest, msg, id=1)  
      @headers = { 'destination' => dest, 'message-id' => id }
      @data = msg
    end
    def to_s ; @data ; end
  end

  FileUtils.rm Dir.glob(".test_queue/*") rescue nil
  @@journal = FrameJournal.new(".test_queue")
  
  def setup
    #needs a journal
    @@journal.clear
    @t = QueueManager.new(@@journal)
  end

  def test_subscribe
    u = UserMock.new
    t = 'foo'
    @t.subscribe(t, u)
    
    m1 = MessageMock.new('foo', 'foomsg')
    m2 = MessageMock.new('bar', 'barmsg')
    @t.sendmsg(m1)
    assert_equal(m1.data, u.data)
    
    u.data = ''
    @t.sendmsg(m2)
    assert_equal('', u.data)
  end

  def test_subscribe2
    t = 'sub2'
    m1 = MessageMock.new(t, 'sub2msg')
    @t.sendmsg(m1)
    
    u = UserMock.new
    @t.subscribe(t, u)
    
    assert_equal(m1.data, u.data)
  end

  def test_unsubscribe
    u = UserMock.new
    t = 'foo'
    @t.subscribe(t, u)
    
    m1 = MessageMock.new('foo', 'foomsg')
    @t.sendmsg(m1)
    assert_equal(m1.data, u.data)

    @t.unsubscribe(t,u)
    u.data = ''
    @t.sendmsg(m1)
    assert_equal('', u.data)        
  end

  def test_sendmsg(msg)
    u = UserMock.new
    t = 'foo'
    @t.subscribe(t, u)
    
    m1 = MessageMock.new('foo', 'foomsg')
    @t.sendmsg(m1)
    assert_equal(m1.data, u.data)
    assert_equal('MESSAGE', m1.command)
  end

end