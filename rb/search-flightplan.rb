#!/usr/local/rvm/bin/ruby
# -*- encoding : utf-8 -*-

require 'cgi'
require 'net/http'
require 'rubygems'
require 'json'
require 'pg'

def log(msg)
  f = open("/tmp/search-flightplan.log","a")
  f.write(msg)
  f.write("\n")
  f.close
end

def search_flightplan(q)
  con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
  sql = "SELECT id,flightdate,flightno,description,"
  sql += "center(the_geom) as center FROM flightplan "
  sql += "WHERE flightdate || description LIKE '%#{q}%' "
  sql += "ORDER BY flightdate,flightno,id "
  log("search-flightplan: #{sql}")
  res = con.exec(sql)
  con.close

  found = res.num_tuples
  records = []

  if found > 0
    res.each do |rec|
      id = rec['id']
      fd = rec['flightdate'].strip
      no = rec['flightno'].strip
      desc = rec['description'].strip
      latlng = rec['center'].tr('()','').split(',');
      center = latlng[1] + ',' + latlng[0];
      kml = "kml/#{fd}-#{no}.kml"
      dat = {
              :id => "#{id}",
              :flightdate => "#{fd}",
              :flightno => "#{no}",
              :description => "#{desc}",
              :center => "#{center}", # this is LonLat order
              :kmlname => "#{kml}" }
      records.push(dat)
    end
  end
  records
end

c = CGI::new
query = c['query']
start = c['start'].to_i
limit = c['limit'].to_i

if start == 0
  limit = 5
end

data = search_flightplan(query)

print <<EOF
Content-type: application/json

#{data.to_json}
EOF
