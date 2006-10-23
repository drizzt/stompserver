require 'rubygems'
require 'stomp'
client = Stomp::Client.open "login", "passcode", "localhost", 61613

client.subscribe("/queue/client2", {
              "persistent" => true,
              "ack" => 'client',
              "client-id" => "rubyClient",
        } ) do |message|
  puts "Got Reply: #{message.headers['message-id']} - #{message.body} on #{message.headers['destination']}"
end

for i in 1..5 do
   m = "Go Sox #{i}!"
   puts m
   client.send("/queue/client2", m, {
    "persistent" => true,
    "priority" => 4,
    "reply-to" => "/queue/client2",
    }
  )
end

gets
client.close
