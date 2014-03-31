require './connection'

class UDPConnection < Connection

  attr_accessor :socket

  def initialize(socket, nick_name, client)
    @socket = socket
    super(nick_name, client)
  end

  # TODO: change 1024
  def read_from_client
    message, client_address = @socket.recvfrom(1024)
    puts client_address

    # Set the client on the first message we receive
    unless client
      @client = client_address[1]
    end

    message.chomp unless message.nil?
  end

  # send a message from the server to the client
  def send_message(message)
    @socket.send(message << "\n", 0, nil, @client)
  end

end