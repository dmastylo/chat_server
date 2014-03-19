abort("Not enough arguments!") if ARGV.length < 1

# Store command line port numbers
port_numbers = []

# Store arguments in port_numbers
ARGV.each do |arg|
	arg_num = arg.to_i
	port_numbers << arg_num if (arg_num > 0 && arg_num < 65536)
end

puts port_numbers