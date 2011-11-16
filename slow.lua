-- MySQL Proxy script for simulating a slow server
--
-- Written by Patrick Allaert <patrickallaert@php.net>
-- Copyright © 2009-2011 Libereco Technologies
-- 
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- Requirements: the sleep command accepting a float value as parameter
-- See http://lua-users.org/wiki/SleepFunction for alternatives

-- Factor of slowness, how many times slower every requests should be
factor = 2

-- In addition to a factor of slowness you can set a fixed amount of additional
-- time every request should take (in seconds).
additionalTime = 0.1

function read_query( packet )
  if packet:byte() ~= proxy.COM_QUERY then
    return
  end
  proxy.queries:append(1, string.char(proxy.COM_QUERY) .. packet:sub(2))

  return proxy.PROXY_SEND_QUERY
end

function read_query_result (inj)
  os.execute( "sleep " .. ( ( (factor - 1) * inj.response_time / 1e6 ) + additionalTime ) )
end
