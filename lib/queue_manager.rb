
class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(qstore)
    @qstore = qstore
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    @messages = Hash.new { Array.new }
  end  

  def subscribe(dest, user, use_ack=false)
    user = Struct::QueueUser.new(user, use_ack)
    @queues[dest] += [user]
    @qstore.open_queue(dest)
    send_backlog(dest,@messages[dest], user)
  end
  
  def send_backlog(dest,queue, user)
  ## Send messages from storage first.
    while current_frame = @qstore.dequeue(dest)
      send_to_user(current_frame, user)
    end

  ## Send messages in memory second
    until queue.empty?
      current_frame = queue.first
      send_to_user(current_frame, user)
      queue.shift
    end 
  end

  def unsubscribe(topic, user)
    @queues[topic].delete_if { |u| u.user == user } 
  end
  
  def ack(user, frame)
    pending_size = @pending[user]
    msgid = frame.headers['message-id']
    dest = frame.headers['destination']
    @pending[user].delete_if { |pf| pf.headers['message-id'] == msgid }
    raise "Message (#{msgid}) not found" if pending_size == @pending[user]
  end

  def disconnect(user)
    @pending[user].each do |frame|
      sendmsg(frame)
    end

    @queues.each do |dest, queue|
      queue.delete_if { |qu| qu.user == user }
    end
  end
    
  def send_to_user(frame, user)
    if user.ack
      @pending[user.user].push([frame])
    end 
    user.user.send_data(frame.to_s)
  end
  
  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    @qstore.open_queue(dest)
    frame.headers['message-id'] = @qstore.enqueue(dest,frame)

    if user = @queues[dest].shift
      send_to_user(frame, user)
      @queues[dest].push(user)
    elsif @qstore.memory_cache
      @messages[dest].push([frame])
    end
  end  
end
