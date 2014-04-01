module Logger

  class << self

    def init(verbose)
      @verbose = verbose
    end

    # TODO generic for TCP, UDP
    def log(connection, message, state)
      return unless @verbose

      host_name = connection.client_full_address

      if state == "send"
        message = "SENT to #{host_name}: #{message}"
      elsif state == "receive"
        message = "RCVD from #{host_name}: #{message}"
      elsif state == "leave"
        message = "#{host_name} (#{connection.nick_name}) has left"
      end

      puts message
    end

  end

end
