
require "rubygems"
require "eventmachine"
require "logger"

module EventMachine; module Protocols
  module VNC
    module Client
      VERSION = "RFB 003.003"
      SECURITY_TYPES = {
        0 => "Invalid",
        1 => "None",
        2 => "VNC Authentication",
        5 => "RA2",
        6 => "RA2ne",
        16 => "Tight",
        17 => "Ultra",
        18 => "TLS",
        19 => "VeNCrypt",
        20 => "GTK-VNC SASL",
        21 => "MD5 hash authentication",
        22 => "Colin Dean xvp",
      }

      attr_accessor :screen_width
      attr_accessor :screen_height
      attr_accessor :name

      KEY_EVENT = 4
      POINTER_EVENT = 5

      def receive_data(data)
        @logger ||= Logger.new(STDERR)
        @buffer ||= ''
        @state ||= :handshake
        @buffer += data
        @logger.info ("Got #{data.length} bytes: #{data}")

        # Process all data in the buffer.
        while @buffer.length > 0
          @logger.info [@state, @buffer.length].inspect
          result = send(@state)
          puts [result, @buffer.length].inspect
          break if result == :wait
        end
      end # def receive_data

      private
      def handshake
        return :wait if @buffer.length < 12

        @server_version = consume(12)
        if @server_version !~ /^RFB [0-9]{3}\.[0-9]{3}\n$/
          error "Invalid protocol message: #{@server_version}"
        end
        send_data("#{VERSION}\n")
        @state = :security
      end # def handshake

      private
      def security
        return :wait if @buffer.length < 4
        security_type = consume(4).unpack("N").first
        
        @logger.info("Security: #{security_type}")
        case security_type
        when 0
          @state = :read_error
          #error "Connection failed (during security handshake)"
          # TODO(sissel): Should set state ':read_string_and_fail'
          # RFP protocol says this 0 will be followed by a string reason.
        when 1
          # No authentication to do
          client_init
        when 2
          @state = :security_vnc_authentication
          @logger.info("VNC AUTH")
        else
          error "Unsupported security type #{SECURITY_TYPES[security_type]}"
        end # case security_type
      end # def security

      # Page 14, RFB 3.7 PDF
      private
      def security_vnc_authentication
        # TODO(sissel): implement VNC auth (DES a 16 byte challenge + password)
        # Except the password is bitwise-reversed.
        #   http://www.vidarholen.net/contents/junk/vnc.html
        # For now, use the Cipher::DES that comes with ruby-vnc
        return :wait if @buffer.length < 16
        require "cipher/des" # from rubygem ruby-vnc
        challenge = consume(16)
        password = ENV["VNCPASS"]
        response = Cipher::DES.encrypt(password, challenge)
        send_data(response)
        @state = :security_result
      end # def security_vnc_authentication

      private
      def security_result
        return :wait if @buffer.length < 4
        result = consume(4).unpack("N").first
        if result == 0
          client_init
        else
          error "Authentication failed"
        end
      end # def security_result

      # ClientInit is 1 byte, U8. Value is 'shared-flag' nonzero is true.
      private
      def client_init
        shared = [1].pack("C")
        send_data(shared)
        @state = :server_init
      end

      # ServerInit
      #   bytes   type   description
      # 2, U16, framebuffer-width
      # 2, U16, framebuffer-height
      # 16, PIXEL_FORMAT, server-pixel-format
      # 4, U32, name-length
      # <name-length>, U8 array, name-string
      private
      def server_init
        return :wait if @buffer.length < 24
        @screen_width, @screen_height, @pixel_format, @name_length = \
          consume(24).unpack("nnA16N")
        puts "Screen: #{@screen_width} x #{@screen_height}"
        @state = :server_init_name
      end

      private
      def server_init_name
        return :wait if @buffer.length < @name_length
        @name = consume(@name_length)
        @logger.info("Name; #{@name}")
        @state = :normal
        ready if self.respond_to?(:ready)
      end

      private
      def read_error
        error(@buffer)
      end

      private
      def consume(bytes)
        result = @buffer[0 .. bytes - 1]
        @buffer = @buffer[bytes .. -1]
        return result
      end # def consume

      public
      def error(message)
        if self.respond_to?(:errback)
          self.errback(message)
        else
          raise message
        end
      end

      public
      def pointerevent(x, y, buttonmask)
        message = [ POINTER_EVENT, buttonmask, x, y ].pack("CCnn")
        send_data(message)
      end
    end # module Client
  end # module VNC
end; end # module EventMachine::Protocols
