# topic - non persistent, sent to all interested parties

module StompServer
class TopicManager
  attr_accessor :frame_index
  def initialize
    @frame_index =0
    @topics = Hash.new { Array.new }
  end  

  def index
    @frame_index
  end

  def next_index
    @frame_index += 1
  end

  def subscribe(topic, user)
    @topics[topic] += [user]
  end
  
  def unsubscribe(topic, user)
    @topics[topic].delete(user) 
  end
  
  def disconnect(user)
    @topics.each do |dest, queue|
      queue.delete_if { |qu| qu == user }
    end
  end
  
  def sendmsg(msg)
    msg.command = "MESSAGE"
    topic = msg.headers['destination']
    @topics[topic].each do |user|
      user.stomp_send_data(msg)
    end
  end  
end
end
