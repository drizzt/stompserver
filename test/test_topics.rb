require 'topics'
require 'test/unit'

class TestTopics < Test::Unit::TestCase

  def setup
    @t = TopicManager.instance
  end
    
  def test_singleton
    assert_equal(@t, TopicManager.instance)
  end
  
end