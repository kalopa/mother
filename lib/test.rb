#!/usr/bin/env ruby
#
# ABSTRACT:
#
$: << '.'
require 'alarm'
require 'gps'

gps = SGS::GPS.new
alarms = SGS::Alarm.new
p gps
p alarms
gps.load_all
