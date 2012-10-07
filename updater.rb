#!/usr/bin/env ruby
#script getting data for ffnodestats
#Copyright (C) 2012 Anton Pirogov
#Usage: DBPATH=/path/to/db.db ruby updater.rb

require 'sqlite3'
require 'ffmaplib'

dbp = ENV['DBPATH']
jsonpath = ENV['JSONPATH']
jsonpath = 'http://holstentor.ffhl/nodes/nodes.json'
jsonpath = DEFAULT_NODESRC if jsonpath.nil?

if dbp.to_s.empty?
  puts "Please set DBPATH env var!"
  exit 1
end

#init database if not existing
if !File.exists?(dbp)
  SQLite3::Database.new(dbp) do |db|
    db.execute "CREATE TABLE connections (time INTEGER, router VARCHAR(17), client VARCHAR(17));"
    db.execute "CREATE TABLE routers (router VARCHAR(255), macs VARCHAR(255));"
  end
end

#read data from json and generate connection rows
tries = 0
list = nil
timestamp = nil
begin
  tries += 1
  timestamp = Time.now.to_i
  list = NodeWrapper.new jsonpath
rescue
  sleep 10
  retry if tries<5
  exit 1
end

connections = []
list.online.routers.to_a.each do |r|
  r.clients.ids.each{|c| connections << "#{timestamp} #{r.id} #{c}"}
end

routers = list.routers.to_a.map{|r| {router: r.label, macs: r.macs.join(' ')}}

db = SQLite3::Database.new(dbp)

#overwrite router->mac list
#NOTE: as long as there are less than 500 routers it can be written in one command
db.execute "DELETE FROM routers"
cmd = "INSERT INTO routers (router, macs) VALUES "
routers.each{|r| cmd += "(\"#{r[:router]}\", \"#{r[:macs]}\"),"}
cmd[-1] = ';'
db.execute cmd

#write new connections in 500 row blocks to database

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
