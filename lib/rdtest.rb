#!/usr/bin/env ruby
#
$: << '.'

require 'gps'

x = SGS::GPS.load
p x
