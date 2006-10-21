
# QueueManager is used in conjunction with a storage class.  The storage class MUST implement the following two methods:
#
# - enqueue(queue name, frame)
# enqueue pushes a frame to the top of the queue in FIFO order. It's return value is ignored. enqueue must also generate the 
# message-id and add it to the frame header before inserting the frame into the queue.
#
# - dequeue(queue name)
# dequeue removes a frame from the bottom of the queue and returns it.
#
# The storage class MAY implement the stop() method which can be used to do any housekeeping that needs to be done before 
# stompserver shuts down. stop() will be called when stompserver is shut down.
#
require 'socket'
require 'resolv-replace'

class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(qstore)
    @qstore = qstore
    @shutdown = false
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    system_id = 'stompserver_' + Socket.gethostname.to_s + '_' + self.object_id.to_s
    @qstore.set_system_id(system_id)
  end  

  def stop
    @shutdown = true
    @qstore.stop if @qstore.methods.include?('stop')
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
    @queues.each do |d, queue|
      queue.delete_if { |qu| qu.user == user and d == dest}
    end
    @queues.delete(dest) if @queues[dest].empty?
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
  end
    
  def send_to_user(frame, user)
    if user.ack
      @pending[user.user] += [frame]
    end 
    user.user.send_data(frame.to_s)
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
