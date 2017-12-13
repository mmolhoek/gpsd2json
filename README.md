# gpsd2json
ruby client to receive JSON formatted info of the gps daemon

## Setup

Make sure you have gpsd installed and you have of course a gps connected to your device
```bash
# Install
sudo apt-get install gpsd
# Check if your gps is available
cgps
# Install the gps2json gem
gem install gps2json
```

## Usage

Start an irb session

```bash
irb
require 'gpsd2json'
gps = GPSD2JSON.new()
```

Set the callbacks on the position and satellite change events

```bash
gps.on_position_change { |pos| STDERR.puts "New position: #{pos.inpect}" }
gps.on_satellites_change { |sats| STDERR.puts "#{sats.count} found, #{sats.count{|sat| sat['used']} are used" }
```

Then, your start watching

```bash
gps.start
```

If you have the gps connected you should get the satelites callback first.
It has to connect te the deamon and the deamon has to tell te gps to start
dumping the data if it did not do so already, but this should be all done
withing a second or so.

To get position change callbacks, the gps should have enough sattelites with
a fix and the speed should be higher then the minimum speed, which defaults to 0.


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
it also have a code coverage dir for you to see if your test set is above 95%

send me PR if you want changes, but only dare to do so when you added the proper tests
