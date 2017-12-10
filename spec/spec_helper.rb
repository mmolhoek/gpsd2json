$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'simplecov'
SimpleCov.start

require 'rspec'
#require 'rspec/mocks'

require 'gps2json'
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
class FakeSocket
    attr_accessor :next_response, :host, :port, :last_received_message
    def initialize
        @next_response = []
        @last_received_message = nil
    end

    def nextResponse(response:)
        @next_response << response
    end

    def puts(param)
        @last_received_message = param
        return true
    end

    def gets
        return @next_response.pop || ''
    end
    def close
        return true
    end
end

