require 'rubygems'
require 'stomp'
client = Stomp::Client.open "login", "passcode", "localhost", 61613

client.subscribe("/queue/test", {
                "persistent" => true,
                "client-id" => "rubyClient",
        } ) do |message|
  puts "Got Reply: ID=#{message.headers['message-id']} BODY=#{message.body} on #{message.headers['destination']}"
end


gets
client.close
