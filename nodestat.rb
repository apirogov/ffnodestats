#!/usr/bin/env ruby
#NodeStat is the upper layer to request statistics
#Copyright (C) 2012 Anton Pirogov
#Licensed under the GPLv3

require './nodequery.rb'

#monkey patches helpers for times
class Time
def self.today
  t=Time.now
  Time.new(t.year,t.month,t.day,0,0)
end

def self.yesterday
  today-day_secs
end

def self.tomorrow
  today+day_secs
end

def self.hour_secs
  3600
end

def self.day_secs
  86400
end
end

class NodeStat

  @@default_start = Time.today
  @@default_length = 24 #hours

  #takes optional db parameter to be passed to NodeQuery
  def initialize(dbfile=nil)
    @db = dbfile
  end

  #array of known routers
  def routers(start=nil, length=nil)
    query(start, length).routers.sort
  end

  #array of known clients
  def clients(start=nil, length=nil)
    query(start, length).clients.sort
  end

  #Return all client connections to routers in given time (or for current day if no times given)
  #client = client mac
  #start = Time
  #length = hours
  def client_timeline(client, start=nil, length=nil)
    query(start, length).client_connections(client).group_by{|c| c[:router]}
  end

  #Return all client connections to this router in given time (or for current day if no times given)
  #sorted by the time they started
  #router = router mac or name
  #start = Time
  #length = hours
  def router_timeline(router, start=nil, length=nil)
    q=query(start, length)
    q.router_clients(router).map{|c| q.client_connections c, router}
  end

  #list of clients and how long in total (seconds) each was connected to a FF router for given time
  def client_activity(start=nil, length=nil)
    q = query(start,length)
    q.clients.map do |c|
      [c, q.client_connections(c).map{|c| c[:end]-c[:start]}.inject(&:+)]
    end
  end

  #list of routers and how many unique visitors they had in the given time
  #TODO: speed up (takes half a minute per router per 25h :/)
  def unique_visitors(start=nil, length=nil)
    q = query(start,length)
    q.routers.map{|r| [r, q.router_clients(r).length]}
  end

  #list of routers and how many connections on average they had in the given time
  #TODO: speed up (takes a minute per router per 24h :/)
  def average_visitors(start=nil, length=nil)
    q = query(start,length)
    q.routers.map do |r|
      avg = router_load_average(r,start,length)
      [r, avg]
    end
  end

  #returns average router load without splitting time up -> a little bit faster
  def router_load_average(router, start=nil, length=nil)
    length=@@default_length if length.nil?
    q = query(start,length)
    clients = q.router_clients(router)
    connections = clients.map{|c| q.client_connections(c, router)}.inject(&:+)
    lengths = connections.map{|c| c[:end]-c[:start]}
    totallength = lengths.inject(&:+).to_f
    return totallength/(length.to_f*Time.hour_secs)
  end

  #splits time into discrete slices, does multiple requests
  #returns an array of [Time,number of clients on this router] pairs
  #router -> router name or mac
  #start -> start time
  #length -> length of timespan in hours
  #step -> X scale in minutes (default: 30)
  def router_load(router,start=nil,length=nil,step=nil)
    puts router,start,length,step
    step=30 if step.nil?
    start=@@default_start if start.nil?
    length=@@default_length if length.nil?
    step = step.to_f/60.to_f #to hours
    endtime = start+length*Time.hour_secs

    ret = []
    slice_start = start.dup
    while slice_start < endtime
      ret << [slice_start, query(slice_start,step).router_clients(router).length]
      slice_start += step*Time.hour_secs
    end
    ret
  end

  private

  #return NodeQuery object initialized correctly for given start and timespan length
  #start and/or length can be nil and be set to sane defaults (whole currently running day if omitting both)
  def query(start, length)
    start=@@default_start if start.nil?
    length=@@default_length if length.nil?
    endtime = start+length*Time.hour_secs

    return NodeQuery.new(fr: start, to: endtime, db: @db)
  end
end
