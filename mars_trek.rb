#! /usr/bin/env ruby

# Found an API, Per the Homework instructions this will just be a stubbed out class
# https://{WMTS endpoint}/1.0.0/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.png

require 'net/http'

class MarsTrek

	def initialize
        @api_key = '98d2e03bb92ebd21704ca8c0aa0d2ba8-standin'
        @api_url = "https://%s/1.0.0/%s/%s/%s/%s/%s.png"
	end

	def GetImageURL(lat, long)
        rand(10000000..99999999).to_s   # Per stubbung instructions return an number as a string
	end

end
