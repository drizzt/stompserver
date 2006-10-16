# queue - persistent sent to a single subscriber
# queue_monitor - looks, but does not remove from queue

class QueueManager
  def initialize
    # read journal information
    @queues = Hash.new { Array.new }
    @monitors = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    @messages = Hash.new { Array.new }
  end  

  def subscribe(dest, user)
    @queues[dest] += [user]
  end
  
  def monitor(dest, user)
    @monitors[dest] += [user]
  end
  
  def unsubscribe(topic, user)
    @queues[topic].delete(user) 
  end
  
  def unmonitor(topic, user)
    @monitors[topic].delete(user) 
  end
  
  def send(msg)
    msg.command = "MESSAGE"
    topic = msg.headers['destination']
    payload = msg.to_s
    @monitors[topic].each do |user|
      user.send_data(payload)
    end
    
    # handle queues
  end  
end