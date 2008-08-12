require 'rubygems'
require 'rev'
require File.dirname(__FILE__) + "/lib/flow"


class DeferredBody

  def eof
    @eof_callback.call
  end

  def error
    @error_callback.call
  end

  def write(chunk)
    @each_callback.call(chunk)
  end

  def on_eof(&block)
    @eof_callback = block 
  end
  
  def on_error(&block)
    @error_callback = block 
  end

  def each(&block)
    @each_callback = block
  end
end

class Delay < Rev::TimerWatcher
  def self.create(evloop, seconds, &block)
    d = new(seconds, &block)
    d.attach(evloop)
    d
  end

  def initialize(seconds, &block)
    @block = block
    super(seconds, false)
  end

  def on_timer
    detach
    @block.call
  end

end

class App
  def initialize(evloop)
    @evloop = evloop
  end
  
  def call(env)
    body = DeferredBody.new 

    Delay.create(@evloop, 0.1) do 
      env['async.callback'].call(
          200, 
          { "content-type" => "text/plain", "Transfer-Encoding" => "chunked" }, 
          body
      )
    end

    Delay.create(@evloop, 0.7) do 
      body.write "hello\n" 
    end

    Delay.create(@evloop, 1) do 
      body.write "world\n" 
      body.eof
    end

    [0, nil, nil]
  end
end

evloop = Rev::Loop.default 
app = App.new(evloop)
Flow.start_server(evloop, app)
evloop.run
