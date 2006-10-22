
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
# The storage class MAY implement the monitor() method.  monitor() should return a hash of hashes containing the queue statistics.
# See the file queue for an example.
#

require 'socket'
require 'resolv-replace'

class QueueMonitor

  def initialize(qstore,queues)
    @qstore = qstore
    @queues = queues
  end

  def start
    EventMachine.defer(proc {monitor})
  end

  def monitor
    loop do
      sleep 5
      next unless @qstore.methods.include?('monitor')
      users = @queues['/queue/monitor']
      next if users.size == 0
      stats = @qstore.monitor
      next if stats.size == 0
      body = ''

      stats.each do |queue,qstats|
        body << "Queue: #{queue}\n"
        qstats.each {|stat,value| body << "#{stat}: #{value}\n"}
        body << "\n"
      end

      headers = {
        'message-id' => "stompstats-#{sprintf("%.6f", Time.now.to_f).to_s}",
        'destination' => '/queue/monitor',
        'content-length' => body.size.to_s
      }

      frame = StompFrame.new('MESSAGE', headers, body)
      users.each {|user| user.user.send_data(frame.to_s)}
    end
  end
end


class QueueManager
  Struct::new('QueueUser', :user, :ack)
  
  def initialize(qstore)
    @qstore = qstore
    @queue_stats = Hash.new
    @queues = Hash.new { Array.new }
    @pending = Hash.new { Array.new }
    system_id = 'stompserver_' + Socket.gethostname.to_s + '_' + self.object_id.to_s
    @qstore.set_system_id(system_id)
    monitor = QueueMonitor.new(@qstore,@queues)
    monitor.start
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
