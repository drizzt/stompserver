module StompServer

class StompAuth
attr_accessor :authorized

  def initialize(passfile='.passwd')
    @passfile = passfile
    @authorized = Hash.new
    if File.exists?(@passfile)
      file = File.read(@passfile)
      file.split(/\n/).each do |data|
        next if data =~/^\s*#/
        data.gsub(/\s/,'')
        if data =~ /^\s*(\S+)\s*:\s*(.*?)\s*$/
          @authorized[$1] = $2
        end
      end
    end
    puts "Authorized users #{@authorized.keys}" if $DEBUG
  end
end
end
