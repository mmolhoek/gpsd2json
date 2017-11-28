# gpsd2json
ruby client to receive JSON formatted info of the gps daemon

# usage
```bash
#start irb session
irb
require 'gpsd2json'
gps = GPSD2JSON.new()
# set callback if any data is received
gps.on_raw_data { |json| STDERR.puts json.inspect}
# or if you want to make it easy on yourself
gps.on_position_change { |pos| STDERR.puts pos.inpect }
gps.on_satellites_change { |sats| STDERR.puts "#{sats.count} found, #{sats.count{|sat| sat['used']} are used" }
#start watching
gps.start
# stop watching
gps.stop
```

# development
```bash
#install
bundle
#irb
bundle exec irb -r ./lib/gpsd2json.rb
```
