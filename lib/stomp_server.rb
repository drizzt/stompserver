require 'rubygems'
require 'eventmachine'
require 'stomp_server/stomp_frame'
require 'stomp_server/stomp_id'
require 'stomp_server/stomp_auth'
require 'stomp_server/topic_manager'
require 'stomp_server/queue_manager'
require 'stomp_server/memory_queue'
require 'stomp_server/file_queue'
require 'stomp_server/dbm_queue'
require 'stomp_server/protocols/stomp'
require 'stomp_server/protocols/test'

module StompServer
  VERSION = '0.9.3'
  VALID_COMMANDS = [:connect, :send, :subscribe, :unsubscribe, :begin, :commit, :abort, :ack, :disconnect]

  def self.setup(qm)
    @@queue_manager = qm
  end

  def self.stop
    @@queue_manager.stop
    p "Stompserver shutting down" if $DEBUG
    EventMachine::stop_event_loop
  end
end

