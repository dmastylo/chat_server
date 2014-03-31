class Connection

  attr_accessor :nick_name, :client, :thread

  def initialize(nick_name, client, thread)
    @nick_name = nick_name
    @client = client
    @thread = thread
  end

end