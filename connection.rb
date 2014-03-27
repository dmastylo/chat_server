class Connection
  attr_accessor :nick_name, :client

  def initialize(nick_name, client)
    @nick_name = nick_name
    @client = client
  end

  def close_connection_on_error
    send_message "ERROR"
    client.close
    Thread.kill self
  end

  # read messages from clients, and cleanup if the socket is closed
  # if client set a username then we have to clean up from clients
  def read_from_client(clients = nil)
    message = client.gets
    if message.nil?
      clients.delete nick_name.to_sym if nick_name
      client.close
      Thread.kill self
    end

    # Chomp here instead of method chaining above b/c chomp on nil = exception
    message.chomp
  end

  # send a message from the server to the client
  def send_message(message)
    client.puts message
  end
end