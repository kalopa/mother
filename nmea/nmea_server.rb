#!/usr/bin/env ruby
#
# Copyright (c) 2013, Kalopa Research.  All rights reserved.  This is free
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
$: << '../sgslib'

require 'socket'
require 'daemons'
require 'nmea'
require 'gps'

client_list = []

Daemons.run_proc('nmea_server') do
  #
  # Fire up the GPS post thread
  gps_thread = Thread.new do
    old_count = 0
    SGS::GPS.subscribe do |count|
      if count > old_count
        old_count = count
        gps = SGS::GPS.load
        nmea = SGS::NMEA.new
        nmea.make_gprmc(gps)
        client_list.each do |client|
          begin
            client.puts nmea
          rescue Errno::EPIPE
            client_list.delete client
          end
        end
      end
    end
  end
  gps_thread.abort_on_exception = true
  #
  # Now start listening for clients
  server_thread = Thread.new do
    server = TCPServer.new 5000
    loop do
      client = server.accept
      client_list << client
    end
  end
  #
  # Now wait for exceptions.
  server_thread.join
  gps_thread.join
end
