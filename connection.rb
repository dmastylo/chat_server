class Connection

  attr_accessor :nick_name, :client

  def initialize(nick_name, client)
    @nick_name = nick_name
    @client = client
  end

  # TODO: this shouldn't close the client connection
  def close_connection_on_error
    send_message "ERROR"
    client.close
    Thread.kill self
  end

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

end