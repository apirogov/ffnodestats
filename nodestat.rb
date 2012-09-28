#!/usr/bin/env ruby
#NodeStat - represents a slice of connection information in a given time span
#needs a textfile database of connections and a nodes.json
#to resolve multiple MACs to one node
#Copyright (C) 2012 Anton Pirogov

require 'date'
require 'ffmaplib'

class NodeStat

  attr_reader :cons
  attr_reader :list

  #initialize a NodeStat object to make requests
  #which includes all entries for a given time span
  def initialize(hash={})
    hash[:fr] = Time.at(0) if hash[:fr].nil?
    hash[:to] = Time.now if hash[:to].nil?
    hash[:db] = File.expand_path('./db') if hash[:db].nil?

    fr = hash[:fr]
    to = hash[:to]
    db = hash[:db]
    json = hash[:json]

    frd = Time.new(fr.year,fr.month,fr.day,0,0).to_i
    tod = Time.new(to.year,to.month,to.day,0,0).to_i

    #get all entries of days touched in span
    files = (Dir.entries(db)-['.','..']).map(&:to_i).select{|t| t>=frd && t<=tod}.map(&:to_s)

    #convert to hashs and do fine filtering
    @cons = files.map{|f| loadfile db+'/'+f}.inject(&:+).select{|c| c[:time]>=fr && c[:time]<=to}

    json = ENV['NODEJSON_PATH'] if json.nil?
    json = DEFAULT_NODESRC if json.nil?

    @list = NodeWrapper.new json
  end

  #all known routers in that timespan
  def routers
    @cons.map{|c| c[:router]}.uniq.map{|m| @list[m].label}
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
    #TODO: fix last entry connection
    cs = @cons.select{|c| c[:client]==client}.sort_by{|c| c[:time]}
    cons = []

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

  #filepath -> array of connection entry hashs
  def loadfile(file)
    File.readlines(file).map{|l| l.split(/\s+/)}.map do |l|
      {time: Time.at(l[0].to_i), router: l[1], client: l[2]}
    end
  end

  #try to resolve that router mac to a specific router known in nodes.json
  #if not possible, return back that mac
  def try_resolve(router)
    return @list[router].label if @list[router]
    router
  end

end
