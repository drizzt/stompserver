require 'rubygems'
require 'stomp'
client = Stomp::Client.open "login", "passcode", "localhost", 61613

# sending 5 messages at once
for i in 1..5 do
   m = "Go Sox #{i}!"
   puts m
   client.send("/queue/test", m, {
    "persistent" => true,
    "client-id" => "Client1",
    "reply-to" => "/queue/test",
    }
  )
end

client.close
