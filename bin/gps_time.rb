#!/usr/bin/env ruby
#
$: << File.expand_path('../../lib', __FILE__)

require 'rubygems'
require 'serialport'
require 'nmea'
require 'gps'

serial = SerialPort.new "/dev/ttyU0", 4800

gps = nil
while true do
  nmea = SGS::NMEA.parse(serial.readline)
  if nmea and nmea.is_gprmc?
    gps = nmea.parse_gprmc
    break if gps
  end
end
%x{date #{gps.time.strftime('%Y%m%d%H%M.%S')}}
exit 0
