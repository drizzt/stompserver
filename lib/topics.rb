# topic - non persistent, sent to all interested parties

require 'singleton'

class TopicManager
  include Singleton
    
  def initialize
    @topics = Hash.new { Array.new }
  end  

  def subscribe(topic, user)
    @topics[topic] += [user]
  end
  
  def unsubscribe(topic, user)
    @topics[topic].delete(user) 
  end
  
  def send(msg)
    msg.command = "MESSAGE"
    topic = msg.headers['destination']
    payload = msg.to_s
    @topics[topic].each do |user|
      user.send_data(payload)
    end
  end  
end