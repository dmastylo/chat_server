class Connection

  attr_accessor :nick_name

  def initialize(nick_name, client)
    @nick_name = nick_name
    @client = client
  end

  # We don't want business logic to touch the client
  def close_client
    @client.close
  end

end