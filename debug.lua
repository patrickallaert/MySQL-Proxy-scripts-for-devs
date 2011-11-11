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

transaction_counter = 0

function read_query( packet )
    if packet:byte() ~= proxy.COM_QUERY then
        return
    end
    proxy.queries:append(1, string.char(proxy.COM_QUERY) .. packet:sub(2), {resultset_is_needed = true}) 

    return proxy.PROXY_SEND_QUERY
end

function read_query_result (inj)
  local row_count = 0
  local res = assert(inj.resultset)
  local num_cols = string.byte(res.raw, 1)
  local error_status = ""
  local color = ""
  local query = ""
  if res.flags.no_good_index_used then
    error_status = error_status .. "No good index used!"
    color = "\27[33m"
  end
  if res.flags.no_index_used then
    error_status = error_status .. "No index used!"
    color = "\27[1;33m"
  end
  if res.affected_rows then
    row_count = res.affected_rows
  else
    if num_cols > 0 and num_cols < 255 then
      for row in inj.resultset.rows do
        row_count = row_count + 1
      end
    end
  end
  if row_count == 0 then
    color = "\27[1;36m"
  end
  if res.query_status == proxy.MYSQLD_PACKET_ERR then
    error_status = string.format("%q", res.raw:sub(10)) 
    color = "\27[1;31m"
  end
  query = string.gsub(string.sub(inj.query, 2), "%s+", " ")
  if string.upper(string.sub(query,1,6)) == "UPDATE" then
    color = "\27[45m"
  end
  if string.upper(string.sub(query,1,6)) == "DELETE" then
    color = "\27[45m"
  end
  if string.upper(string.sub(query,1,6)) == "INSERT" then
    color = "\27[45m"
  end

  if string.upper(string.sub(query,1,6)) == "COMMIT" then
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
      "%s%s\t%s\t\27[0m%d\t%s%fms\27[0m", 
      color,
      query,
      error_status,
      row_count,
      inj.response_time > 1e5 and "\27[1;31m" or "\27[32m",
      inj.response_time / 1e3
    )
  )
end
