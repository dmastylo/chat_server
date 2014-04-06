require 'socket'
require './tcp_connection'
require './udp_connection'
require './message'
require './logger'
require './random_messages'

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

    # TCP Server connections
    @tcp_servers.map do |tcp_server|
      server_threads << Thread.new do
        loop do
          client = tcp_server.accept
          thread = Thread.new do
            connection = TCPConnection.new(nil, client, thread)

            listen_for_commands(connection)
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

  def listen_for_commands(connection)
    loop do
      # all cleanup will be done in this method on socket closing and such
      message = receive_message_from_tcp_client(connection)

      # Read message and extract command
      read_command(connection, message)
    end
  end

  def read_command(connection, message)
    return set_nick_name(connection, message) unless connection.nick_name

    command = message.split[0]

    # Check for existence of from-user
    if message[0..7] == "WHO HERE"
      from_user = message.downcase.split[2]
    else
      from_user = message.downcase.split[1]
    end

    if from_user != connection.nick_name
      send_message_to_client(connection, "ERROR: <from-user> must be your own nick_name")
      return
    end

    # Decode command
    if ["SEND", "BROADCAST"].include? command
      length, length_message = read_message_length(connection)

      if length == "UDP_CHUNK"
        send_message_to_client(connection, "ERROR: UDP can't send chunked messages")
        return
      elsif length == "NEED_CHUNK"
        send_message_to_client(connection, "ERROR: messages greater than 99 bytes need to be chunked")
        return
      elsif length.nil?
        connection.reset_status
        send_message_to_client(connection, "ERROR: invalid message length")
      elsif length > 0
        # Remove the command from the message and keep userids
        connection.receivers = message.downcase.split[2..message.split.length]

        # Send the length to the receivers
        message_header = "FROM #{connection.nick_name}\n"
        length_message.prepend message_header
        send("#{command.downcase}_chat_message", connection, connection.receivers, length_message, false, true)

        dope_message = Message.new(connection, length)

        # Processing chunked messages
        while connection.processing_chunk do
          unless dope_message.construct_message
            connection.reset_status
            send_message_to_client(connection, "ERROR: message longer than given size")
            return
          end

          send("#{command.downcase}_chat_message", connection, connection.receivers, dope_message.message)

          # If the userids do not exist then processing_chunk will be false,
          # no point in listening for more messages as no one to send to
          break unless connection.processing_chunk

          # Next line should be the new chunk length
          length, length_message = read_message_length(connection)
          dope_message.prep_new_message(length)

          # "C0\n" has been reached indicating the end of the message, or
          # an invalid length was entered
          if length.nil?
            connection.reset_status
            send_message_to_client(connection, "ERROR: invalid message length")
          elsif length == 0
            # Send the length to the receivers
            send("#{command.downcase}_chat_message", connection, connection.receivers, length_message, false, true)
            connection.reset_status
          end
        end

        # Processing regular message without chunking
        if connection.processing_message
          if dope_message.construct_message
            send("#{command.downcase}_chat_message", connection, connection.receivers, dope_message.message, true)
          else
            connection.reset_status
            send_message_to_client(connection, "ERROR: message longer than given size")
          end
        end
      end
    elsif command == "LOGOUT"
      # Remove from clients
      clean_up_connection(connection)
    elsif message[0..7] == "WHO HERE"
      send_message_to_client(connection, @clients.keys.join(" "))
    else
      send_message_to_client(connection, "ERROR: invalid command")
    end
  end

  # Returns array [length integer, length string message]
  # Use the length string message to send to the client
  def read_message_length(connection)
    # Read the length of the message
    length_message = receive_message_from_tcp_client(connection)

    # Check if it's a regular message or a chunked message (ugh)
    match = length_message.match(/C(\d*)/)
    if match.nil?
      if length_message.to_i == 0
        length = nil
      else
        if length_message.to_i > 99
          length = "NEED_CHUNK"
        else
          length = length_message.to_i
          connection.processing_message = true
        end
      end
    else
      if connection.is_a? UDPConnection
        length = "UDP_CHUNK"
      else
        connection.processing_chunk = true
        length = match[1].to_i
      end
    end

    [length, length_message]
  end

  def send_chat_message(connection, receivers, message, reset = false, length_message = nil)
    message_receivers = receivers.map { |receiver| @clients[receiver.to_sym] }.compact

    if message_receivers.empty?
      send_message_to_client(connection, "ERROR: userid(s) do not exist")
      connection.reset_status
    else
      message_receivers.each do |message_receiver|
        send_message_to_client(message_receiver, message, connection, length_message) if can_receive?(connection, message_receiver)
      end

      # If we're sending a regular (non-chunked) message we don't want to listen
      # further so we want to listen for new commands
      if (!connection.processing_chunk && reset)
        connection.reset_status
      end
    end
  end

  def broadcast_chat_message(connection, _, message, reset = false, length_message = nil)
    @clients.each do |other_name, message_receiver|
      if (can_receive?(connection, message_receiver) && connection != message_receiver)
        send_message_to_client(message_receiver, message, connection, length_message)
      end
    end

    # If we're sending a regular (non-chunked) message we don't want to listen
    # further so we want to listen for new commands
    if (!connection.processing_chunk && reset)
      connection.reset_status
    end
  end

  def can_receive?(connection, message_receiver)
    if (connection.processing_chunk && message_receiver.is_a?(UDPConnection))
      false
    else
      true
    end
  end

  # Handle input from the client and disconnect on a closed socket
  def receive_message_from_tcp_client(connection)
    message = connection.read_from_client
    clean_up_connection(connection) if message.nil?

    Logger.log(connection, message, "receive")
    message
  end

  def send_message_to_client(receiver, message, sender = nil, length_message = false)
    receiver.send_message message

    # If the message isn't from the server (errors, WHO HERE..)
    # Or if the message isn't a length_message
    if (!sender.nil? && !length_message)
      receiver.message_count += 1
      receiver.recent_senders << sender
    end

    # Check if counter if divisible by 3
    puts "message_count: #{receiver.message_count}"
    if (receiver.message_count % 3 == 0 && receiver.message_count != 0)
      send_random_message_to_client(receiver)
      receiver.recent_senders.clear
      receiver.message_count = 0
    end

    Logger.log(receiver, message, "send")
    message
  end

  def send_random_message_to_client(receiver)
    message = RANDOM_MESSAGES.sample
    sender = receiver.recent_senders.sample

    # Send the length to the receiver
    message_header = "FROM #{sender.nick_name}\n#{message.length + 1}\n"
    message.prepend message_header

    receiver.send_message message

    Logger.log(receiver, message, "send")
  end

  def clean_up_connection(connection)
    Logger.log(connection, "leave")

    # Clean up the client and connection
    @clients.delete connection.nick_name.to_sym if connection.nick_name
    connection.close_client

    Thread.kill connection.thread if connection.thread
  end

end
