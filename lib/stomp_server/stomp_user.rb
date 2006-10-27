
# Used when accessing queues/topics outside of EM
require 'stomp_id'
require 'stomp_frame'
$MULTIUSER = true

module StompServer
class StompUser
  attr_accessor :data
  def initialize
    @data = []
  end
  def stomp_send_data(data)
    @data << data.to_s
  end
end
end
