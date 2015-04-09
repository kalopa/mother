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

##
# Routines for manipulating data in Redis.
#
require 'redis'

module Smacht
  class RedisBase
    ##
    # The base (inherited) class for dealing with Redis data for
    # the navigation system. Each model class inherits this parent,
    # and gets an update count for free.
    attr_accessor :count

    #
    # Initialize the (sub-)class variables in Redis.
    def self.setup
      cls = new
      cls.instance_variables.each do |var|
        val = cls.instance_variable_get var
        if val.kind_of? Array
          #
          # Arrays are handled separately. We instead
          # use the index to create a series of 'fooN'
          # variables.
          val.size.times do |idx|
            var_init var, val, idx
          end
        else
          var_init var, val
        end
      end
    end

    #
    # Translate an instance variable into a Redis key name.
    # This is simply the class name, a dot and the instance
    # variable. A bit of jiggery-pokery to convert the
    # instance variable into a proper name. Probably an easier
    # way to do this, but...
    def self.make_redis_name(var, idx = nil, var_name = nil)
      prefix = self.name.downcase.gsub(/^smacht::/, '')
      var_name ||= var.to_s.gsub(/^@/, '')
      if idx
        "#{prefix}.#{var_name}#{idx + 1}"
      else
        "#{prefix}.#{var_name}"
      end
    end

    #
    # Initialize a Redis variable.
    def self.var_init(var, val, idx = nil)
      $redis.setnx make_redis_name(var, idx), self.to_redis(var, val, idx)
    end

    #
    # Load the instance variables for the class.
    def self.load
      cls = new
      cls.instance_variables.each do |var|
        lval = cls.instance_variable_get var
        if lval.kind_of? Array
          #
          # It's an array - iterate and read the values.
          lval.size.times do |idx|
            idx_val = lval[idx]
            lval[idx] = from_redis var, idx_val.class, idx
          end
        elsif lval.kind_of? Location
          lval.latitude = from_redis var, Float, nil, 'latitude'
          lval.longitude = from_redis var, Float, nil, 'longitude'
        else
          lval = from_redis var, lval.class
        end
        cls.instance_variable_set var, lval
      end
      cls
    end

    #
    # Get an instance variable value from a Redis value.
    def self.from_redis(var, klass, idx = nil, var_name = nil)
      redis_name = make_redis_name var, idx, var_name
      redis_val = $redis.get redis_name
      redis_val = nil if redis_val == ""
      if redis_val
        case
        when klass == Time
          redis_val = Time.at(redis_val.to_f).gmtime
        when klass == Fixnum
          redis_val = redis_val.to_i
        when klass == Float
          redis_val = redis_val.to_f
        end
      end
      redis_val
    end

    #
    # Set a variable - convert from Ruby format to Redis format.
    # As of now, we only convert times. Floats and integers are
    # dealt with by Redis (converted to strings, unfortunately).
    def self.to_redis(var, local_val, idx = nil)
      if local_val
        local_val = local_val[idx] if idx
        if local_val.class == Time
          local_val = local_val.to_f
        end
      end
      local_val
    end

    #
    # Initialize the base class.
    def initialize
      @count = 0

      $redis = Redis.new unless $redis
    end

    #
    # Write the instance to Redis. In order to auto-increment
    # the count, we produce a Hash of keys and values. From this,
    # we then remove the count. Finally, inside a Redis "multi"
    # block, we set all the values and finally increment the count.
    def save
      #
      # Get the Hash of settable values (including count).
      var_list = {}
      self.instance_variables.each do |var|
        lval = self.instance_variable_get var
        if lval.kind_of? Array
          lval.size.times do |idx|
            var_list[self.class.make_redis_name(var, idx)] = self.class.to_redis var, lval, idx
          end
        elsif lval.kind_of? Location
          var_list[self.class.make_redis_name(var, nil, 'latitude')] = lval.latitude
          var_list[self.class.make_redis_name(var, nil, 'longitude')] = lval.longitude
        else
          var_list[self.class.make_redis_name(var)] = self.class.to_redis var, lval
        end
      end
      #
      # Remove the count (it is incremented, not set).
      count_name = self.class.make_redis_name "@count"
      var_list.delete count_name
      #
      # Inside a multi-block, set all the variables and increment
      # the count.
      $redis.multi do
        var_list.each do |key, value|
          $redis.set key, value
        end
        $redis.incr count_name
      end
      #
      # Finally, collect the new count setting.
      @count = $redis.get count_name
    end
  end
end
