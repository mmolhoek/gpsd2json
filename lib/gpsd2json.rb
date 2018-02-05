require 'socket'
require 'json'
require 'date'
class GPSD2JSON
    VERBOSE = false
    # A simple gpsd client that dump's json objects contianing all info received from the gpsd deamon
    # you need to at least setup either the raw callback (on_raw_change) or position callback (on_position_change) to use GPSD2JSON. the raw callback just passes the json objects it received from the daemon on to the block you pass it. the on_position_change and on_satellites_change are a bit easier to use.
    # @example Easy setup
    # gps = GPSD2JSON.new()
    # gps.on_satellites_change { |sats| STDERR.puts "found #{sats.length} satellites, of which #{sats.count{|sat| sat['used']} } active" }
    # gps.on_position_change { |pos| STDERR.puts "lat: #{pos['lat']}, lng: #{pos['lon']}, alt: #{pos['alt']}, speed: #{pos['speed']} at #{pos['time']}, which is #{(Time.now - pos['time'].to_time) * 1000}ms old" }
    # gps.start
    # #when done
    # gps.stop
    # @example Quickest raw mode, just dumping all json packets as the are
    # gps = GPSD2JSON.new()
    # gps.on_raw_change { |raw| STDERR.puts raw.inspect }
    # gps.start
    # #when done
    # gps.stop
    def initialize(host: 'localhost', port: 2947)
        @socket = nil
        @socket_ready = false
        @host = host
        @port = port
        @trackthread = nil
        @socket_init_thread = nil
        @min_speed = 0 # speed needs to be higher than this to make the gps info count
        @last = nil #last gps info
        @sats = nil # last satellites info
        @json_raw_callback = nil
        @json_pos_callback = nil
        @json_sat_callback = nil
    end

    # @param [Object] options Possible options to pass (not used yet)
    # @param [Block] block Block to call when new json object comes from gpsd
    def on_raw_change(options:{}, &block)
        @json_raw_callback = block
    end

    # @param [Object] options Possible options to pass (not used yet)
    # @param [Block] block Block to call when new gps position json object comes from gpsd
    def on_position_change(options:{}, &block)
        @json_pos_callback = block
    end

    # @param [Object] options Possible options to pass (not used yet)
    # @param [Block] block Block to call when new satellite info json object comes from gpsd
    def on_satellites_change(options:{}, &block)
        @json_sat_callback = block
    end

    # @param [Float] speed The minimum speed to accept a gps update
    def change_min_speed(speed:)
        @min_speed = speed
    end

    # Open the socket and when ready request the position flow from the gps daemon
    def start
        # background thread that is used to open the socket and wait for it to be ready
        @socket_init_thread = Thread.start do
            #open the socket
            while not @socket_ready
                init_socket
                #wait for it to be ready
                sleep 0.1
            end
            # it's ready, tell it to start watching and passing
            puts "socket ready, start watching" if VERBOSE
            @socket.puts '?WATCH={"enable":true,"json":true}'
        end

        # background thead that is used to read info from the socket and use it
        @trackthread = Thread.start do
            while true do
                begin
                    read_from_socket
                rescue
                    "error while reading socket: #{$!}" if VERBOSE
                end
            end
        end
    end

    # @return [string] status info string containing nr satellites, fix, speed
    def to_status
        return "lat: #{last['lat']}, lng: #{last['lon']}, speed:#{last['speed']}, sats: #{@sats.length}(#{@sats.count{|sat| sat['used']}})" if @socket_ready and @last and @sats
        return "lat: #{last['lat']}, lng: #{last['lon']}, speed:#{last['speed']}" if @socket_ready and @last and @sats.nil?
        return "sats: #{@sats.length}(#{@sats.count{|sat| sat['used']}}), no fix yet" if @socket_ready and @last.nil? and @sats
        return "connected with gpsd, waiting for data" if @socket_ready
        return "waiting for connection with gpsd" if @socket_ready == false
    end

    # Stop the listening loop and close the socket. It will read the last bit of data from the socket, close it, and clean it up
    def stop
        # last read(s)
        3.times { read_from_socket }
        # then close
        close_socket
        # then cleanup
        Thread.kill(@socket_init_thread) if @socket_init_thread
        Thread.kill(@trackthread) if @trackthread
        @socket_ready = false
    end

    # initialize gpsd socket
    def init_socket
        begin
            puts "init_socket" if VERBOSE
            close_socket if @socket
            @socket = TCPSocket.new(@host, @port)
            @socket.puts("w+")
            puts "reading socket..." if VERBOSE
            welkom = ::JSON.parse(@socket.gets)
            puts "welkom: #{welkom.inspect}" if VERBOSE
            @socket_ready = (welkom and welkom['class'] and welkom['class'] == 'VERSION')
            puts "@socket_ready: #{@socket_ready.inspect}" if VERBOSE
        rescue
            @socket_ready = false
            puts "#$!" if VERBOSE
        end
    end

    # Read from socket. this should happen in a Thread as a continues loop. It should try to read data from the socket but nothing might happen if the gps deamon might not be ready. If ready it will send packets that we read and proces
    def read_from_socket
        if @socket_ready
            begin
                if input = @socket.gets.chomp and not input.to_s.empty?
                    parse_socket_json(json: JSON.parse(input))
                else
                    sleep 0.1
                end
            rescue
                puts "error reading from socket: #{$!}" if VERBOSE
            end
        else
            sleep 0.1
        end
    end

    # Proceses json object returned by gpsd daemon. The TPV and SKY object
    # are used the most as they give info about satellites used and gps locations
    # @param [JSON] json The object returned by the daemon
    def parse_socket_json(json:)
        case json['class']
        when 'DEVICE', 'DEVICES'
            # devices that are found, not needed
        when 'WATCH'
            # gps deamon is ready and will send other packets, not needed yet
        when 'TPV'
            # gps position
            #  "tag"=>"RMC", #  "device"=>"/dev/ttyS0", #  "mode"=>3,
            #  "time"=>"2017-11-28T12:54:54.000Z", #  "ept"=>0.005, #  "lat"=>52.368576667,
            #  "lon"=>4.901715, #  "alt"=>-6.2, #  "epx"=>2.738, #  "epy"=>3.5,
            #  "epv"=>5.06, #  "track"=>198.53, #  "speed"=>0.19, #  "climb"=>0.0,
            #  "eps"=>7.0, #  "epc"=>10.12
            if json['mode'] > 1
               #we have a 2d or 3d fix
                if is_new_measurement(json: json)
                    json['time'] = DateTime.parse(json['time'])
                    puts "lat: #{json['lat']}, lng: #{json['lon']}, alt: #{json['alt']}, speed: #{json['speed']} at #{json['time']}, which is #{(Time.now - json['time'].to_time) * 1000}ms old" if VERBOSE
                    @json_pos_callback.call(json) if @json_pos_callback
                end
            end
        when 'SKY'
            # report on found satellites
            sats = json['satellites']
            if satellites_changed(sats: sats)
                puts "found #{sats.length} satellites, of which #{sats.count{|sat| sat['used']}} are used" if VERBOSE
                @json_sat_callback.call(sats) if @json_sat_callback
            end
        else
            puts "hey...found unknow tag: #{json.inspect}" if VERBOSE
        end
        @json_raw_callback.call(json) if @json_raw_callback
    end

    # checks if the new satellites object return by the deamon is different enough compared
    # to the last one, to use it
    def satellites_changed(sats:)
        if @sats.nil? or (@sats.length != sats.length or @sats.count{|sat| sat['used']} != sats.count{|sat| sat['used']})
            @sats = sats
            return true
        end
        return false
    end

    # checks if the new location object return by the deamon is different enough compared
    # to the last one, to use it. it could be disregarded for example because the speed is to low, and you don't want to have the location jumping around when you stand still
    def is_new_measurement(json:)
        if @last.nil? or (@last['lat'] != json['lat'] and @last['lon'] != json['lon'] and json['speed'] >= @min_speed)
            @last = json
            return true
        end
        return false
    end

    # Close the gps deamon socket
    def close_socket
        begin
            if @socket
                @socket.puts '?WATCH={"enable":false}'
                @socket.close
            end
            @socket = nil
        rescue
            puts "#$!" if VERBOSE
        end
    end
end
