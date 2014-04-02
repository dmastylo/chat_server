class Message

  attr_accessor :connection, :message, :length

  def initialize(connection, length)
    @connection = connection
    @length = length
    @message = ""
  end

  def construct_message
    while @message.length < @length
      received = @connection.read_from_client
      @message << received
    end

    # the "..." range means to omit the last index.
    # Since 0 indexing can be confusing sometimes here's an example:
    # Length 10: hey there\n (\n is a single char)
    # If 8 or C8 is received, the e\n should be cut off from the message
    # but with ".." it'll include the 8th index which is actually the 9th char
    @message = @message[0...@length]
  end

  def prep_new_message(length)
    @message = ""
    @length = length
  end

end