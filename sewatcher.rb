#!/usr/bin/env ruby
# encoding: ASCII-8BIT

require 'rb-inotify'
require 'pathname'
require 'open3'
require 'optparse'

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

def do_notification(text)
	if $options[:stdout]
		puts text
	end
	if !$options[:no_notify]
		system("notify-send", "sewatcher: #{text}")
	end
end


$options = {}
OptionParser.new do |opts|
	opts.banner = "Notifies you of new turns in Shadow Empire games in given dirs.
	Usage: #{$0} [$options] <savedir> [<savename:playerno> ...]"

	opts.on("-p", "--parse", "Parse all save files once, notify and exit") do |v|
		$options[:parse] = true
	end
	
	opts.on("-n", "--no-notify", "Don't notify-send") do |v|
		$options[:no_notify] = true
	end
	
	opts.on("-s", "--stdout", "Notify on stdout") do |v|
		$options[:stdout] = true
	end
	
	opts.on("-a", "--all", "Display all turns, not only yours") do |v|
		$options[:all] = true
	end
	
	opts.on("-w", "--watch", "Like --all, but display others' turns only on stdout. Implies --all, --stdout") do |v|
		$options[:all] = true
		$options[:stdout] = true
		$options[:stdout_others] = true
	end
end.parse!

notifier = INotify::Notifier.new


$saves = Hash.new
$mynumbers = Hash.new

ARGV[1..-1].each do |myn|
	save,number = myn.split(":")
	number = :any if !number
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

do_notification initial_message

exit if $options[:parse]

notifier.watch(ARGV[0], :moved_to, :close_write) do |event|
	next unless event.name =~ /.se1$/
	fname = "#{ARGV[0]}/#{event.name}"
	turn = get_turn(fname)
	next unless turn
	you = your_number(event.name)
	if $saves[event.name] != turn && ($options[:all] || you == turn || you == :all)
		itsyou = if you == turn then " (you)" else "" end
		notification = "[#{event.name}] player #{turn}#{itsyou}"
		if $options[:stdout_others] && you != turn
			puts notification
		else
			do_notification notification
		end
	end
	$saves[event.name] = turn
end

notifier.run
