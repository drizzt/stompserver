require 'frame_journal'
require 'test/unit' unless defined? $ZENTEST and $ZENTEST

class TestFrameJournal < Test::Unit::TestCase
  def setup
    MockFS.mock = true   
    MockFS.flush
    MockFS.fill_path '.'
  end
  
  def test_directory_create
    MockFS.mock_file_system.flush
    MockFS.fill_path '.'
    p
    
    fj = FrameJournal.new('foo/bar')
    assert(MockFS.file.exist?('foo/bar'))
    assert(!MockFS.file.exist?('bar'))
    assert(MockFS.file.directory?('foo'))
    assert(MockFS.file.directory?('foo/bar'))
    
    assert(MockFS.file.exist?('foo/bar/fjf0000.dat'))
    assert(!MockFS.file.exist?('foo/bar/fjf0001.dat'))
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
