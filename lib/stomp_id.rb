
# This class is instantiated in all the queue storage classes, plus the queue manager (for the statistic messages).  It generates a unique
# id for each message.  The caller passes an additional identifier that is appended message-id, which is usually the id of the frame and is
# different for each storage class.

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

