#!/usr/bin/env ruby
#
$: << '.'

require 'gps'

x = Smacht::GPS.load
p x
