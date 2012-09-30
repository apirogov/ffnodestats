#!/usr/bin/env ruby
#script getting data for ffnodestats
#Copyright (C) 2012 Anton Pirogov
#Usage: DBPATH=/path/to/db.db ruby updater.rb

require 'sqlite3'
require 'ffmaplib'

dbp = ENV['DBPATH']
jsonpath = DEFAULT_NODESRC

if dbp.to_s.empty?
  puts "Please set DBPATH env var!"
  exit 1
end

#init database if not existing
if !File.exists?(dbp)
  SQLite3::Database.new(dbp) do |db|
    db.execute "CREATE TABLE connections (time INTEGER, router VARCHAR(17), client VARCHAR(17));"
  end
end

#read data from json and generate connection rows
timestamp = Time.now.to_i
list = NodeWrapper.new jsonpath

connections = []
list.online.routers.to_a.each do |r|
  r.clients.ids.each{|c| connections << "#{timestamp} #{r.id} #{c}"}
end

#write new connections in 500 row blocks to database
db = SQLite3::Database.new(dbp)

#template for insert
cmd = "INSERT INTO connections (time, router, client) VALUES "

curr = cmd
counter = 0

connections.each do |r|
  r=r.split(/\s+/)
  curr += "(#{r[0]}, \"#{r[1]}\", \"#{r[2]}\"),"
  counter += 1

  if counter == 500
    puts "block"
    curr[-1]=";"  #close command
    db.execute curr

    counter = 0
    curr = cmd
  end
end

#write rest if any
if counter != 0
  curr[-1]=";"
  db.execute curr
end

db.close
