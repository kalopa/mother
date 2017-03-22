#!/usr/bin/env ruby
#
$: << '../sgslib'

require 'rubygems'
require 'timeout'
require 'serialport'
require 'nmea'
require 'gps'

device = "/dev/ttyU0"
speed = 4800

if ARGV.count > 0
  device = ARGV[0]
  if ARGV.count > 1
    speed = ARGV[1].to_i
  end
end

serial = SerialPort.new device, serial

gps = nil
status = Timeout::timeout(30) do
  while true do
    nmea = SGS::NMEA.parse(serial.readline)
    if nmea and nmea.is_gprmc?
      gps = nmea.parse_gprmc
      break if gps
    end
  end
  %x{date #{gps.time.strftime('%Y%m%d%H%M.%S')}}
end
exit 0
