class Connection

  attr_accessor :nick_name, :processing_message, :receivers, :thread

  def initialize(nick_name, client, thread)
    @nick_name = nick_name
    @client = client
    @thread = thread
  end

  def reset_status
    @receivers = []
    @processing_message = false
  end

end