require 'open-uri'
require 'json'
require 'csv'

STITCH_LOGS_URL = "https://stitch.mongodb.com/api/admin/v3.0/groups/%s/apps/%s/logs?end_date=%s&start_date=%s"

# change the following values to match your application and token
STITCH_APP      = "5ae776ea4fdd1f3fea0b7c55"
ATLAS_GROUP     = "5ae350d80bd66b1c5f73483e"
DATE_START      = "2019-07-02T00%3A00%3A00.000-04%3A00"
DATE_END        = "2019-07-03T00%3A00%3A00.000-04%3A00"
AUTH_TOKEN      = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NjIxODE0NDAsImlhdCI6MTU2MjE3OTY0MCwiaXNzIjoiNWQxY2IxMTkyOTA1Nzk4MDgzNWYzZTI2Iiwic3RpdGNoX2RhdGEiOnsiYXBwX2lkIjoiWXdBQUFBVjJZV3gxWlFCQUFBQUFBS0Z2Y1J3a1EzNVE2cmtoSmtmamJybEREL29DK1JIQWN2anJnMytjTEpaK2J3U1FQUTRHY1M0Vlo3VEt6VmFKR3E1YThza0hXd3YxU29INC9lUXF3Z29JWlc1amNubHdkR1ZrWDNaaGJIVmxBQUVBIiwiYXV0aC9zb3VyY2VkX2J5X3Byb3ZpZGVyX2lkIjoiWXdBQUFBVjJZV3gxWlFCQUFBQUFBSS9oTWJuM0JPSGFDMG5oVVphRXFkaFZlVDYrVGgwQ0xrbFkxVlEzWlhiY1lDbkxmbkRGbVQ0Y2w2R0M5MGd2aE1xV3lJK2o1T09nUkZ1VDBBcUY3bkFJWlc1amNubHdkR1ZrWDNaaGJIVmxBQUVBIiwibW9uZ29kYi9jbG91ZC1hcGlLZXkiOiJjd0FBQUFWMllXeDFaUUJRQUFBQUFNNHkrVlU1VlpaMjZmMzhHa0tEZEZPd0J5RDYzZFNjMWtMYVlBZm9FaGpkQUFzWE90VCtJUGFyTW5KTVVIdzhIS3VFZGFzOHE3VUg5SkFrOHV3eEh2OHhSbTY3M1o1NEVZNXJvTTFiWnRBQUNHVnVZM0o1Y0hSbFpGOTJZV3gxWlFBQkFBPT0iLCJtb25nb2RiL2Nsb3VkLXVzZXJuYW1lIjoiWXdBQUFBVjJZV3gxWlFCQUFBQUFBRU1ocDZ5RENCZk1qd3ZiT2xZeHNDNFl4MndYSk9keGRwMzdvTUdxaHZYbTcrQmhIQ3VYbjJKZzRFWVlkaUZUdVQ1cm42bThKaW5WaUJ4TGl3RjdqTk1JWlc1amNubHdkR1ZrWDNaaGJIVmxBQUVBIn0sInN0aXRjaF9kZXZJZCI6IjViZDBiNjNkMGUxMTkwYTFiZWU3N2IwOCIsInN0aXRjaF9kb21haW5JZCI6IjAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMCIsInN1YiI6IjViN2M0OTMxZGY5ZGIxNGUxYWNiYjBhNSIsInR5cCI6ImFjY2VzcyJ9.fqTUWMQMKBZJk1qNsTyXkKtwUyJ0C50cf_hPcV762ao"

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