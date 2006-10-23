
require 'socket'
require 'resolv-replace'

class StompId

  def initialize
    @host = Socket.gethostname.to_s
  end

  def [](id)
    msgid = sprintf("%.6f",Time.now.to_f).to_s.sub('.','-')
    msgid = @host + '-' + msgid + '-' + id.to_s
  end
end

