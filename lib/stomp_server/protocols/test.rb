
module StompServer
module StompServer::Protocols

  class Test < StompServer::Protocols::Stomp

    def receive_data(data)
      create_frame_from_request(data)
    end

    ## This will be called when there is a complete frame to send to the client
    def stomp_send_data(data)
      reply = create_reply_from_frame(data)
      send_data(reply)
    end

    def create_reply_from_frame(frame)
      frame
    end

    def create_frame_from_request(data)
      frame = data

      ## parse data until you have a complete request. create the stomp frame yourself and pass it to stomp_receive_frame
      stomp_receive_frame(frame)
  
      ## Or let the stomp protocol handler create the frame for you. Note you still have to pass it a valid frame, or part thereof. 
      stomp_receive_data(data)
    end

  end

end
end
