class Message

  attr_accessor :connection, :message, :length

  def initialize(connection, length)
    @connection = connection
    @length = length
    @message = ""
  end

  def construct_message
    while @message.length < @length
      # puts "length: #{@length}"
      # puts "@message_length: #{@message.length}"
      received = @connection.read_from_client
      # puts "received_length = #{received.length}"
      @message << received
      # puts @message
    end
  end

  def construct_chunk
    while @message.length < @length
      received = @connection.read_from_client
      @message << received
    end
  end

end