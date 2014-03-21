require "socket"

class ChatServer
  attr_accessor :servers, :server, :clients

  def initialize(port)
    @servers = []
    @server = TCPServer.new(port)
    @clients = {}

    run
  end

  def run
    loop do
      Thread.start(@server.accept) do |client|
        client.puts "Enter your username"
        nick_name = client.gets.chomp
        if match = nick_name.match(/ME IS (.*)/)
          nick_name = match[1]

          if @clients.has_key?(nick_name) || @clients.has_value?(client)
            client.puts "ERROR"
            Thread.kill self
          end
        else
          client.puts "ERROR"
          Thread.kill self
        end

        @clients[nick_name.to_sym] = client
        puts "#{nick_name} #{client}"

        client.puts "OK"

        listen_for_messages(nick_name, client)
      end
    end
  end

  def listen_for_messages(username, client)
    loop do
      message = client.gets.chomp

      @clients.each do |other_name, other_client|
        unless other_name == username
          other_client.puts "#{username.to_s}: #{message}"
        end
      end

    end
  end

end

server = ChatServer.new(8000)
