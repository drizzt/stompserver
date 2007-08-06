require 'active_record'

class ArMessage < ActiveRecord::Base
  serialize :frame
end
