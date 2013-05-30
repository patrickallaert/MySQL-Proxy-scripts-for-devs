-- MySQL Proxy script for development/debugging purposes
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

use_sql_no_cache = 0

function nocache(query)
    local word = string.upper(string.sub(query,1,6))
    if ( word == "SELECT" ) then
        query = "SELECT SQL_NO_CACHE" .. query:sub(7)
    end
    return query
end

transaction_counter = 0

function read_query( packet )
    if packet:byte() ~= proxy.COM_QUERY then
        return
    end
    local query = packet:sub(2)
    if ( use_sql_no_cache == 1 ) then
        query = nocache(query)
    end    
    proxy.queries:append(1, string.char(proxy.COM_QUERY) .. query, {resultset_is_needed = true}) 

    return proxy.PROXY_SEND_QUERY
end

function read_query_result (inj)
  local res = assert(inj.resultset)
  local error_status = ""
  if res.flags.no_good_index_used then
    error_status = error_status .. "No good index used!"
  end
  if res.flags.no_index_used then
    error_status = error_status .. "No index used!"
  end
  local row_count = 0
  if res.affected_rows then
    row_count = res.affected_rows
  else
    local num_cols = string.byte(res.raw, 1)
    if num_cols > 0 and num_cols < 255 then
      for row in inj.resultset.rows do
        row_count = row_count + 1
      end
    end
  end
  if res.query_status == proxy.MYSQLD_PACKET_ERR then
    error_status = string.format("%q", res.raw:sub(10)) 
  end
  local query = string.gsub(string.sub(inj.query, 2), "%s+", " ")
  local word = string.upper(string.sub(query,1,6))
  if word == "COMMIT" then
    transaction_counter = transaction_counter - 1
  end

  local i = 0
  while i < transaction_counter do
    io.write("    ")
    i = i +1
  end

  if string.upper(string.sub(query,1,5)) == "BEGIN" then
    transaction_counter = transaction_counter + 1
  end
  
  print(
    string.format(
      "%s\t%s\t%s\t%fms", 
      query,
      error_status,
      row_count == 0 and "<NONE>" or row_count,
      inj.response_time / 1e3
    )
  )
end
