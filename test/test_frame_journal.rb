require 'frame_journal'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST

class TestFrameJournal < Test::Unit::TestCase
  def init
    MockFS.mock = true   
  end
  
  def test_directory_create
    fj = FrameJournal.new('/foo/bar')
    assert(MockFS.file.exist?('/foo/bar'))
    assert(!MockFS.file.exist?('bar'))
    assert(MockFS.file.directory?('/foo'))
    assert(MockFS.file.directory?('/foo/bar'))
    
    assert(MockFS.file.exist?('/foo/bar/fjf0001.dat2'))
  end
  
  def test_journal
  end

  def test_pending
  end

  def test_release
  end

  def test_rollover
  end
end

