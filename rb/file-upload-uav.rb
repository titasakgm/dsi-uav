#!/usr/local/rvm/bin/ruby
# -*- encoding : utf-8 -*-

require 'cgi'
require 'rubygems'
require 'json'
require 'pg'

def log(str)
  l = open("/tmp/file-upload-uav.log","a")
  l.write("#{str}\n")
  l.close
end

def save_flightplan(fdate,fno,vehicle,descr)
  con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
  sql = "INSERT INTO flightplan (flightdate,flightno,vehicle,description) "
  sql += "VALUES ('#{fdate}','#{fno}','#{vehicle}','#{descr}')"
  log("INSERT: #{sql}")
  res = con.exec(sql)

  # get all lat/lng ORDER BY id of this fdate,fno
  sql = "SELECT latitude,longitude "
  sql += "FROM flightgps "
  sql += "WHERE flightdate='#{fdate}' AND flightno='#{fno}' "
  sql += "ORDER BY id"
  log("SELECT: #{sql}")
  res = con.exec(sql)

  linestr = ""
  res.each do |rec|
    lat = rec['latitude']
    lng = rec['longitude']
    if linestr == ""
      linestr = "#{lat} #{lng}"
    else
      linestr = "#{linestr},#{lat} #{lng}"
    end
  end

  # update the_geom with LINESTRING
  sql = "UPDATE flightplan "
  sql += "SET the_geom = GeometryFromText('LINESTRING(#{linestr})',4326) "
  sql += "WHERE flightdate='#{fdate}' AND flightno='#{fno}' "
  log("UPDATE: #{sql}")
  res = con.exec(sql)
  con.close
end

def save_multi_rotor(f)
  con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
  sql = "INSERT INTO flightgps VALUES("
  sql += "'#{f[0]}','#{f[1]}','#{f[2]}','#{f[3]}','#{f[4]}',"
  sql += "'#{f[5]}','#{f[6]}','#{f[7]}','#{f[8]}','#{f[9]}',"
  sql += "'#{f[10]}','#{f[11]}','#{f[12]}','#{f[13]}','#{f[14]}')"
  log("INSERT: #{sql}")
  res = con.exec(sql)
  con.close
end

def save_fixed_wing(f)
  con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
  sql = "INSERT INTO flightgps (flightdate,flightno,id,latitude,"
  sql += "longitude,altitude) VALUES ('#{f[0]}','#{f[1]}','#{f[2]}',"
  sql += "'#{f[3]}','#{f[4]}','#{f[5]}') "
  log("INSERT-fixed-wing: #{sql}")
  res = con.exec(sql)
  con.close
end

# process Fixed-Wing .txt OR XML (Multi-Rotor .awm)
# in /data/dsi-uav/flightplan
def process_flightplan(server_file)
  filename = server_file.split('/').last
  fdate = filename[0..7]
  fno = filename[9..10]
  vehicle = (filename.downcase =~ /txt/) ? 'FIXED-WING' : 'MULTI-ROTOR'
  src = open(server_file).readlines

  if vehicle == 'MULTI-ROTOR'
    f = [fdate,fno]
    start = false
    src.each do |line|
      d = line.chomp.gsub(/<.+?>/,'').strip
      if line =~ /WayPoint id/
        id = line.chomp.split(/\"/)[1]
        f[2] = id
        start = true
      elsif line =~ /\<\/WayPoint/
        save_multi_rotor(f)
        f = [fdate,fno]
        start = false
        next
      end

      next if !start

      if line =~ /Latitude/
        f[3] = d
      elsif line =~ /Longitude/
        f[4] = d
      elsif line =~ /Altitude/
        f[5] = d
      elsif line =~ /Speed/
        f[6] = d
      elsif line =~ /TimeLimit/
        f[7] = d
      elsif line =~ /YawDegree/
        f[8] = d
      elsif line =~ /HoldTime/
        f[9] = d
      elsif line =~ /StartDelay/
        f[10] = d
      elsif line =~ /Period/
        f[11] = d
      elsif line =~ /RepeatTime/
        f[12] = d
      elsif line =~ /RepeatDistance/
        f[13] = d
      elsif line =~ /TurnMode/
        f[14] = d
      end
    end
  else # FIXED-WING
    f = [fdate,fno]
    src.each do |line|
      d = line.chomp.split(/\t/)
      next if d[0] !~ /^\d/ # line dows not START with DIGIT [0-9]
      f[2] = d[0]  # id
      f[3] = d[8]  # latitude
      f[4] = d[9]  # longitude
      f[5] = d[10] # altitude
      save_fixed_wing(f)
      f = [fdate,fno]
    end
  end
  descr = ' '
  save_flightplan(fdate,fno,vehicle,descr)
end

# generate KML to /data/dsi-uav/kml
def generate_kml(fdate,fno)
  con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
  sql = "SELECT longitude,latitude "
  sql += "FROM flightgps "
  sql += "WHERE flightdate='#{fdate}' AND flightno='#{fno}' "
  sql += "ORDER BY id "
  log("gen KM: #{sql}")
  res = con.exec(sql)

  xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  xml += "<kml xmlns=\"http://earth.google.com/kml/2.0\">\n"
  xml += "<Document>\n"
  xml += "<Placemark>\n"
  xml += "<LineString>\n"
  xml += "<coordinates>\n"

  res.each do |rec|
    lng = rec['longitude']
    lat = rec['latitude']
    xml += "  #{lng},#{lat},0\n"
  end

  xml += "</coordinates>\n"
  xml += "</LineString>\n"

  # Styling LineString
  xml += "<Style>\n"
  xml += "  <LineStyle>\n"  
  xml += "    <color>#ff0000ff</color>\n"
  xml += "    <width>3</width>\n"
  xml += "  </LineStyle>\n"
  xml += "</Style>\n"

  xml += "</Placemark>\n"
  xml += "</Document>\n"
  xml += "</kml>\n"

  kml = open("/data/dsi-uav/kml/#{fdate}-#{fno}.kml","w")
  kml.write(xml)
  kml.close

  # get center ### get extent won't work !!!
  sql = "SELECT center(the_geom) as center "
  sql += "FROM flightplan "
  sql += "WHERE flightdate='#{fdate}' AND flightno='#{fno}' "
  res = con.exec(sql)
  con.close
  latlng = res[0]['center'].tr('()','').split(',')
  center = "#{latlng.last},#{latlng.first}"
end

c = CGI::new
params = c.params
kmlname = 'NA'
center = 'NA'

if params.has_key?"file"
  # upload flight plan in /data/dsi-uav/flightplan
  file = params["file"].first 
  type = file.original_filename.split('.').last

  log("file:type => #{file.original_filename}:#{type}")
  
  server_file = '/data/dsi-uav/flightplan/' + file.original_filename
  if File.exists?(server_file)
    File.delete(server_file)
  end
  File.open(server_file.untaint, "w") do |f|
    f << file.read
  end

  # remove \r from DOS format
  system("perl -p -i -e 's/\r//g' #{server_file}")

  fdate = file.original_filename[0..7]
  fno = file.original_filename[9..10]
  kmlname = "/data/dsi-uav/kml/" + file.original_filename.gsub(/#{type}/,'kml')  

  # process txt (FIXED-WING) or XML (Multi-Rotor .awm) 
  # in /data/dsi-uav/flightplan
  process_flightplan(server_file)
  # generate KML to /data/dsi-uav/kml
  center = generate_kml(fdate,fno)
end

data = {}
data['success'] = true
data['flightdate'] = fdate
data['flightno'] = fno
data['kmlname'] = kmlname.gsub(/\/data\/dsi-uav/,'/dsiuav') # change actual kmlname to URL kmlname
data['center'] = center

# Return json back to user
print <<EOF
Content-type: text/html

#{data.to_json}
EOF
