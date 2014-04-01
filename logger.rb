module Logger

  class << self

    def init(verbose)
      @verbose = verbose
    end

    def log(connection, message, state)
      return unless @verbose

      if connection.nick_name
        host_name = "#{connection.nick_name} (#{connection.client_full_address})"
      else
        host_name = connection.client_full_address
      end

      if state == "send"
        message = "SENT to #{host_name}:\n#{message}"
      elsif state == "receive"
        message = "RCVD from #{host_name}:\n#{message}"
      elsif state == "leave"
        message = "#{host_name} (#{connection.nick_name}) HAS LEFT"
      end

      puts message
    end

  end

end
