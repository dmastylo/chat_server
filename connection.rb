class Connection

  attr_accessor :nick_name, :client

  def initialize(nick_name, client)
    @nick_name = nick_name
    @client = client
  end

end