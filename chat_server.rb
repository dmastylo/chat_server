require 'socket'
require './tcp_connection'
require './udp_connection'
require './logger'

class ChatServer
  # clients is a hash -> { nick_name: Connection class }
  attr_accessor :udp_servers, :tcp_servers, :clients

  def initialize(ports = {}, verbose, development_mode)
    Thread.abort_on_exception = true if development_mode

    Logger.init(verbose)

    @udp_servers = []
    @tcp_servers = []
    @clients = {}

    # Create a UDPSocket and TCPServer on each port
    ports.each do |port|
      udp_server = UDPSocket.new
      udp_server.bind(nil, port)
      @udp_servers << udp_server

      @tcp_servers << TCPServer.new(port)
    end

    run
  end

private

  def run
    server_threads = []

    # TODO: chunking
    # TCP Server connections
    @tcp_servers.map do |tcp_server|
      server_threads << Thread.new do
        loop do
          client = tcp_server.accept
          thread = Thread.new do
            connection = TCPConnection.new(nil, client, thread)

            listen_for_messages(connection)
          end
        end
      end
    end

    @udp_servers.map do |udp_server|
      server_threads << Thread.new do
        loop do
          message, client_address = udp_server.recvfrom(1024)
          message.chomp
          client = client_address[1]
          client_name = "#{client_address[2]}:#{client_address[1]}"

          puts client_address

          exists = false

          connection = UDPConnection.new(nil, client, client_name, udp_server)

          @clients.each do |other_client_nick_name, other_client|
            if client == other_client.client
              connection = other_client
              puts "exists"
              exists = true

              if connection.nick_name
                read_command(connection, message)
              else
                set_nick_name(connection, message)
              end
            end
          end

          unless exists
            set_nick_name(connection, message)
          end

        end
      end
    end

    server_threads.map &:join
  end

  def set_nick_name(connection, message)
    nick_name = nick_name_available?(connection, message)
    if nick_name.nil?
      send_message_to_client(connection, "ERROR")
      return nil
    end

    connection.nick_name = nick_name
    @clients[nick_name.to_sym] = connection
    puts @clients

    send_message_to_client(connection, "OK")
  end

  def nick_name_available?(connection, message)
    return nil if message[0..5] != "ME IS "

    nick_name = message[6..message.length].strip

    return nil if nick_name.nil? ||
                  nick_name.empty? ||
                  nick_name.include?(" ") ||
                  @clients.has_key?(nick_name.to_sym) ||
                  @clients.has_value?(connection)

    nick_name
  end

  def listen_for_messages(connection)
    loop do
      # all cleanup will be done in this method on socket closing and such
      message = receive_message_from_client(connection)

      # Read message and extract command
      read_command(connection, message)
    end
  end

  def read_command(connection, message)
    unless connection.nick_name
      return set_nick_name(connection, message)
    end

    command = message.split[0]

    if ["SEND", "BROADCAST"].include? command
      # Remove the command from the message and keep userid if SENDing
      message = message.split[1..message.length].join(" ")
      send("#{command.downcase}_chat_message", connection, message)
    else
      send_message_to_client(connection, "ERROR: invalid command")
    end
  end

  def send_chat_message(connection, message)
    # The first index should be the userid, check for validity
    message_receiver = @clients[message.split[0].to_sym]
    if message_receiver == nil
      send_message_to_client(connection, "ERROR: userid does not exist")
    else
      # Don't send the userid
      send_message_to_client(message_receiver, "#{connection.nick_name}: #{message.split[1..message.length].join(" ")}")
    end
  end

  def broadcast_chat_message(connection, message)
    @clients.each do |other_name, message_receiver|
      send_message_to_client(message_receiver, "#{connection.nick_name}: #{message}")
    end
  end

  # Handle input from the client and disconnect on a closed socket
  def receive_message_from_client(connection)
    message = connection.read_from_client
    if message.nil?
      Logger.log(connection, message, "leave")

      # Clean up the client and connection
      @clients.delete connection.nick_name.to_sym if connection.nick_name
      connection.client.close

      Thread.kill connection.thread if connection.thread
    end

    Logger.log(connection, message, "receive")
    message
  end

  def send_message_to_client(connection, message)
    connection.send_message message
    Logger.log(connection, message, "send")
  end

end
