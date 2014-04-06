class Connection

  attr_accessor :nick_name, :processing_message, :receivers, :message_count, :recent_senders

  def initialize(nick_name, client)
    @nick_name = nick_name
    @client = client
    @message_count = 0
    @recent_senders = []
  end

  def reset_status
    @receivers = []
    @processing_message = false
  end

  # We don't want business logic to touch the client
  def close_client
    @client.close
  end

end