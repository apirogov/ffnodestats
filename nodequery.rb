#!/usr/bin/env ruby
#NodeQuery - represents a slice of connection information in a given time span
#Copyright (C) 2012 Anton Pirogov
#Licensed under the GPLv3

require 'date'
require 'sqlite3'

class NodeQuery

  attr_reader :cons
  attr_reader :macs

  #initialize a NodeStat object to make requests
  #which includes all entries for a given time span
  #hash parameters: :fr=start Time (default: unixtime 0) :to=end Time (default: right now)
  #:db = path to data files (default= ./db)
  def initialize(hash={})
    hash[:fr] = Time.at(0) if hash[:fr].nil?
    hash[:to] = Time.now if hash[:to].nil?
    hash[:db] = './ffnodestats.db' if hash[:db].nil?

    fr = hash[:fr].to_i
    to = hash[:to].to_i
    db = hash[:db]

    #load rows requested
    db = SQLite3::Database.new(db)
    @macs = db.execute("SELECT * FROM routers").map{|e| {router: e[0], macs: e[1].split(' ')}}
    @cons = db.execute "SELECT * FROM connections WHERE time BETWEEN #{fr} AND #{to}"
    @cons.map!{|a| {time: Time.at(a[0]), router: a[1], client: a[2]}}
    db.close
  end

  #all known routers in that timespan
  def routers
    @cons.map{|c| c[:router]}.uniq.map{|m| try_resolve m}
  end

  #all known clients in that timespan
  def clients
    @cons.map{|c| c[:client]}.uniq
  end

  #all unique clients a router had in that timespan
  def router_clients(router)
    lbl = try_resolve router
    @cons.select{|c| try_resolve(c[:router]) == lbl}.map{|c| c[:client]}.uniq
  end

  #all unique routers a client was connected to in that timespan
  def client_routers(client)
    @cons.select{|c| c[:client]==client}.map{|c| try_resolve c[:router]}.uniq
  end

  #get all connections of a client in that timespan
  #if router name or mac given, only return connections to that router
  def client_connections(client, router=nil)
    cs = @cons.select{|c| c[:client]==client}.sort_by{|c| c[:time]}
    cons = []
    return cs if cs==[]

    c = cs.shift
    curr = {client: client, router: try_resolve(c[:router]), start: c[:time], end: c[:time]}
    cs.each do |c|
      #same router as last check and no gap of more than 20 minutes
      if try_resolve(c[:router]) == curr[:router] && c[:time]-curr[:end]<1200
        curr[:end] = c[:time]  #still connected -> change end-time
      else  #changed routers or offline -> new connection entry
        cons << curr
        curr = {client: client, router: try_resolve(c[:router]), start: c[:time], end: c[:time]}
      end
    end
    cons << curr  #put last one in

    cons.select!{|c| c[:router] == try_resolve(router)} if !router.nil?
    cons
  end

 # private

  #try to resolve that router mac to a specific known router name
  #if not possible, return back that mac
  def try_resolve(router)
    ret = @macs.find{|e| e[:router]==router || e[:macs].index(router)}
    return ret[:router] if ret #found something?
    router  #nope
  end

end
