#!/usr/bin/env ruby
#script getting data for ffnodestats
#Copyright (C) 2012 Anton Pirogov
#Usage: DBPATH=/path/to/dir ruby updater.rb
#Format:
#the files in DBPATH represent all connection snapshots for a day
#the file name is the unix time of the beginning of that day
#a snapshot entry is:
#timestamp AP-MAC Client-MAC

require 'ffmaplib'

dbpath = ENV['DBPATH']
jsonpath = DEFAULT_NODESRC

if dbpath.to_s.empty?
  puts "Please set DBPATH env var!"
  exit 1
end

if !`mkdir -p #{dbpath} 2>&1`.chomp.strip.empty?
  puts "Failed to create DB directory!"
  exit 1
end

timestamp = Time.now.to_i
list = NodeWrapper.new jsonpath

connections = []
list.online.routers.to_a.each do |r|
  r.clients.ids.each{|c| connections << "#{timestamp} #{r.id} #{c}"}
end

todayfile = Time.new(Time.now.year, Time.now.month, Time.now.day, 0, 0).to_i.to_s
File.open(dbpath+'/'+todayfile,'a') do |f|
  connections.each{|c| f.puts c}
end
