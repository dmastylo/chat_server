class Logger

  def initialize(verbose)
    @verbose = verbose
  end

  def log(connection, message, state)
    return unless @verbose

    host_name = connection.client.peeraddr(:hostname)
    host_name = "#{host_name[2]}:#{host_name[1]}"

    if state == "send"
      message = "SENT to #{host_name}: #{message}"
    elsif state == "receive"
      message = "RCVD from #{host_name}: #{message}"
    end

    puts message
  end

end
