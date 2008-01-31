# QueueManager is used in conjunction with a storage class.  The storage class MUST implement the following two methods:
#
# - enqueue(queue name, frame)
# enqueue pushes a frame to the top of the queue in FIFO order. It's return value is ignored. enqueue must also set the 
# message-id and add it to the frame header before inserting the frame into the queue.
#
# - dequeue(queue name)
# dequeue removes a frame from the bottom of the queue and returns it.
#
# - requeue(queue name,frame)
# does the same as enqueue, except it puts the from at the bottom of the queue
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
    users.each {|user| user.connection.stomp_send_data(frame)}
  end
end

class QueueManager
  Struct::new('QueueUser', :connection, :ack)

  def initialize(qstore)
    @qstore = qstore
    @queues = Hash.new { Array.new }
    @pending = Hash.new
    if $STOMP_SERVER
      monitor = StompServer::QueueMonitor.new(@qstore,@queues)
      monitor.start
      puts "Queue monitor started" if $DEBUG
    end
  end

  def stop
    @qstore.stop if @qstore.methods.include?('stop')
  end

  def subscribe(dest, connection, use_ack=false)
    puts "Subscribing to #{dest}"
    user = Struct::QueueUser.new(connection, use_ack)
    @queues[dest] += [user]
    send_destination_backlog(dest,user) unless dest == '/queue/monitor'
  end

  # Send at most one frame to a connection
  # used when use_ack == true
  def send_a_backlog(connection)
    puts "Sending a backlog" if $DEBUG
    # lookup queues with data for this connection
    possible_queues = @queues.select{ |destination,users|
      @qstore.message_for?(destination) &&
        users.detect{|u| u.connection == connection}
    }
    if possible_queues.empty?
      puts "Nothing left" if $DEBUG
      return
    end
    # Get a random one (avoid artificial priority between queues
    # without coding a whole scheduler, which might be desirable later)
    dest,users = possible_queues[rand(possible_queues.length)]
    user = users.find{|u| u.connection == connection}
    frame = @qstore.dequeue(dest)
    puts "Chose #{dest}" if $DEBUG
    send_to_user(frame, user)
  end

  def send_destination_backlog(dest,user)
    puts "Sending destination backlog for #{dest}" if $DEBUG
    if user.ack
      # only send one message (waiting for ack)
      frame = @qstore.dequeue(dest)
      send_to_user(frame, user) if frame
    else
      while frame = @qstore.dequeue(dest)
        send_to_user(frame, user)
      end
    end
  end

  def unsubscribe(dest, connection)
    puts "Unsubscribing from #{dest}"
    @queues.each do |d, queue|
      queue.delete_if { |qu| qu.connection == connection and d == dest}
    end
    @queues.delete(dest) if @queues[dest].empty?
  end

  def ack(connection, frame)
    puts "Acking #{frame.headers['message-id']}" if $DEBUG
    unless @pending[connection]
      puts "No message pending for connection!"
      return
    end
    msgid = frame.headers['message-id']
    p_msgid = @pending[connection].headers['message-id']
    if p_msgid != msgid
      # We don't know what happened, we requeue
      # (probably a client connecting to a restarted server)
      frame = @pending[connection]
      @qstore.requeue(frame.headers['destination'],frame)
      puts "Invalid message-id (received #{msgid} != #{p_msgid})"
    end
    @pending.delete connection
    # We are free to work now, look if there's something for us
    send_a_backlog(connection)
  end

  def disconnect(connection)
    puts "Disconnecting"
    frame = @pending[connection]
    if frame
      @qstore.requeue(frame.headers['destination'],frame)
      @pending.delete connection
    end

    @queues.each do |dest, queue|
      queue.delete_if { |qu| qu.connection == connection }
      @queues.delete(dest) if queue.empty?
    end
  end

  def send_to_user(frame, user)
    connection = user.connection
    if user.ack
      raise "other connection's end already busy" if @pending[connection]
      @pending[connection] = frame
    end
    connection.stomp_send_data(frame)
  end

  def sendmsg(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    puts "Sending a message to #{dest}: "
    # Lookup a user willing to handle this destination
    available_users = @queues[dest].reject{|user| @pending[user.connection]}
    if available_users.empty?
      @qstore.enqueue(dest,frame)
      return
    end

    # Look for a user with ack (we favor reliability)
    reliable_user = available_users.find{|u| u.ack}

    if reliable_user
      # give it a message-id
      @qstore.assign_id(frame, dest)
      send_to_user(frame, reliable_user)
    else
      random_user = available_users[rand(available_users.length)]
      # Note message-id header isn't set but we won't need it anyway
      # <TODO> could break some clients: fix this
      send_to_user(frame, random_user)
    end
  end

  # For protocol handlers that want direct access to the queue
  def dequeue(dest)
    @qstore.dequeue(dest)
  end

  def enqueue(frame)
    frame.command = "MESSAGE"
    dest = frame.headers['destination']
    @qstore.enqueue(dest,frame)
  end

end
end
