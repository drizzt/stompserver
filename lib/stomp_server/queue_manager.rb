
# QueueManager is used in conjunction with a storage class.  The storage class MUST implement the following two methods:
#
# - enqueue(queue name, frame)
# enqueue pushes a frame to the top of the queue in FIFO order. It's return value is ignored. enqueue must also set the 
# message-id and add it to the frame header before inserting the frame into the queue.
#
# - dequeue(queue name)
# dequeue removes a frame from the bottom of the queue and returns it.
#
# The storage class MAY implement the stop() method which can be used to do any housekeeping that needs to be done before 
# stompserver shuts down. stop() will be called when stompserver is shut down.
#
# The storage class MAY implement the monitor() method.  monitor() should return a hash of hashes containing the queue statistics.
# See the file queue for an example. Statistics are available to clients in /queue/monitor.
#

module StompServer
class QueueMonitor

  def initialize(qstore,queues)
    @qstore = qstore
    @queues = queues
    @stompid = StompServer::StompId.new
    puts "QueueManager initialized"
  end

  def start
    count =0
    EventMachine::add_periodic_timer 5, proc {count+=1; monitor(count) }
  end

  def monitor(count)
    return unless @qstore.methods.include?('monitor')
    users = @queues['/queue/monitor']
    return if users.size == 0
    stats = @qstore.monitor
    return if stats.size == 0
    body = ''

    stats.each do |queue,qstats|
      body << "Queue: #{queue}\n"
      qstats.each {|stat,value| body << "#{stat}: #{value}\n"}
      body << "\n"
    end

    headers = {
      'message-id' => @stompid[count],
      'destination' => '/queue/monitor',
      'content-length' => body.size.to_s
    }

    frame = StompServer::StompFrame.new('MESSAGE', headers, body)
    users.each {|user| user.user.stomp_send_data(frame)}
  end
end

class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(qstore)
    @qstore = qstore
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    if $STOMP_SERVER
      monitor = StompServer::QueueMonitor.new(@qstore,@queues)
      monitor.start
      puts "Queue monitor started" if $DEBUG
    end
  end  

  def stop
    @qstore.stop if @qstore.methods.include?('stop')
  end

  def subscribe(dest, user, use_ack=false)
    user = Struct::QueueUser.new(user, use_ack)
    @queues[dest] += [user]
    send_backlog(dest,user) unless dest == '/queue/monitor'
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
    pending_size = @pending[user].size
    @pending[user].delete_if { |pf| pf.headers['message-id'] == frame.headers['message-id'] }
    raise "Message (#{frame.headers['message-id']}) not found" if pending_size == @pending[user].size
  end

  def disconnect(user)
    while frame = @pending[user].pop
      @qstore.requeue(frame.headers['destination'],frame)
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
    user.user.stomp_send_data(frame)
  end
  
  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    @qstore.enqueue(dest,frame)

    if user = @queues[dest].shift
      if user.user.connected?
        if frame = @qstore.dequeue(dest)
          send_to_user(frame, user)
        end
      end
      @queues[dest].push(user)
    end
  end  
end
end
