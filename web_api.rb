#! /usr/bin/env ruby

require 'sinatra'
require_relative "lru"
require_relative "mars_trek"

set :port, 4441
set :environment, :production

url_cache = LRUdata.new(size: 3000)
hit_times = LRUdata.new(size: 1000)
hit_rates = LRUdata.new(size: 100)

mars_trek = MarsTrek.new

def end_time(start) ((Time.now - start).to_f * 1000).truncate(5) end  # Format Time Response
def sum_array(s) s.inject(0){|sum,x| sum + x } end
def avg_array(a) (sum_array(a).to_f / a.length.to_f).truncate(5) end

get('/') { 'pong' }     # Root respond pong to pings

get '/cache' do
    content_type 'application/json'
    url_cache.cache.to_json
end

get '/cache/hit_rate' do
    content_type 'application/json'
    sum = hit_rates.cache.inject(0){|acc,x| acc + x }.to_f
    len = hit_rates.cache.length.to_f
    hit = "%.2f" % ( ( sum / len ) * 100 )
    mis = "%.2f" % ( 100 - hit.to_f )
    { 'hit' => hit, 'mis' => mis, 'dsc' => "Hit Rates over the last 100 requests" }.to_json
end

get '/cache/hit_counts' do
    content_type 'application/json'
    tot = hit_rates.cache.length
    hit = hit_rates.cache.inject(0){|sum,x| sum + x }
    mis = ( tot - hit )
    { 'hit' => hit, 'mis' => mis, 'total' => tot, 'dsc' => "Hit counts over the last 100 requests" }.to_json
end

get '/cache/hit_times' do
    content_type 'application/json'
    hits_building = hit_times.cache.map {|t| t['time'] if t['hit'] && ! t['full']}.compact
    miss_building = hit_times.cache.map {|t| t['time'] if ! t['hit'] && ! t['full']}.compact
    miss_full     = hit_times.cache.map {|t| t['time'] if ! t['hit'] && t['full']}.compact

    hits_building = [0] if hits_building.empty?
    miss_building = [0] if miss_building.empty?
    miss_full     = [0] if miss_full.empty?

    {
        'building' => {
            'hit' => {
                'sum' => sum_array(hits_building).truncate(5),
                'avg' => avg_array(hits_building),
                'min' => hits_building.min,
                'max' => hits_building.max
            },
            'miss' => {
                'sum' => sum_array(miss_building).truncate(5),
                'avg' => avg_array(miss_building),
                'min' => miss_building.min,
                'max' => miss_building.max
            }
        },
        'full' => {
            'miss' => {
                'sum' => sum_array(miss_full).truncate(5),
                'avg' => avg_array(miss_full),
                'min' => miss_full.min,
                'max' => miss_full.max
            }
        }
    }.to_json
end

get '/coordinate/url/:lat/:long' do

	latitude  = params['lat'].to_f
	longitude = params['long'].to_f

	unless latitude.between?(-90,90) && longitude.between?(-180,180)
		return 400, "#{latitude} or #{longitude} are out of bounds (-90,90), (-180,180)"
	end

    start = Time.now

	coordinate = "#{latitude},#{longitude}"
	cached_url = url_cache.select(coordinate)
    cache_full = url_cache.cache.length >= 15
    k, cached_value = cached_url.first unless cached_url.nil?

	if cached_url.nil?
        hit_rates.add(0)
		url = mars_trek.GetImageURL(latitude, longitude)
		if url.nil?
			url_cache.add({ coordinate => 404 })
			return 404, "No URL Found"
		else
			url_cache.add({ coordinate => url })
		end
        runtime, cached = end_time(start), false
	elsif cached_value == 404
        hit_rates.add(1)
        runtime, cached = end_time(start), true
		return 404, "No URL Found"
	else
        hit_rates.add(1)
        runtime, cached = end_time(start), true
		url = cached_value
	end

    hit_times.add({'time' => runtime, 'hit' => cached, 'full' => cache_full})

	url

end