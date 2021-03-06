require './connection'

class TCPConnection < Connection

  def read_from_client
    # Returns nil on closed socket
    message = client.gets

    # Chomp here instead of method chaining above b/c chomp on nil = exception
    message.chomp unless message.nil?
  end

  # send a message from the server to the client
  def send_message(message)
    client.puts message
  end

  def client_full_address
    host_name = client.peeraddr(:hostname)
    "#{host_name[2]}:#{host_name[1]}"
  end

end