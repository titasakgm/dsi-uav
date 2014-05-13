#!/usr/local/rvm/bin/ruby
# -*- encoding : utf-8 -*-

require 'rubygems'
require 'pg'

# remove flightplan file,table
system("rm -rf /data/dsi-dev/flightplan/*.mtr")

con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
sql = "DELETE FROM flightplan"
res = con.exec(sql)

sql = "ALTER SEQUENCE flightplan_id_seq RESTART WITH 1"
res = con.exec(sql)

sql = "DELETE FROM flightgps"
res = con.exec(sql)

# remove kml
system("rm -rf /data/dsi-dev/kml/2014*.kml")

# remove flightplan
system("rm -rf /data/dsi-dev/flightplan/2014*")
