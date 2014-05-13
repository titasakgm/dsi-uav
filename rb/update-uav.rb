#!/usr/local/rvm/bin/ruby
# -*- encoding : utf-8 -*-

require 'cgi'
require 'rubygems'
require 'pg'
require 'json'

c = CGI::new
id = c['id']
fdate = c['fdate']
fno = c['fno']
descr = c['description']

con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
sql = "UPDATE flightplan "
sql += "SET description='#{descr}' "
sql += "WHERE id='#{id}' "
res = con.exec(sql)
con.close

return_data = Hash.new
return_data[:success] = true

print <<EOF
Content-type: application/json

#{return_data.to_json}
EOF


