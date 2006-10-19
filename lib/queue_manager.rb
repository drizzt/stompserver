
class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(qstore)
    @qstore = qstore
    @shutdown = false
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
  end  

  def stop
    @shutdown = true
    @qstore.stop if @queues.empty?
  end

  def subscribe(dest, user, use_ack=false)
    user = Struct::QueueUser.new(user, use_ack)
    @queues[dest] += [user]
    send_backlog(dest,user)
  end
  
  def send_backlog(dest,user)
    while frame = @qstore.dequeue(dest)
      send_to_user(frame, user)
    end
  end

  def unsubscribe(dest, user)
    @queues.each do |dest, queue|
      queue.delete_if { |qu| qu.user == user }
      @queues.delete(dest) if queue.empty?
    end
  end
  
  def ack(user, frame)
    pending_size = @pending[user]
    @pending[user].delete_if { |pf| pf.headers['message-id'] == frame.headers['message-id'] }
    raise "Message (#{frame.headers['message-id']}) not found" if pending_size == @pending[user]
  end

  def disconnect(user)
    @pending[user].each do |frame|
      sendmsg(frame)
    end

    @queues.each do |dest, queue|
      queue.delete_if { |qu| qu.user == user }
      @queues.delete(dest) if queue.empty?
    end

    if @shutdown and @queues.empty?
      @qstore.stop
    end
  end
    
  def send_to_user(frame, user)
    if user.ack
      @pending[user.user] += [frame]
    end 
    user.user.send_data(frame.to_s)
    p "send_to_user #{frame.to_s}" if $DEBUG
  end
  
  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    @qstore.enqueue(dest,frame)

    if user = @queues[dest].shift
      if frame = @qstore.dequeue(dest)
        send_to_user(frame, user)
      end
      @queues[dest].push(user)
    end
  end  
end
