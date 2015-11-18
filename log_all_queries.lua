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

logfile="/var/log/mysql-proxy/querydebug.log"
transaction_counter = 0
output_header=0
function read_query( packet )
    if packet:byte() ~= proxy.COM_QUERY then
        return
    end
    proxy.queries:append(1, string.char(proxy.COM_QUERY) .. packet:sub(2), {resultset_is_needed = true}) 

    return proxy.PROXY_SEND_QUERY
end

function read_query_result (inj)
  local res = assert(inj.resultset)
  local error_status = ""
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

  --
  --  local i = 0
  -- while i < transaction_counter do
  --   io.write("    ")
  --   i = i +1
  -- end

  if string.upper(string.sub(query,1,5)) == "BEGIN" then
    transaction_counter = transaction_counter + 1
  end
  
  logfd:write(
    string.format(
      "%d\t%s\t%s\t%x\t%s\t%d\t%s:%s:%s\t%d\t%fms\t%s\n", 
      os.time(),
      proxy.connection.client.username,
      proxy.connection.client.default_db,
      res.query_status,
      error_status,
      res.warning_count,
      	tostring(res.flags.in_trans),
	tostring(res.flags.no_index_used),
	tostring(res.flags.no_good_index_used),
      row_count,
      inj.response_time / 1e3,
      query
    )
  )
end

function print_header(fd)
  fd:write("# time\tusername\tdbname\tquery-status(hex)\terror-status(str)\twarning-count\tin_trans(b):no-index-used(b):no-good-index-used(b)\trow-count\tresponse-time(ms)\tquery\n")
end

--
-- Init code
-- 
if not io.open(logfile,"r") then
	output_header=1
end

logfd=assert(io.open(logfile,"a"))
if output_header then
	print_header(logfd)
end


