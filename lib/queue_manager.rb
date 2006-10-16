# queue - persistent sent to a single subscriber
# queue_monitor - looks, but does not remove from queue

class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(journal)
    # read journal information
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    @messages = Hash.new { Array.new }
  end  

  def subscribe(dest, user, use_ack=false)
    user = Struct::QueueUser.new(user, use_ack)
    @queues[dest] += [user]
    @messages[dest].each do |frame|
      send_to_user(frame, user)
    end
  end
  
  def unsubscribe(topic, user)
    @queues[topic].delete_if { |u| u.user == user } 
  end
  
  def ack(user, frame)
    pending_size = @pending[user]
    msgid = frame.headers['message-id']
    @pending[user].delete_if { |pf| pf.headers['message-id'] == msgid }
    raise "Message (#{msgid}) not found" if pending_size == @pending[user]
  end

  def disconnect(user)
    @pending[user].each do |frame|
      sendmsg(frame)
    end
  end
    
  def send_to_user(frame, user)
    @pending[user.user] += [frame] if user.ack
    user.user.send_data(frame.to_s)
  end
  
  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']

    if user = @queues[dest].shift
      send_to_user(frame, user)
      @queues[dest].push(user)
    else
      @messages[dest] += [frame]
    end
  end  
end
