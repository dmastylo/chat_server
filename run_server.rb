require 'socket'
require 'thread'

abort('Not enough arguments!') if ARGV.length < 1

ports = []
servers = []

ARGV.each do |arg|
  if (arg_num > 1023 && arg_num < 65536)
    ports << arg_num.to_i
  else
    puts "port number must be between 1024 and 65536"
  end
end

puts ports

ports.each { |port| servers << TCPServer.new(port) }

loop do
  servers.each do |server|
    Thread.fork(server.accept) do |client|

      client.puts("Hey, I'm a Ruby Chat server")
      while (input = client.gets)
        puts input
      end
      client.puts("I'm disconnecting, bye")
      client.close
    end
  end
end

# Connecting with TCPSocket to see if its open
# threads = []
# ports.each do |port|
#   threads << Thread.new(port) do |p|
#     puts "Check if port " + p.to_s + " is open"

#     begin
#       t = TCPSocket.new('0.0.0.0', p)
#       t.close
#       puts "Port " + p.to_s + " is open."
#     rescue
#       puts "Port " + p.to_s + " is not open."
#     end
#   end
# end

# threads.map &:join

# Threads listening on UDP ports
# threads = ports.collect do |port|
#   Thread.new do
#     while($running) do
#       payload, host = udp_socket.recvfrom(port)
#       process payload
#     end
#   end
# end

# threads.map &:join