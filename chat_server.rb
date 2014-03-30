require 'socket'
require './connection'
require './logger'

class ChatServer
  # clients is a hash -> { nick_name: Connection class }
  attr_accessor :udp_servers, :tcp_servers, :clients, :logger

  def initialize(ports = {}, verbose)
    @udp_servers = []
    @tcp_servers = []
    @clients = {}
    @logger = Logger.new(verbose)

    # Create a UDPSocket and TCPServer on each port
    ports.each do |port|
      udp_server = UDPSocket.new
      udp_server.bind('localhost', port)
      @udp_servers << udp_server

      @tcp_servers << TCPServer.new(port)
    end

    run
  end

private

  def run
    threads = []

    # TODO: UDP Server
    # TODO: chunking
    # TCP Server connections
    @tcp_servers.map do |tcp_server|
      threads << Thread.new do
        loop do
          Thread.start(tcp_server.accept) do |client|
            # No nickname specified yet
            connection = Connection.new(nil, client)

            send_message(connection, "Enter your username") # TODO remove
            set_nick_name(connection)

            listen_for_messages(connection)
          end
        end
      end
    end

    threads.map &:join
  end

  def set_nick_name(connection)
    nick_name = nil

    while nick_name.nil? do
      nick_name = receive_message(connection)

      # Make sure it matches the "ME IS user_name" format
      if nick_name[0..5] == "ME IS "
        nick_name = nick_name[6..nick_name.length].strip

        # Check if nickname/client already exists and for whitespace in nick_name
        if @clients.has_key?(nick_name) || @clients.has_value?(connection) || nick_name.include?(" ")
          send_message(connection, "ERROR")
          nick_name = nil
        end
      else
        send_message(connection, "ERROR")
        nick_name = nil
      end
    end

    connection.nick_name = nick_name
    @clients[nick_name.to_sym] = connection

    send_message(connection, "OK")
  end

  def listen_for_messages(connection)
    loop do
      # all cleanup will be done in this method on socket closing and such
      message = receive_message(connection)

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
      send_message(connection, "ERROR: invalid command")
    end
  end

  def send_chat_message(connection, message)
    # The first index should be the userid, check for validity
    message_receiver = @clients[message.split[0].to_sym]
    if message_receiver == nil
      send_message(connection, "ERROR: userid does not exist")
    else
      # Don't send the userid
      send_message(message_receiver, "#{connection.nick_name}: #{message.split[1..message.length].join(" ")}")
    end
  end

  def broadcast_chat_message(connection, message)
    @clients.each do |other_name, message_receiver|
      send_message(message_receiver, "#{connection.nick_name}: #{message}")
    end
  end

  def receive_message(connection)
    message = connection.read_from_client
    if message.nil?
      @logger.log(connection, message, "leave")

      # Clean up the client and connection
      @clients.delete connection.nick_name.to_sym
      connection.client.close
      Thread.kill self
    end

    @logger.log(connection, message, "receive")
    message
  end

  def send_message(connection, message)
    connection.send_message message
    @logger.log(connection, message, "send")
  end

end
