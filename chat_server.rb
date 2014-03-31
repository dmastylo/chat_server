require 'socket'
require './tcp_connection'
require './udp_connection'
require './logger'

class ChatServer
  # clients is a hash -> { nick_name: Connection class }
  attr_accessor :udp_servers, :tcp_servers, :clients, :logger

  def initialize(ports = {}, verbose, development_mode)
    # TODO remove this after done
    Thread.abort_on_exception = true if development_mode

    @udp_servers = []
    @tcp_servers = []
    @clients = {}
    @logger = Logger.new(verbose)

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
    threads = []

    # TODO: chunking
    # TCP Server connections
    @tcp_servers.map do |tcp_server|
      threads << Thread.new do
        loop do
          Thread.start(tcp_server.accept) do |client|
            # No nickname specified yet
            connection = TCPConnection.new(nil, client)

            send_message(connection, "Enter your username") # TODO remove
            set_nick_name(connection)

            listen_for_messages(connection)
          end
        end
      end
    end

    # OLD
    # @udp_servers.map do |udp_server|
    #   threads << Thread.new do
    #     loop do
    #       message, client_address = udp_server.recvfrom(1024)
    #       Thread.start(client_address) do |client|
    #         # No nickname specified yet
    #         connection = UDPConnection.new(nil, client)
    #         set_nick_name(connection)

    #         puts "New packets"
    #         unless @udp_clients.include? client[1]
    #           puts "new client doe"
    #           @udp_clients << client[1]
    #         end

    #         puts "From client: #{client.join(',')}, msg: '#{message}'"
    #         broadcast_udp_clients(udp_server, message, @udp_clients)
    #       end
    #     end
    #   end
    # end

    @udp_servers.map do |udp_server|
      threads << Thread.new do
        loop do
          # No nickname specified yet
          connection = UDPConnection.new(udp_server, nil, nil)
          set_nick_name(connection)

          # puts "New packets"
          # unless @udp_clients.include? client[1]
          #   puts "new client doe"
          #   @udp_clients << client[1]
          # end

          # Once we have a nick_name for the UDP connection we can delegate
          Thread.start(connection) do |connection|
            # puts "From client: #{client.join(',')}, msg: '#{message}'"
            # broadcast_udp_clients(udp_server, message, @udp_clients)
            listen_for_messages(connection)
          end
        end
      end
    end

    threads.map &:join
  end

  # TODO clean up!
  def broadcast_udp_clients(socket, data, clients)
    puts "broadcasting"
    puts clients
    puts "clients??"
    clients.each do |client|
      socket.send(data, 0, nil, client)
    end
  end

  def set_nick_name(connection)
    nick_name = nil

    while nick_name.nil? do
      nick_name = receive_message(connection)

      # Make sure it matches the "ME IS user_name" format
      if nick_name[0..5] == "ME IS "
        nick_name = nick_name[6..nick_name.length].strip

        # Check if nickname/client already exists and for whitespace in nick_name
        if @clients.has_key?(nick_name.to_sym) || @clients.has_value?(connection) || nick_name.include?(" ")
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
    puts @clients

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

  # Handle input from the client and disconnect on a closed socket
  def receive_message(connection)
    message = connection.read_from_client
    if message.nil?
      @logger.log(connection, message, "leave")

      # Clean up the client and connection
      @clients.delete connection.nick_name.to_sym
      connection.client.close

      # TODO: This is actually wrong, fix this, zombie thread
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
