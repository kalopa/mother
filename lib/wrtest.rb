#!/usr/bin/env ruby
#
$: << '.'

require 'gps'

loop do
  x = Smacht::GPS.new
  x.time = Time.now
  x.location.latitude_degrees = 53.26066666
  x.location.longitude_degrees = -9.03083333
  x.save
  sleep 1
end
