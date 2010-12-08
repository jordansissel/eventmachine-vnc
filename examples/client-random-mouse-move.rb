require "rubygems"
require "eventmachine-vnc"
require "eventmachine"

class VNCClient < EventMachine::Connection
  include EventMachine::Protocols::VNC::Client

  def mousemove(x, y)
    message = [ POINTER_EVENT, 0, x, y ].pack("CCnn")
    send_data(message)
  end

  def ready
    EventMachine::PeriodicTimer.new(1) do 
      mousemove((rand * @screen_width).to_i, (rand * @screen_height).to_i)
    end
  end
end

EventMachine.run do
  EM::connect("sadness", 5900, VNCClient)
end
