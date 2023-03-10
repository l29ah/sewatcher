#!/usr/bin/env ruby
# encoding: ASCII-8BIT

require 'rb-inotify'
require 'pathname'
require 'open3'
require 'optparse'
require 'yaml'

def get_savename(filename)
	pt = Pathname.new(filename)
	pt.basename.to_s
end

def get_turn(filename)
	out, _, status = Open3.capture3("unzip", "-c", "-P", "GarfieldJonesCat", filename)

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

def do_notification(text, notify)
	if $options[:stdout] && (notify || $options[:verbose])
		puts text
		STDOUT.flush
	end
	if !$options[:no_notify] && notify
		system("notify-send", "sewatcher: #{text}")
	end
end

$options = {}
OptionParser.new do |opts|
	opts.banner = "Notifies you of new turns in Shadow Empire games in given dirs.
	Usage: #{$0} [options] <config.yml>"
	
	opts.on("-n", "--no-notify", "Don't notify-send") do |v|
		$options[:no_notify] = true
	end
	
	opts.on("-p", "--parse", "Parse files once, then exit") do |v|
		$options[:parse] = true
	end
	
	opts.on("-s", "--stdout", "Notify on stdout") do |v|
		$options[:stdout] = true
	end
	
	opts.on("-V", "--verbose", "Notify about all turn changes on stdout. Implies --stdout") do |v|
		$options[:verbose] = true
		$options[:stdout] = true
	end
end.parse!

config = YAML.load_file(ARGV[0])
notifier = INotify::Notifier.new

$saves = Hash.new
$mynumbers = Hash.new

ARGV[1..-1].each do |myn|
	save,number = myn.split(":")
	number = :any if !number
	$mynumbers[save] = number.to_i
end

initial_message = "sewatcher initialized\n"

config["games"].each do |game|
	game["nicks"] ||= {}
	filename = Pathname::new(game["file"]).expand_path.to_s
	turn = get_turn(filename)
	nick = game["nicks"][turn]
	nickstring = if nick then " - #{nick}" else "" end
	next unless turn
	itsyou = if game["turn"] == turn then " (you)" else "" end
	$saves[filename] = turn
	initial_message << "[#{game["name"] || filename}] player #{turn}#{nickstring}#{itsyou}\n"
end

do_notification initial_message, true

exit if $options[:parse]

config["games"].each do |game|
	Thread.new do
		fullname = Pathname.new(game["file"]).expand_path
		dir = fullname.dirname.to_s
		filename = fullname.to_s
		notifier.watch(dir, :moved_to, :close_write) do |event|
			event_filename = Pathname.new("#{dir}/#{event.name}").expand_path.to_s
			next unless event_filename == filename
			turn = get_turn(filename)
			next unless turn
			nick = game["nicks"][turn]
			nickstring = if nick then " - #{nick}" else "" end
			yourturn = (game["turn"] == turn)
			itsyou = yourturn ? " (you)" : ""
			if ($saves[filename] == turn)
				next unless $options[:verbose]
				reopened = " (reopened)"
				yourturn = false
			else
				reopened = ""
				$saves[filename] = turn
			end
			notification = "[#{game["name"] || filename}] player #{turn}#{nickstring}#{itsyou}#{reopened}"
			do_notification notification, yourturn
		end
	end
end

notifier.run
