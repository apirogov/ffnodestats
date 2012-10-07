#!/usr/bin/env ruby
#Webinterface für NodeStats
#Copyright (C) 2012 Anton Pirogov
#Licensed under the GPLv3
#TODO: implement timeline feature using scatter graph from google chart tools

require 'sinatra'
require 'json'

require './nodestat.rb'

TITLE="ffnodestats UI"

stat = NodeStat.new

#interface to request json data for visualizations
get '/json' do
  content_type :json

  t = params['type'].to_s
  o = params['obj'].to_s #used to tell which router/client is requested
  s = Time.at(params['start'].to_i) #unixtime, start of timespan
  l = params['length'].to_f #hours, length of timespan
  step = params['step']  #step in minutes for router_load

  data = case t
  when 'routers'
    stat.routers s, l
  when 'clients'
    stat.clients s, l
  when 'ctimeline'
    stat.client_timeline o, s, l
  when 'rtimeline'
    stat.router_timeline o, s, l
  when 'cactivity'
    stat.client_activity s, l
  when 'runique'
    stat.unique_visitors s, l
  when 'raverage'
    stat.average_visitors s, l
  when 'rload'
    stat.router_load o, s, l, step
  else {}
  end

  JSON.generate data
end

get '/' do
  erb :index
end
