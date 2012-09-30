#!/usr/bin/env ruby
#NodeQuery - represents a slice of connection information in a given time span
#needs a textfile database of connections and a nodes.json
#to resolve multiple MACs to one node
#Copyright (C) 2012 Anton Pirogov

#TODO: maybe port mac<->names to some sqlite table and write from the updater?

require 'date'
require 'sqlite3'

require 'ffmaplib'

class NodeQuery

  attr_reader :cons
  attr_reader :list

  #initialize a NodeStat object to make requests
  #which includes all entries for a given time span
  #hash parameters: :fr=start Time (default: unixtime 0) :to=end Time (default: right now)
  #:db = path to data files (default= ./db) :json=path or URI to nodes.json (default: burgtor.ffhl/mesh/nodes.json)
  def initialize(hash={})
    hash[:fr] = Time.at(0) if hash[:fr].nil?
    hash[:to] = Time.now if hash[:to].nil?
    hash[:db] = './ffnodestats.db' if hash[:db].nil?

    fr = hash[:fr].to_i
    to = hash[:to].to_i
    db = hash[:db]
    json = hash[:json]

    #load rows requested
    db = SQLite3::Database.new(db)
    @cons = db.execute "select * FROM connections WHERE time BETWEEN #{fr} AND #{to}"
    @cons.map!{|a| {time: Time.at(a[0]), router: a[1], client: a[2]}}
    db.close

    #load node json file to resolve macs
    json = ENV['NODEJSON_PATH'] if json.nil?
    json = DEFAULT_NODESRC if json.nil?
    @list = NodeWrapper.new json
  end

  #all known routers in that timespan
  def routers
    @cons.map{|c| c[:router]}.uniq.map{|m| n=@list[m]; n.nil? ? m : n.label}
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

  #try to resolve that router mac to a specific router known in nodes.json
  #if not possible, return back that mac
  def try_resolve(router)
    return @list[router].label if @list[router]
    router
  end

end
