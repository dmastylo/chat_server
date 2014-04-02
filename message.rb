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

  def prep_new_message(length)
    @message = ""
    @length = length
  end

end