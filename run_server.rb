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
    puts "#{arg} is not in the valid port range (1024 through 65536)"
  end
end

abort('No ports specified.') if ports.length < 1

ChatServer.new(ports, verbose, development_mode)