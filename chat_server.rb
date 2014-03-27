require 'socket'
require './connection'

class ChatServer
  # clients is a hash -> { nick_name: Connection class }
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

    # TODO: UDP Server
    # TODO: chunking
    # TCP Server connections
    @tcp_servers.map do |tcp_server|
      threads << Thread.new do
        loop do
          Thread.start(tcp_server.accept) do |client|
            connection = Connection.new(nil, client)

            connection.send_message "Enter your username" # TODO remove

            nick_name = set_nick_name(connection, connection.read_from_client)

            connection.nick_name = nick_name
            @clients[nick_name.to_sym] = connection
            puts "#{nick_name} #{client}" # TODO remove

            connection.send_message "OK"

            listen_for_messages(connection)
          end
        end
      end
    end

    threads.map &:join
  end

  # Make sure it matches the "ME IS user_name" format
  def set_nick_name(connection, nick_name)
    if nick_name[0..5] == "ME IS "
      nick_name = nick_name[6..nick_name.length].strip

      # Check if nickname/client already exists and for whitespace in nick_name
      if @clients.has_key?(nick_name) || @clients.has_value?(connection) || nick_name.include?(" ")
        connection.close_connection_on_error
      end
    else
      connection.close_connection_on_error
    end

    nick_name
  end

  def listen_for_messages(connection)
    loop do
      # all cleanup will be done in this method on socket closing and such
      message = connection.read_from_client(@clients)

      # Read message and extract command
      read_command(connection, message)
    end
  end

  def read_command(connection, message)
    command = message.split[0]
    if ["SEND", "BROADCAST"].include? command
      # Remove the command from the message and keep userid if SENDing
      message = message.split[1..message.length].join(" ")
      send("#{command.downcase}_chat_message", connection, message)
    else
      connection.send_message "ERROR: invalid command"
    end
  end

  def send_chat_message(connection, message)
    # The first index should be the userid, check for validity
    message_receiver = @clients[message.split[0].to_sym]
    if message_receiver == nil
      connection.send_message "ERROR: userid does not exist"
    else
      # Don't send the userid
      message_receiver.send_message "#{connection.nick_name}: #{message.split[1..message.length].join(" ")}"
    end
  end

  def broadcast_chat_message(connection, message)
    @clients.each do |other_name, message_receiver|
      message_receiver.send_message "#{connection.nick_name}: #{message}"
    end
  end

end
