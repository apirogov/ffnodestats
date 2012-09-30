#!/usr/bin/env ruby
#NodeStat is the upper layer to request statistics
#Copyright (C) 2012 Anton Pirogov
#Licensed under the GPLv3

require './nodequery.rb'

#patches in helpers for dates
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

  #takes optional :db and :json parameters to be passed to NodeQuery
  def initialize(h={})
    @db = h[:db]
    @json = h[:json]
  end

  #Return all client connections to routers in given time (or for current day if no times given)
  #client = client mac
  #start = Time
  #length = hours
  def client_timeline(client, start=nil, length=nil)
    query(start, length).client_connections client
  end

  #Return all client connections to this router in given time (or for current day if no times given)
  #sorted by the time they started
  #router = router mac or name
  #start = Time
  #length = hours
  def router_timeline(router, start=nil, length=nil)
    q = query(start, length)

    clients = q.router_clients(router)
    clients.map{|c| q.client_connections c, router}.inject(&:+).to_a.sort_by{|c| c[:start]}
  end

  #list of clients and how long in total (seconds) each was connected to a FF router for given time
  def client_activity(start=nil, length=nil)
    q = query(start,length)
    clients = q.clients
    clients.map do |c|
      [c, q.client_connections(c).map{|c| c[:end]-c[:start]}.inject(&:+)]
    end
  end

  #list of routers and how many unique visitors they had in the given time
  def unique_visitors(start=nil, length=nil)
    q = query(start,length)
    routers = q.routers
    routers.map{|r| [r, q.router_clients(r).length]}
  end

  #TODO: test after reimplementing backend with sqlite
  def average_visitors(start=nil, length=nil)
    q = query(start,length)
    routers = q.routers
    routers.map do |r|
      loads = router_client_load r
      avg = loads.map{|l| l[1]}.inject(&:+).to_f/loads.length
      [r, avg]
    end
  end

  #---- splits time into discrete slices ----

  #returns an array of [Time,client_count] pairs
  #router -> router name or mac
  #start -> start time
  #length -> length of timespan in hours
  #step -> X scale in minutes (default: 30)
  def router_client_load(router,step=30,start=nil,length=nil)
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

    return NodeQuery.new(fr: start, to: endtime, db: @db, json: @json)
  end
end
