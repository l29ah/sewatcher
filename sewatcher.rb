#!/usr/bin/env ruby
# encoding: ASCII-8BIT

require 'rb-inotify'
require 'pathname'

def get_savename(filename)
	pt = Pathname.new(filename)
	pt.basename.to_s
end

def get_turn(filename)
	sf = IO.popen(["unzip", "-c", "-P", "GarfieldJonesCat", filename])

	d = sf.read(5000)

	desc_string = "This is the base file for creation the random planets."

	desc_pos = (d.index(desc_string))

	turn_pos = desc_pos + desc_string.size+1

	d[turn_pos].ord
end

def your_number(savefile)
	$mynumbers[savefile]
end


notifier = INotify::Notifier.new


$saves = Hash.new
$mynumbers = Hash.new

ARGV[1..-1].each do |myn|
	save,number = myn.split(":")
	$mynumbers[save] = number.to_i
end

initial_message = "sewatcher initialized\n"

Dir.glob("#{ARGV[0]}/*.se1") do |savefile|
	turn = get_turn(savefile)
	savename = get_savename(savefile)
	itsyou = if your_number(savename) == turn then " (you)" else "" end
	$saves[savename] = turn
	initial_message << "[#{savename}] player #{turn}#{itsyou}\n"
end

system("notify-send", initial_message)

notifier.watch(ARGV[0], :moved_to) do |event|
	fname = "#{ARGV[0]}/#{event.name}"
	turn = get_turn(fname)
	you = your_number(event.name)
	if $saves[event.name] != turn && (!you || turn == you)
		itsyou = if you == turn then " (you)" else "" end
		$saves[event.name] = turn
		system("notify-send", "sewatcher: [#{event.name}] player #{turn}#{itsyou}")
	end
end

notifier.run
