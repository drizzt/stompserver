require 'queue_manager'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST
require 'tesly'

class TestQueues < Test::Unit::TestCase
  
  def test_foo
    assert(true)
  end
  
end