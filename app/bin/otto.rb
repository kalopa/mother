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
require 'msgpack'
require 'sgslib'

class Otto
  #
  # Set up the serial port
  def initialize
    @config = SGS::Config.load
    @sp = SerialPort.new @config.otto_device, @config.otto_speed
    set_timeout
  end

  #
  # Set the serial port timeout for reads.
  def set_timeout(val = 2000)
    @sp.read_timeout = val
  end

  #
  # Synchronize with the low-level code. Because the system console
  # will spew a lot of crap during startup, Otto will ignore all
  # serial I/O until it sees a CQ sequence.
  def synchronize
    initted = false
    while not initted do
      resp = command "__CQ!"
      if resp =~ /^\+CQOK/ or resp =~ /^\+OK/
        initted = true
        break
      end
      sleep 5
    end
  end

  #
  # Send a command to Otto and wait for a response.
  def command(str)
    puts "> Sending command: #{str}"
    @sp.write "#{str}\n"
    begin
      response = @sp.readline.chomp
    rescue EOFError => error
      puts "Command timed out."
      response = "-TMO"
    end
    puts "< Response: #{response}"
    response
  end
end

otto = Otto.new
puts "Synchronize with the low-level board."
otto.synchronize
puts "Starting OTTO service..."

#
# Now listen for Redis PUB/SUB requests and act on each one.
otto.set_timeout 30000
while true
  channel, request = SGS::RedisBase.redis.brpop("otto")
  request = MessagePack.unpack(request)
  id = request['id']

  args = request['params'].unshift(request['method'])
  result = otto.send *args

  reply = {
    'id' => id,
    'jsonrpc' => '2.0',
    'result' => result
  }

  SGS::RedisBase.redis.rpush(id, MessagePack.pack(reply))
  SGS::RedisBase.redis.expire(id, 30)
end
exit 0
