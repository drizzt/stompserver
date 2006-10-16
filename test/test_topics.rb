require 'topics'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST

class TestTopics < Test::Unit::TestCase

  class UserMock
    attr_accessor :data
    def initialize ; @data = '' ; end
    def send_data(data); @data += data ; end
  end
  
  class MessageMock
    attr_accessor :headers, :data, :command
    def initialize(dest, msg)  
      @headers = { 'destination' => dest }
      @data = msg
    end
    def to_s ; @data ; end
  end
  
  def setup
    @t = TopicManager.new
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

