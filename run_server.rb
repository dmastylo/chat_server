require 'socket'
require 'thread'
require './chat_server'

abort('Not enough arguments! Please specify the ports you want, and, optionally, a -v flag for logging.') if ARGV.length < 1

ports = []
servers = []

# Filter the args
verbose = ARGV.delete("-v")
development_mode = ARGV.delete("-d")
ARGV.each do |arg|
  arg_num = arg.to_i
  if (arg_num > 1023 && arg_num < 65536)
    ports << arg_num
  else
    puts "port number must be between 1024 and 65536"
  end
end

abort('No ports specified.') if ports.length < 1

puts "Ports: ", ports

ChatServer.new(ports, verbose, development_mode)

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