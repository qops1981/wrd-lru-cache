#! /usr/bin/env ruby

require 'sinatra'
require_relative "lru"
require_relative "mars_trek"

set :port, 4441
set :environment, :production

url_cache = LRUdata.new(size: 3000) # Main LRU Cache
hit_times = LRUdata.new(size: 1000) # Using LRU cache to hold metrics
hit_rates = LRUdata.new(size: 100)

mars_trek = MarsTrek.new

## Some Array helper methods ##
#  Note: Could Extend these off the Array class itself

def end_time(start) ((Time.now - start).to_f * 1000).truncate(5) end    # Return formated runtime
def sum_array(s) s.inject(0){|sum,x| sum + x } end                      # Sum an array
def avg_array(a) (sum_array(a).to_f / a.length.to_f).truncate(5) end    # Average of Array values

get('/') { 'pong' }         # Root respond pong to pings

get '/cache' do # present the whole LRU cache
    content_type 'application/json'
    url_cache.cache.to_json
end

get '/cache/hit_rate' do    # Metrics on hit rates
    content_type 'application/json'
    sum = hit_rates.cache.inject(0){|acc,x| acc + x }.to_f  # Hits are all 1, a count is literal
    len = hit_rates.cache.length.to_f
    hit = ( ( sum / len ) * 100 ).truncate(5)               # Multiplied by 100 to make %
    mis = ( 100 - hit ).truncate(5)                         # Misses are the inverse of the hit rate
    { 'hit' => hit, 'mis' => mis, 'dsc' => "Hit Rates over the last 100 requests" }.to_json
end

get '/cache/hit_counts' do  # Metrics on hit counts
    content_type 'application/json'
    tot = hit_rates.cache.length
    hit = hit_rates.cache.inject(0){|sum,x| sum + x }
    mis = ( tot - hit )
    { 'hit' => hit, 'mis' => mis, 'total' => tot, 'dsc' => "Hit counts over the last 100 requests" }.to_json
end

get '/cache/hit_times' do   # Metrics on hit times
    content_type 'application/json'
    hits_building = hit_times.cache.map {|t| t['time'] if t['hit'] && ! t['full']}.compact      # Accumulate relevant 
    miss_building = hit_times.cache.map {|t| t['time'] if ! t['hit'] && ! t['full']}.compact    #  values for each
    miss_full     = hit_times.cache.map {|t| t['time'] if ! t['hit'] && t['full']}.compact      #  hit and miss type

    hits_building = [0] if hits_building.empty? # Zero out if empty to compute values
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

get '/coordinate/url/:lat/:long' do # Get URL endpoint

	latitude  = params['lat'].to_f     # Convert to float
	longitude = params['long'].to_f    # Also handles the conversion of non float values

    ## Enforce coordinate values in range ##

	unless latitude.between?(-90,90) && longitude.between?(-180,180)
		return 400, "#{latitude} or #{longitude} are out of bounds (-90,90), (-180,180)"
	end

    start = Time.now

	coordinate = "#{latitude},#{longitude}"                     # Make a string key using coordinates
	cached_url = url_cache.select(coordinate)                   # Fetch a cached value if there
    cache_full = url_cache.cache.length >= 3000                 # Determine if cache is full
    k, cached_value = cached_url.first unless cached_url.nil?   # Separate the value

	if cached_url.nil?         # Need to get a fresh URL if not Chached
        hit_rates.add(0)       # Track metric for cache misses
		url = mars_trek.GetImageURL(latitude, longitude) # Get a fresh URL, String INT in this test case
		if url.nil?            # Return Errors if not found
			url_cache.add({ coordinate => 404 }) # Cache 404's to save time looking for an know bad coordinate
			return 404, "No URL Found"
		else
			url_cache.add({ coordinate => url }) # Cache the URL
		end
        runtime, cached = end_time(start), false # Track runtime metrics
	elsif cached_value == 404  # Re-return the error for a known bad coordinate
        hit_rates.add(1)
        runtime, cached = end_time(start), true
		return 404, "No URL Found"
	else
        hit_rates.add(1)
        runtime, cached = end_time(start), true
		url = cached_value     # Set the URL to the cached value
	end

    hit_times.add({'time' => runtime, 'hit' => cached, 'full' => cache_full})   # cache runtime metrics

	url

end