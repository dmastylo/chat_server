require './connection'

class UDPConnection < Connection

  attr_accessor :socket

  def initialize(nick_name, client, client_name, socket)
    @socket = socket
    @client_name = client_name
    super(nick_name, client, nil)
  end

  # send a message from the server to the client
  def send_message(message)
    @socket.send(message << "\n", 0, nil, @client)
  end

end