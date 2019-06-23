#! /usr/bin/env ruby

require 'socket'

    ## Graphite Class to send metrics to a viewable platform ##

class Graphite

    def initialize(host, port) 
        @connection = TCPSocket::new(host, port)
    end

    def send(metric, value, time) 
        @connection.puts("%s %s %s\n" % [metric, value, time])
    end

    def close() @connection.close end

end

    ## Metrics class to handle gathering ans sending metrics ##

class Metrics

    def initialize(graphite_endpoint: nil)
        @graphite_endpoint = graphite_endpoint
        @current = Hash.new {|h, key| h[key] = []}
        @recent  = nil
    end

    def submit(label: nil, value: nil)     # Submit metric to Hash

        label_key = label.split('.')       # Split label into Arrays

        unless label_key.last == 'end'     # Unless marked as an End Time
            @current[label] << value.to_f     # Set value into Hash
        else
            start_key = (label_key[0..-2] + ['start']).join('.')          # Render Start Key for Time
            @current[label_key[0..-2]] << ( value - @current[start_key] ) # Set Runtime from Start & End Diff
            @current.delete(start_key)                                    # Delete the Start time
        end
        
    end

    def start(label: nil) submit(label: (label + '.start'), value: Time.now) end    # Mark Start Time
    def end(label: nil)   submit(label: (label + '.end'),   value: Time.now) end    # Mark End Time, Triggers Set Runtime

    def shift_and_reset                             # Copy to Current Metrics and Reset to keep recording
        @recent  = @current.dump                    # Copy over
        @current = Hash.new {|h, key| h[key] = []}  # Reset
    end

    def total(label: nil)   @recent[label].inject(0){|sum,x| sum + x }.to_f.truncate(5) end     # Calculate Total
    def average(label: nil) (total(label) / @recent[label].length.to_f).truncate(5)     end     # Calculate Average

    def dump        # Render Hash of Metrics
        dump = {}

        def branch_array_to_hash(key_array)     # Render nested Hash from Array of Keys
            array = key_array.dup               # Separate Array from passed in object
            { array.shift => array.empty? ? nil : branch_array_to_hash(array) }     # Recursive Hash Build
        end

        ['total','average'].each do |function|  # Set Total and Average values for Each Metrics
            @recent.each do |k,v|               # For each Recorded Metrics
                key   = k + '_' + function      # Create Key for intended Metric
                value = eval("#{function}(k)")  # Meta-Programming to get Intended Value
                key_path = key.split('.'); key_path.shift   # Key path to Array, minus first key

                root_hash = dump.dig(*key_path[0..-2])      # Check for Existing Key Path

                if root_hash.nil?                           # If the Path didn't exist
                    dump = branch_array_to_hash(key_path)       # Create it
                    root_hash = dump.dig(*key_path[0..-2])  # Get know path pointer
                end

                root_hash[key_path.last] = value            # Set Value

            end
        end

        dump
    end

    def send_to_graphite        # Method to send all metrics to graphite
        unless @graphite_endpoint.nil?      # Don't try unless a connection path was provided
            send_time = Time.now.to_i       # Set all metrics to current time
            graphite  = Graphite.new(@graphite_endpoint, 2003)      # Make Connection

            shift_and_reset     # Move Current Metrics over for use
            ['total','average'].each do |function|
                @recent.each do |k,v| 
                    key   = k + '_' + function
                    value = eval("#{function}(k)")
                    graphite.send(key, value, send_time)
                end
            end

            graphite.close

        end
    end

end