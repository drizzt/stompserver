
  class Mongrel::HttpRequest
    attr_reader :body, :params

    def initialize(params, initial_body)
      @params = params
      @body = StringIO.new
      @body.write params.http_body
    end
  end

module StompServer
module StompServer::Protocols

  class Http < EventMachine::Connection

    def initialize *args
      super
    end

    def post_init
      @parser = Mongrel::HttpParser.new
      @params = Mongrel::HttpParams.new
      @buf = ''
      @nparsed = 0
      @request = nil
      @request_method = nil
      @state = :headers
      @headers_out = {'Content-Length' => 0,'Connection' => 'close', 'Content-Type' => 'text/plain; charset=UTF-8'}
    end

    def receive_data data
      @buf << data
      case @state
      when :headers
        @nparsed = @parser.execute(@params, @buf, @nparsed)
        if @parser.finished?
          @request = Mongrel::HttpRequest.new(@params,@buf)
          @request_method = @request.params[Mongrel::Const::REQUEST_METHOD]
          content_length = @request.params[Mongrel::Const::CONTENT_LENGTH].to_i
          @remain = content_length - @request.params.http_body.length
          if @remain <= 0
            @request.body.rewind
            @state = :headers
            process_request and return
          end
          @request.body.write @request.params.http_body
          @state = :body
        end
      when :body
        @remain -= @request.body.write data
        if @remain <= 0
          @request.body.rewind
          @state = :headers
          process_request
        end
      end
    end

    def process_request
      begin
        dest = @request.params[Mongrel::Const::REQUEST_PATH]
        case @request_method
        when 'PUT'
          @frame = StompServer::StompFrame.new
          @frame.command = 'SEND'
          @frame.body = @request.body.read
          @frame.headers['destination'] = dest
          if @@queue_manager.enqueue(@frame)
            create_response('200','Message Enqueued')
          else
            create_response('500','Error enqueueing message')
          end
        when 'GET'
          if frame = @@queue_manager.dequeue(dest)
            @headers_out['message-id'] = frame.headers['message-id']
            create_response('200',frame.body)
          else
            create_response('404','No messages in queue')
          end
        else
          create_response('500','Invalid Command')
        end
      rescue Exception => e
        puts "err: #{e} #{e.backtrace.join("\n")}"
        create_response('500',e)
      end
    end

    def create_response(code,response_text)
      response = ''
      @headers_out['Content-Length'] = response_text.size

      case code
      when '200'
        response << "HTTP/1.1 200 OK\r\n"
      when '500'
        response << "HTTP/1.1 500 Server Error\r\n"
      when '404'
        response << "HTTP/1.1 404 Message Not Found\r\n"
      end
      @headers_out.each_pair do |key, value|
        response << "#{key}:#{value}\r\n"
      end
      response << "\r\n"
      response << response_text
      send_data(response)
      close_connection_after_writing
    end

  end

end
end
