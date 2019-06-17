#! /usr/bin/env ruby

class LRUdata

public

    attr_reader :cache

	def initialize(size: 0)
		@size 	= size         # Size to fix the cache too
		@cache 	= []           # Cache Array to maintain order 
	end

	def add(element)
        ## Maintain a Fixed LRU cache ##
		@cache.shift((@cache.length - @size) + 1) if @cache.length >= @size   # Shift values off the top to keep size
		@cache.push(element)                                                  # Add to the bottom of the array
	end

    def select(c) 
        element = @cache.select {|h| h.first[0] == c }  # Find the Element Hash with a Key that Matches
        if element.empty?
            element = nil                               # Return nil it no cache element found
        else
            element = element.first                     # Extract element from Array
        end
        move(element) unless element.nil?               # Move the Element back to the bottom
        element
    end

private

    ## Delete the Element from its present position and add it back to the bottom of the array ##
    def move(element) add(@cache.delete(element)) end 

end
