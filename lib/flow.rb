# copyright ryah dahl all rights reserved
# see readme for license
require 'rev' 
require File.dirname(__FILE__) + "/../ext/flow_parser"
require File.dirname(__FILE__) + "/flow/version"

$prof = false
if $prof
  require 'ruby-prof'
end

$i = 0


module Flow
  # The only public method
  # the rest is private.
  def self.start_server(evloop, app, options = {})


    port = (options[:port] || 4001).to_i
    socket = TCPServer.new("0.0.0.0", port)
    server = Rev::Server.new(socket, Flow::Connection, app)
    server.attach(evloop)
    puts "flow on http://0.0.0.0:#{port}/"
  end

  class Connection < Rev::IO
    TIMEOUT = 3 
    attr_reader :responses
    def initialize(socket, app)
      @app = app
      @timeout = Timeout.new(self, TIMEOUT) 
      @parser = Flow::Parser.new(self)
      @responses = []
      super(socket)
    end

    def on_connect
      if $prof
        if $i == 0
          RubyProf.start 
        end
        $i += 1
        @i = $i
      end
    end

    def attach(evloop)
      @timeout.attach(evloop)
      super(evloop)
    end

    def on_close
      @responses = [] # free responses so we don't write anymore
      @timeout.detach if @timeout.attached?
      if $prof
        if @i == 999 
          result = RubyProf.stop
          printer = RubyProf::FlatPrinter.new(result)
          printer.print(STDOUT)
        end
      end
    end

    def on_timeout
      close
    end

    def on_request(request)
      request.connection = self
      if request.method == "GET"
        process(request) 
      else
        fiber = Fiber.new { process(request) }
        request.fiber = fiber
      end
    end

    def process(req)
      status = headers = body = nil # how do i pass these out of 
                                    # catch(:async) and not predeclar them
                                    # here
      catch(:async) do 
        status, headers, body = @app.call(req.env)
      end

      res = req.response

      # James Tucker's async response scheme
      # check out
      # http://github.com/raggi/thin/tree/async_for_rack/example/async_app.ru
      res.call(status, headers, body) if status != 0 
      # if status == 0 then the application promises to call
      # env['async.callback'].call(status, headers, body) 
      # later on...

      @responses << res
      write_response
    end

    def write_response
      return unless res = @responses.first
      while chunk = res.output.shift
        write(chunk)
      end
    end

    def on_write_complete
      return unless res = @responses.first
      if res.finished
        @responses.shift
        if res.last 
          close 
          return
        end
      end 
      write_response
    end

    def on_read(data)
      @parser.execute(data)
    rescue Flow::Parser::Error
      close
    end

    class Timeout < Rev::TimerWatcher
      def initialize(connection, timeout)
        @connection = connection
        super(timeout, false)
      end

      def on_timer
        detach
        @connection.__send__(:on_timeout)
      end
    end
  end

  class Response
    attr_reader :output, :finished
    attr_accessor :last
    def initialize(connection, last)
      @connection = connection
      @last = last
      @output = []
      @finished = false
      @chunked = false 
    end

    def call(status, headers, body)
      write("HTTP/1.1 #{status} #{HTTP_STATUS_CODES[status.to_i]}\r\n")
      headers.each { |field, value| write("#{field}: #{value}\r\n") }
      write("\r\n")

      # XXX i would prefer to do
      # @chunked = true unless body.respond_to?(:length)
      @chunked = true if headers["Transfer-Encoding"] == "chunked"
      # I also don't like this
      @last = true if headers["Connection"] == "close"

      # Note: not setting Content-Length. do it yourself.
      
      body.each { |chunk| write(chunk) }

      body.on_error { close } if body.respond_to?(:on_error)

      if body.respond_to?(:on_eof)
        body.on_eof { finish }
      else
        finish
      end

      # deferred requests SHOULD NOT respond to close
      body.close if body.respond_to?(:close)
    end

    def finish
      @finished = true 
      write("") if @chunked
      @connection.write_response
    end
    
    def write(chunk)
      encoded = @chunked ? "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n" : chunk
      if self == @connection.responses.first
        # write directly to output buffer
        @connection.write(encoded)
      else
        # need to buffer - app is writing responses out of order
        @output << encoded
      end
    end

    HTTP_STATUS_CODES = {
      100  => 'Continue', 
      101  => 'Switching Protocols', 
      200  => 'OK', 
      201  => 'Created', 
      202  => 'Accepted', 
      203  => 'Non-Authoritative Information', 
      204  => 'No Content', 
      205  => 'Reset Content', 
      206  => 'Partial Content', 
      300  => 'Multiple Choices', 
      301  => 'Moved Permanently', 
      302  => 'Moved Temporarily', 
      303  => 'See Other', 
      304  => 'Not Modified', 
      305  => 'Use Proxy', 
      400  => 'Bad Request', 
      401  => 'Unauthorized', 
      402  => 'Payment Required', 
      403  => 'Forbidden', 
      404  => 'Not Found', 
      405  => 'Method Not Allowed', 
      406  => 'Not Acceptable', 
      407  => 'Proxy Authentication Required', 
      408  => 'Request Time-out', 
      409  => 'Conflict', 
      410  => 'Gone', 
      411  => 'Length Required', 
      412  => 'Precondition Failed', 
      413  => 'Request Entity Too Large', 
      414  => 'Request-URI Too Large', 
      415  => 'Unsupported Media Type', 
      500  => 'Internal Server Error', 
      501  => 'Not Implemented', 
      502  => 'Bad Gateway', 
      503  => 'Service Unavailable', 
      504  => 'Gateway Time-out', 
      505  => 'HTTP Version not supported'
    }.freeze
  end

  # created in c-land
  class Request 
    BASE_ENV = {
      'SERVER_NAME' => '0.0.0.0',
      'SCRIPT_NAME' => '',
      'QUERY_STRING' => '',
      'SERVER_SOFTWARE' => Flow::VERSION,
      'SERVER_PROTOCOL' => 'HTTP/1.1',
      'rack.version' => [0, 1],
      'rack.errors' => STDERR,
      'rack.url_scheme' => 'http',
      'rack.multiprocess' => false,
      'rack.run_once' => false
    }
    attr_accessor :fiber, :connection

    def env
      @env ||= begin
        env = BASE_ENV.merge(@env_ffi)
        env["rack.input"] = self
        env["CONTENT_LENGTH"] = env.delete("HTTP_CONTENT_LENGTH")
        env["CONTENT_TYPE"] = env.delete("HTTP_CONTENT_TYPE")
        env["async.callback"] = response
        env
      end
    end

    def method
      env["REQUEST_METHOD"]
    end

    def response
      @response ||= begin
        last = !keep_alive? # this is the last response if the request isnt keep-alive
        Flow::Response.new(@connection, last)
      end
    end

    def input
      @input ||= Rev::Buffer.new
    end

    def read(len = nil)
      if input.size == 0
        if @body_complete
          @fiber = nil
          nil
        else
          Fiber.yield(:wait_for_read)
          read(len)
        end
      else
        len.nil? ? input.read : input.read(len)
      end
    end

    # XXX hacky fiber shit...

    def on_body(chunk)
      input.append(chunk)
      if @fiber
        @fiber = nil if @fiber.resume != :wait_for_read
      end
    end

    def on_complete
      if @fiber
        @fiber = nil if @fiber.resume != :wait_for_read
      end
    end
  end
end
