require 'rubygems'
require 'eventmachine'

module StompServer
module TestServer


  def post_init
    @transactions = {}
    @connected = false
  end
  
  def receive_data(data)
  end
  
  def unbind
    p "Unbind called" if $DEBUG
    @connected = false
  end
end
end
