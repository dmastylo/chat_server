require 'socket'
require './tcp_connection'
require './udp_connection'
require './message'
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
          connection = UDPConnection.new(nil, nil, nil, udp_server)
          message = connection.read_from_client

          Logger.log(connection, message, "receive")

          exists = false
          @clients.each do |_, other_client|
            if connection.client_full_address == other_client.client_full_address
              connection = other_client
              puts "exists"
              exists = true
              break
            end
          end

          # Already received message from this UDP connection
          # and it has already set their nickname
          if exists && connection.nick_name
            read_command(connection, message)
          else
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

    nick_name = message[6..message.length].strip.downcase

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
      message = receive_message_from_tcp_client(connection)

      # TODO remove this?
      # If we're still listening for more of the message, don't read for commands
      if connection.processing_message
        process_message(connection, message)
      else
        # Read message and extract command
        read_command(connection, message)
      end
    end
  end

  def process_message(connection, message)
  end

  def read_command(connection, message)
    unless connection.nick_name
      return set_nick_name(connection, message)
    end

    command = message.split[0]

    if command == "SEND"
      length = read_message_length(connection)

      if length > 0
        # Remove the command from the message and keep userids
        connection.last_command = command
        connection.receivers = message.split[1..message.split.length]

        dope_message = Message.new(connection, length)

        # Processing chunked messages
        while connection.processing_chunk do
          dope_message.construct_message
          send_chat_message(connection, connection.receivers, dope_message.message)
          break unless connection.processing_chunk

          # Next line should new chunk length
          length = read_message_length(connection)
          dope_message.prep_new_message(length)

          # "C0\n" has been reached indicating the end of the message
          connection.reset_status if length == 0
        end

        # Processing regular message without chunking
        if connection.processing_message
          dope_message.construct_message
          send_chat_message(connection, connection.receivers, dope_message.message)
        end
      else
        connection.reset_status
        send_message_to_client(connection, "ERROR: invalid message length")
      end
    elsif command == "BROADCAST"
    elsif command == "LOGOUT"
    elsif message[0..7] == "WHO HERE"
    else
      send_message_to_client(connection, "ERROR: invalid command")
    end
  end

  def read_message_length(connection)
    # Read the length of the message
    length = receive_message_from_tcp_client(connection)

    # Check if it's a regular message or a chunked message (ugh)
    match = length.match(/C(\d*)/)
    if match.nil?
      length = length.to_i
      connection.processing_message = true
    else
      connection.processing_chunk = true
      # connection.last_command = message.first.split.first
      length = match[1].to_i
    end

    length
  end

  def send_chat_message(connection, receivers, message)
    message_receivers = receivers.map { |receiver| @clients[receiver.to_sym] }.compact
    message_header = "FROM #{connection.nick_name}\n"
    message.prepend message_header

    if message_receivers.empty?
      send_message_to_client(connection, "ERROR: userid(s) do not exist")
      connection.reset_status
    else
      message_receivers.each do |receiver|
        send_message_to_client(receiver, message)
      end

      unless connection.processing_chunk
        connection.reset_status
      end
    end


    # It's an annoying chunked message
    # if message[1] =~ /C\d*/
    #   connection.processing_chunk = true
    #   connection.chunk_command = message.first.split.first

    #   # Construct the chunks
    #   chunks = ["#{message[1]}\n"]

    #   message.drop(2).each do |line|
    #     chunks << "" if line =~ /C\d*/
    #     chunks.last << "#{line}\n"

    #     # Already have full chunked message, so no more chunks should arrive.
    #     # Other messages will be new commands
    #     if line =~ /C0/
    #       connection.processing_chunk = false
    #       connection.chunk_command = nil
    #       break
    #     end
    #   end
    # else
    #   # TODO
    #   # send_message = message.split[1..message.length].join(" ").split("\n")

    #   # Don't send the userid
    #   # send_message_to_client(message_receiver, "#{send_message}")
    # end

  end

  def broadcast_chat_message(connection, receiver, message)
    @clients.each do |other_name, message_receiver|
      send_message_to_client(message_receiver, "BROADCAST FROM #{connection.nick_name}\n #{message}")
    end
  end

  # Handle input from the client and disconnect on a closed socket
  def receive_message_from_tcp_client(connection)
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
