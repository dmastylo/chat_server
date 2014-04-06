class Connection

  attr_accessor :nick_name, :processing_message, :receivers

  def initialize(nick_name, client)
    @nick_name = nick_name
    @client = client
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