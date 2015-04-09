#!/usr/bin/env ruby
#
# ABSTRACT:
#
$: << '.'
require 'alarm'
require 'gps'

gps = Smacht::GPS.new
alarms = Smacht::Alarm.new
p gps
p alarms
gps.load_all
