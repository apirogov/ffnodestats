#!/usr/bin/env ruby
#NodeStat - represents a slice of connection information in a given time span
#Copyright (C) 2012 Anton Pirogov

require 'date'
require 'ffmaplib'

class NodeStat

  attr_reader :cons
  attr_reader :list

  #initialize a NodeStat object to make requests
  #which includes all entries for a given time span
  def initialize(fr, to, db=File.expand_path('./db'), json=DEFAULT_NODESRC)
    frd = Time.new(fr.year,fr.month,fr.day,0,0).to_i
    tod = Time.new(to.year,to.month,to.day,0,0).to_i

    #get all entries of days touched in span
    files = Dir.entries(db).map(&:to_i).select{|t| t>=frd && t<=tod}.map(&:to_s)

    #convert to hashs and do fine filtering
    @cons = files.map{|f| loadfile db+'/'+f}.inject(&:+).select{|c| c[:time]>=fr && c[:time]<=to}

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
    lbl = @list[router].label
    @cons.select{|c| @list[c[:router]].label == lbl}.map{|c| c[:client]}.uniq
  end


  private

  #filepath -> array of connection entry hashs
  def loadfile(file)
    File.readlines(file).map{|l| l.split(/\s+/)}.map{|l| {time: Time.at(l[0].to_i), router: l[1], client: l[2]} }
  end

end
