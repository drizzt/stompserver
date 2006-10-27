require 'stomp_server/stomp_frame'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST

class TestStompFrame < Test::Unit::TestCase
  def setup
    @sfr = StompServer::StompFrameRecognizer.new
  end
  
  def test_simpleframe
    @sfr << <<FRAME
COMMAND
name:value
foo:bar

message body
\000
FRAME
    assert_equal(1, @sfr.frames.size)
    f = @sfr.frames.shift
    assert_equal(0, @sfr.frames.size)
    assert_equal("COMMAND", f.command)
    assert_equal("value", f.headers["name"])
    assert_equal("bar", f.headers["foo"])
    assert_equal("message body\n", f.body)
  end
  
  def test_doubleframe
    @sfr << <<FRAME
COMMAND
name:value
foo:bar

message body
\000

COMMAND2
name2:value2
foo2:bar2

message body 2
\000
FRAME
    assert_equal(2, @sfr.frames.size)
    f = @sfr.frames.shift
    assert_equal(1, @sfr.frames.size)
    assert_equal("COMMAND", f.command)
    assert_equal("value", f.headers["name"])
    assert_equal("bar", f.headers["foo"])
    assert_equal("message body\n", f.body)
    
    # check second frame
    f = @sfr.frames.shift
    assert_equal(0, @sfr.frames.size)
    assert_equal("COMMAND2", f.command)
    assert_equal("value2", f.headers["name2"])
    assert_equal("bar2", f.headers["foo2"])
    assert_equal("message body 2\n", f.body)
  end
  
    def test_partialframe
    @sfr << <<FRAME
COMMAND
name:value
foo:bar

message body
\000

COMMAND2
name2:value2
foo2:bar2

message body 2
FRAME
    assert_equal(1, @sfr.frames.size)
    f = @sfr.frames.shift
    assert_equal(0, @sfr.frames.size)
    assert_equal("COMMAND", f.command)
    assert_equal("value", f.headers["name"])
    assert_equal("bar", f.headers["foo"])
    assert_equal("message body\n", f.body)    
  end

  def test_partialframe2
    @sfr << <<FRAME
COMMAND
name:value
foo:bar
FRAME
    assert_equal(0, @sfr.frames.size)
  end
  
  def test_headless_frame
    @sfr << <<FRAME
COMMAND

message body\000
FRAME
    assert_equal(1, @sfr.frames.size)
    f = @sfr.frames.shift
    assert_equal(0, @sfr.frames.size)
    assert_equal("COMMAND", f.command)
    assert_equal("message body", f.body)    
  end

  def test_destination_cache
    @sfr << <<FRAME
MESSAGE
destination: /queue/foo

message body\000
FRAME
    assert_equal(1, @sfr.frames.size)
    f = @sfr.frames.shift
    assert_equal(0, @sfr.frames.size)
    assert_equal("MESSAGE", f.command)
    assert_equal("message body", f.body)
    assert_equal('/queue/foo', f.dest)    
  end  
end
