require "socket"

class ChatServer
  attr_accessor :udp_servers, :tcp_servers, :clients

  def initialize(ports = {})
    @udp_servers = []
    @tcp_servers = []
    @clients = {}

    ports.each do |port|
      udp_server = UDPSocket.new
      udp_server.bind('localhost', port)
      @udp_servers << udp_server

      @tcp_servers << TCPServer.new(port)
    end

    run
  end

  def run
    threads = []

    # TCP Server connections
    # TODO: UDP Server
    # TODO: chunking
    @tcp_servers.map do |tcp_server|
      threads << Thread.new do
        loop do
          Thread.start(tcp_server.accept) do |client|
            puts "client connected" # TODO remove

            client.puts "Enter your username" # TODO remove
            nick_name = client.gets.chomp

            # Make sure it matches the "ME IS user_name" format
            if match = nick_name.match(/ME IS (.*)/)
              nick_name = match[1]

              # Nickname or client already exists
              if @clients.has_key?(nick_name) || @clients.has_value?(client)
                client.puts "ERROR"
                client.close
                Thread.kill self
              end
            else
              client.puts "ERROR"
              client.close
              Thread.kill self
            end

            @clients[nick_name.to_sym] = client
            puts "#{nick_name} #{client}" # TODO remove

            client.puts "OK"

            listen_for_messages(nick_name, client)
          end
        end
      end
    end

    threads.map &:join
  end

  def listen_for_messages(sender, client)
    loop do
      # gets returns nil at EOF (socket closed)
      message = client.gets
      if message.nil?
        @clients.delete sender.to_sym
        client.close
        Thread.kill self
      end

      # Chomp here instead of method chaining above, chomping on nil = exception
      message.chomp

      @clients.each do |other_name, other_client|
        # Don't send it to yourself
        other_client.puts "#{sender.to_s}: #{message}" unless other_client == client
      end

    end
  end

end
