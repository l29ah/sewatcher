#!/usr/bin/env ruby
# encoding: ASCII-8BIT

require 'rb-inotify'
require 'pathname'
require 'open3'

def get_savename(filename)
	pt = Pathname.new(filename)
	pt.basename.to_s
end

def get_turn(filename)
	out, err, status = Open3.capture3("unzip", "-c", "-P", "GarfieldJonesCat", filename)

	if !status.success?
		# it's not a save yet, likely
		return nil
	end

	desc_string = "This is the base file for creation the random planets."

	desc_pos = (out.index(desc_string))

	turn_pos = desc_pos + desc_string.size+1

	out[turn_pos].ord
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
	next unless turn
	savename = get_savename(savefile)
	itsyou = if your_number(savename) == turn then " (you)" else "" end
	$saves[savename] = turn
	initial_message << "[#{savename}] player #{turn}#{itsyou}\n"
end

system("notify-send", initial_message)

notifier.watch(ARGV[0], :moved_to, :close_write) do |event|
	next unless event.name =~ /.se1$/
	fname = "#{ARGV[0]}/#{event.name}"
	turn = get_turn(fname)
	next unless turn
	you = your_number(event.name)
	$saves[event.name] = turn
	if $saves[event.name] != turn && (!you || turn == you)
		itsyou = if you == turn then " (you)" else "" end
		system("notify-send", "sewatcher: [#{event.name}] player #{turn}#{itsyou}")
	end
end

notifier.run
