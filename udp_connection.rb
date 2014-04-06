require './connection'

class UDPConnection < Connection

  attr_accessor :client_full_address

  def initialize(nick_name, client, client_full_address, socket)
    @socket = socket
    @client_full_address = client_full_address
    super(nick_name, client)
  end

  def read_from_client
    message, client_address = @socket.recvfrom(1024)
    @client = client_address[1]
    @client_full_address = "#{client_address[2]}:#{client_address[1]}"

    message.chomp
  end

  def processing_chunk
    false
  end

  # send a message from the server to the client
  def send_message(message)
    @socket.send(message << "\n", 0, nil, @client)
  end

end