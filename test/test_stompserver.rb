require 'stompserver'
require 'test/unit'

class TestStompServer < Test::Unit::TestCase
  def test_version
    assert(StompServer.const_defined?(:VERSION))
  end
end