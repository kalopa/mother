#
# ABSTRACT:
#
require 'redis_base'
require 'location'

module Smacht
  class GPS < RedisBase
    attr_accessor :time, :location, :sog, :cmg, :magvar, :count, :valid

    def initialize
      @time = Time.now.getgm
      @location = Location.new
      @sog = 0.0
      @cmg = 0.0
      @magvar = nil
      @count = 0
      @valid = false
      super
    end
  end
end
