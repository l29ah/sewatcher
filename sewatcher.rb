#!/usr/bin/env ruby
# encoding: ASCII-8BIT

require 'rb-inotify'
require 'pathname'

def get_savename(filename)
	pt = Pathname.new(filename)
	pt.basename
end

def get_turn(filename)
	sf = IO.popen(["unzip", "-c", "-P", "GarfieldJonesCat", filename])

	d = sf.read(5000)

	desc_string = "This is the base file for creation the random planets."

	desc_pos = (d.index(desc_string))

	turn_pos = desc_pos + desc_string.size+1

	d[turn_pos].ord
end



notifier = INotify::Notifier.new

initial_message = "separser initialized\n"

Dir.glob("#{ARGV[0]}/*.se1") do |savefile|
	turn = get_turn(savefile)
	initial_message << "#{get_savename(savefile)}: turn for #{get_turn(savefile)}\n"
end

system("notify-send", initial_message)

exit

notifier.watch(ARGV[0], :moved_to) do |event|
	
end
