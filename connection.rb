class Connection

  attr_accessor :nick_name, :processing_message, :receivers, :message_count, :recent_senders, :thread

  def initialize(nick_name, client, thread)
    @nick_name = nick_name
    @client = client
    @thread = thread
    @message_count = 0
    @recent_senders = []
  end

  def reset_status
    @receivers = []
    @processing_message = false
  end

end