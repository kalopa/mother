#!/usr/local/bin/ruby
#
# Copyright (c) 2014, Kalopa Research.  All rights reserved.  This is free
# software; you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation;
# either version 2, or (at your option) any later version.
#
# It is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this product; see the file COPYING.  If not, write to the Free
# Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
#
# THIS SOFTWARE IS PROVIDED BY KALOPA RESEARCH "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL KALOPA RESEARCH BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ABSTRACT
# This utility function will read from the GPS device one time, and set
# the system clock accordingly. It is used on the PC Engines WRAP, ALIX
# and APU boards because they don't have a real-time clock. It is called
# once during system boot, to attempt to read GPS data, parse it, extract
# the time, and set the system time. It gives up after thirty seconds.
#
require 'timeout'
require 'serialport'
require 'sgslib'

device = "/dev/ttyU0"
speed = 9600

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
      break if gps and gps.valid?
    end
  end
  puts "Time is #{gps.time.to_s}"
  %x{date #{gps.time.strftime('%Y%m%d%H%M.%S')}}
end
exit 0
