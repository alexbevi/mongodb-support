require 'open-uri'
require 'json'
require 'csv'

STITCH_LOGS_URL = "https://stitch.mongodb.com/api/admin/v3.0/groups/%s/apps/%s/logs?end_date=%s&start_date=%s"

# change the following values to match your application and token
STITCH_APP      = "enter Stitch app id"
ATLAS_GROUP     = "enter Atlas group id"
DATE_START      = "2019-07-02T00%3A00%3A00.000-04%3A00"
DATE_END        = "2019-07-03T00%3A00%3A00.000-04%3A00"
AUTH_TOKEN      = "Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

done = false
logs = []
url = sprintf(STITCH_LOGS_URL, ATLAS_GROUP, STITCH_APP, DATE_END, DATE_START)
done = false

result = JSON.parse(open(url, "authorization" => AUTH_TOKEN).read)

def parse_date(datestring)
  begin
    # handle milliseconds
    return DateTime.strptime(datestring, "%Y-%m-%dT%H:%M:%S.%LZ").to_time.to_f
  rescue
    # handled without milliseconds
    return DateTime.strptime(datestring, "%Y-%m-%dT%H:%M:%SZ").to_time.to_f
  end
end

while !done do
  result["logs"].each do |log|
    started = parse_date(log["started"])
    completed = parse_date(log["completed"])
    log["duration"] = (completed - started) * 1000
    # ensure messages appear at the "end" of the hash so that exports are consistent
    m = log.delete("messages")
    log["messages"] = m
    logs << log
  end
  if result["nextEndDate"]
    url = sprintf(STITCH_LOGS_URL, ATLAS_GROUP, STITCH_APP, result["nextEndDate"], DATE_START)
    puts "Scraping from #{result["nextEndDate"]} ..."
    result = JSON.parse(open(url, "authorization" => AUTH_TOKEN).read)
  else
    done = true
  end
end

csv_string = CSV.generate do |csv|
  logs.each do |hash|
    csv << hash.values
  end
end
File.open("stitch-logs.csv", "w") do |f|
  f.write(logs.first.keys.join(","))
  f.write("\n")
  f.write(csv_string)
end