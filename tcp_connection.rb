require './connection'

class TCPConnection < Connection

  attr_accessor :thread, :processing_message, :processing_chunk, :last_command, :receivers

  def initialize(nick_name, client, thread)
    @thread = thread
    reset_status
    super(nick_name, client)
  end

  def reset_status
    @processing_message = false
    @processing_chunk = false
    @last_command = nil
    @receivers = []
  end

  def read_from_client
    # Returns nil on closed socket
    message = client.gets

    # Get rid of carriage returns and deal with just regular newlines
    unless message.nil?
      message.chomp!.strip!
      message << "\n"
    end

    message
  end

  # send a message from the server to the client
  def send_message(message)
    client.puts message
  end

  def send_chunk(message)
  end

  def client_full_address
    host_name = client.peeraddr(:hostname)
    "#{host_name[2]}:#{host_name[1]}"
  end

end