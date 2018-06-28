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
# This utility daemon handles all communication between the low-level
# Atmel board ("Otto Von Helm") and the upper-level systems. Any component
# which needs to interact with the low-level hardware does so using this
# daemon. Alarms are also processed herein. It will periodically check
# for various state updates, as well.
#
require 'serialport'
require 'sgslib'

config = SGS::Config.load

sp = SerialPort.new config.otto_device, config.otto_speed

#
# First off, get the device into comms mode. This is done by sending CQ
# messages until Otto responds appropriately.
initted = false
sp.read_timeout = 2000
while not initted do
  begin
    puts "Send CQ...\n"
    sp.write "__CQ!\n"
    puts "Receive response...\n"
    response = sp.readline.chomp
    puts "Received: #{response}"
    if response =~ /^__OK!$/
      initted = true
      break
    end
    sleep 5
  rescue EOFError => error
    puts "Timed out!"
    sleep 5
    retry
  end
  puts "Wait...\n"
  sleep 5
end

#
# Now listen for Redis PUB/SUB requests and act on each one.
puts "Starting OTTO service...\n"
sp.read_timeout = 30000
begin
  SGS::RedisBase.redis.subscribe(:otto) do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
    end

    on.message do |channel, message|
      puts "##{channel}: #{message}"
    end

    on.unsubscribe do |channel, subscriptions|
      puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
    end
  end
rescue Redis::BaseConnectionError => error
  puts "#{error}, retrying in 1s"
  sleep 1
  retry
end
exit 0
