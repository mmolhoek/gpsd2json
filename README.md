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


You can stop watching with

```bash
gps.stop
```

There is also a on_raw_data callback you can use to see all data that is dumped by the deamon

```bash
gps.on_raw_data { |json| STDERR.puts json.inspect}
```

You can change the minimum speed requered to return a position change, with

```bash
gps.change_min_speed(speed: <whatever speed>)
```

## Development

```bash
# Install
git clone git@github.com:mmolhoek/gpsd2json.git
cd gpsd2json
bundle
# irb
bundle exec irb -r ./lib/gpsd2json.rb
# test (with coverage to ./coverage/index.html)
bundle exec rspec --color -fd spec/gpsd_client_test.rb
```

Send me PR if you want changes, but only dare to do so when you added the proper tests and the overall coverage stays above 95%
