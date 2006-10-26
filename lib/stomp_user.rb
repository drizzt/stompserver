
# Used when accessing queues/topics outside of EM
require 'stomp_id'
require 'stomp_frame'
$MULTIUSER = true

class StompUser
  attr_accessor :data
  def initialize
    @data = []
  end
  def send_frame_data(data)
    @data << data.to_s
  end
end

