require File.dirname(__FILE__) + '/spec_helper.rb'
class GPSD2JSON
    VERBOSE = true
    # we need to access the init tread to wait for it to finish, before we continue the test
    attr_reader :socket_init_thread
    # we open these up just for the test
    attr_reader :host, :port
end
gps = nil
socket = nil
describe GPSD2JSON do
    before(:each) do
        gps = GPSD2JSON.new() # use the library
        socket = FakeSocket.new # but, fake the socket
        allow(TCPSocket).to receive(:new).and_return(socket)
        socket.nextResponse(response: %{{"class": "VERSION"}}) #that how the socket says 'hi'
    end
    it "it should start with default settings" do
        expect(gps.host).to eq('localhost')
        expect(gps.port).to eq(2947)
    end
    it "it waits for connection with on init" do
        expect(gps.to_status).to eq('waiting for connection with gpsd')
    end
    it "connects to GPS daemon socket, on start" do
        gps.start
        gps.socket_init_thread.join # wait for thread to be ready
        expect(socket.last_received_message).to eq('?WATCH={"enable":true,"json":true}')
        expect(gps.to_status).to eq('connected with gpsd, waiting for data')
    end
    it "receives raw json using the on_raw_change callback" do
        gps.start
        gps.socket_init_thread.join # wait for thread to be ready
        gps.on_position_change { |pos|
            expect(pos["lat"]).to eq('should not come here')
        }
        gps.on_raw_change { |json|
            expect(json["some"]).to eq("thing")
        }
        socket.nextResponse(response: %{{"class":"DEVICES","some":"thing"}})
        gps.stop
    end
    it "catches unknown tags" do
        gps.start
        gps.socket_init_thread.join # wait for thread to be ready
        gps.on_position_change { |pos|
            expect(pos["lat"]).to eq('should not come here')
        }
        gps.on_raw_change { |data|
            expect(data["some"]).to eq('thing')
        }
        socket.nextResponse(response: %{{"class":"MISCHA","some":"thing"}})
        gps.stop
    end
    it "receives a gps position using the on_position_change callback" do
        gps.start
        gps.socket_init_thread.join # wait for thread to be ready
        gps.on_position_change { |pos|
            expect(pos["lat"]).to eq(23.34323)
            expect(pos["lng"]).to eq(10.12345)
            expect(pos["speed"]).to eq(50)
            expect(pos["mode"]).to eq(2)
        }
        socket.nextResponse(response: %{{"class":"TPV","mode":2,"time":"2017-12-04T12:54:54.000Z","lat":23.34323,"lng":10.12345,"alt":10.5,"speed":50}})
        # twice to also test false handle
        socket.nextResponse(response: %{{"class":"TPV","mode":2,"time":"2017-12-04T12:54:54.000Z","lat":23.34323,"lng":10.12345,"alt":10.5,"speed":50}})
        gps.stop
    end
    it "receives blocks positions that have a to low speed" do
        gps.start
        gps.socket_init_thread.join # wait for thread to be ready
        gps.on_position_change { |pos|
            expect(pos["lat"]).to eq(23.34323)
            expect(pos["lng"]).to eq(10.12345)
            expect(pos["speed"]).to eq(5)
            expect(pos["mode"]).to eq(2)
        }
        # twice to also test false handle
        gps.change_min_speed(speed: 5)
        socket.nextResponse(response: %{{"class":"TPV","mode":2,"time":"2017-12-04T12:54:54.000Z","lat":24.34323,"lng":11.12345,"alt":10.5,"speed":1}})
        socket.nextResponse(response: %{{"class":"TPV","mode":2,"time":"2017-12-04T12:54:54.000Z","lat":23.34323,"lng":10.12345,"alt":10.5,"speed":5}})
        gps.stop
    end
    it "receives satellite changes the on_satellites_change callback" do
        gps.start
        gps.socket_init_thread.join # wait for thread to be ready
        gps.on_position_change { |pos|
            expect(pos["lat"]).to eq('should not come here')
        }
        gps.on_satellites_change { |sats|
            expect(sats.length).to eq(2)
            expect(sats.count{|sat| sat['used']}).to eq(1)
        }
        socket.nextResponse(response: %{{"class":"SKY","satellites":[{"used": true},{"used":false}]}})
        socket.nextResponse(response: %{{"class":"SKY","satellites":[{"used": true},{"used":false}]}})
        gps.stop
    end
end
