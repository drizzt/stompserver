
class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(storage='memory')
    p "Storage=#{storage}" if $DEBUG
    if storage == 'bdb'
      @qstore = BDBQueue.new
    else
      @qstore = MemoryQueue.new
    end
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

  ## Send messages in memory first
    until queue.empty?
      current_frame = queue.first
      send_to_user(current_frame, user)
      queue.shift
    end 

  ## Send messages from storage that aren't in memory
    while current_frame = @qstore.get_next_message(dest)
      send_to_user(current_frame, user)
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
    @qstore.delete_message(dest,msgid.to_s)
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
      @pending[user.user] += [frame]
    else
      @qstore.delete_message(frame.headers['destination'],frame.headers['message-id'].to_s)
    end 
    user.user.send_data(frame.to_s)
  end
  
  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    @qstore.open_queue(dest)
    frame.headers['message-id'] = @qstore.add_message(dest,frame)

    if user = @queues[dest].shift
      send_to_user(frame, user)
      @queues[dest].push(user)
    else
      @messages[dest] += [frame]
    end
  end  
end
