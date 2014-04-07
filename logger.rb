module Logger

  class << self

    def init(verbose)
      @verbose = verbose
    end

    def log(connection, message = nil, state)
      return unless @verbose

      host_name = connection.client_full_address

      if state == "send"
        message = "SENT to #{host_name}:\n#{message}"
      elsif state == "send_random"
        message = "SENT (randomly!) to #{host_name}:\n#{message}"
      elsif state == "receive"
        message = "RCVD from #{host_name}:\n#{message}"
      elsif state == "leave"
        message = "#{host_name} (#{connection.nick_name}) HAS LEFT"
      end

      puts message
    end

  end

end
