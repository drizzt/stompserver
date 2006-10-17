# queue - persistent sent to a single subscriber
# queue_monitor - looks, but does not remove from queue

class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(journal)
    # read journal information
    @journal = journal
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    @messages = Hash.new { Array.new }
    
    # recover from previous run
    msgids = @journal.keys.sort
    msgids.each do |msgid|
      sendmsg(@journal[msgid])
    end
  end  

  def subscribe(dest, user, use_ack=false)
    user = Struct::QueueUser.new(user, use_ack)
    @queues[dest] += [user]
    
    # TODO handle this is some form of call back
    # it is quite possible that this could be a lot
    # of data and block things up.
    send_backlog(@messages[dest], user)
  end
  
  def send_backlog(queue, user)
    until queue.empty?
      current = queue.first
      send_to_user(current, user)
      queue.shift
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
    @journal.delete(msgid)
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
      @journal.delete(frame.headers['message-id'])
    end 
    user.user.send_data(frame.to_s)
  end
  
  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    @journal[frame.headers['message-id']] = frame

    if user = @queues[dest].shift
      send_to_user(frame, user)
      @queues[dest].push(user)
    else
      @messages[dest] += [frame]
    end
  end  
end
