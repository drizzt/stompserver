begin
  require 'tesly_reporter'
  
  module TeslyReporter
    class Config
      AppName = 'StompServer' unless const_defined? :AppName
      # put your code here
      # User = 'id'
    end
  end
  
rescue LoadError => err
  # do nothing
end  

