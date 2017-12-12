# gpsd2json
ruby client to receive JSON formatted info of the gps daemon

## initialization
```bash
require 'gpsd2json'
gps = GPSD2JSON.new()
```
## First you set some callbacks on the most important changes
```bash
gps.on_position_change { |pos| STDERR.puts pos.inpect }
gps.on_satellites_change { |sats| STDERR.puts "#{sats.count} found, #{sats.count{|sat| sat['used']} are used" }
```
## Then, your start watching
```bash
gps.start
```
after this, the positions will be given to the callback block

## When you had enough, you can stop watching
```bash
gps.stop
```

## there is on more callback to receive all data as raw json
```bash
gps.on_raw_data { |json| STDERR.puts json.inspect}
```

## Also, you can change the minimum speed requered to return a position change, with
```bash
gps.change_min_speed(speed: <whatever speed>)
```

## development
```bash
# Install
bundle
# irb
bundle exec irb -r ./lib/gpsd2json.rb
# test
bundle exec rspec --color -fd spec/gpsd_client_test.rb
```
it also have a code coverage dir for you to see if your test set is about 95%

send me PR if you want changes, but only dare to do so when you added the proper tests
