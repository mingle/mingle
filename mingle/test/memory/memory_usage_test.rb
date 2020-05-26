#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require 'java'
require 'net/http'
require 'net/https'
require 'jmx4r'

class AllMemoryTest < ActiveSupport::TestCase

  def setup
    @performance_spec = {
      :mingle_port =>'8080',
      :host => ENV["MEMTEST_HOST"] || "localhost",
      :port => ENV["MEMTEST_HOST_PORT"] || '8080',
      :auth_user => ENV["MEMTEST_USER"] || 'mingleadmin',
      :auth_passwd => ENV["MEMTEST_PASSWD"] || 'password',
      :httperf_logfile => (ENV["HTTPERF_LOG_ROOT"] || "/export/users/mingle_builder/mingle-performance-httperf"),
      :httperf_sessions => (ENV["HTTPERF_SESSIONS"] || "1"),
      :jmx_port => ENV["MEMTEST_JMX_PORT"] || "1098"
    }
  end

  def test_memory_usage
    output_file = File.expand_path(File.dirname(__FILE__) + '/../../tmp/memorytest.csv')
    `/bin/rm -f #{output_file}`
    numOfUsers = 20
    #testTarget = ["card_summary", "card_add_comment", "card_grid", "card_list", "card_show", "update_property"]
    testTarget = ["card_summary", "card_add_comment", "card_list", "card_show",  "update_property"]
    testTargetIndex = {}
    testTargetNumOfRequests = {}
    threads = []
    testTarget.each do |target|
      testTargetIndex[target] = 1
      testTargetNumOfRequests[target] =  %x[cat #{@performance_spec[:httperf_logfile]}/log/#{target}.hlog | wc -l].to_i
    end
    numberOfHours = 2
    startTime = Time.new
    stopTime = startTime + (numberOfHours * 60 * 60)
    #stopTime = startTime + 1800

    requests = {}
    while (Time.new <= stopTime)
      poll_jmx(output_file)
      (0..numOfUsers-1).each do |user|
        tmpTarget = testTarget[rand(testTarget.size)]
        requests[user] = tmpTarget + "|" + testTargetIndex[tmpTarget].to_s
        testTargetIndex[tmpTarget] = testTargetIndex[tmpTarget] >= testTargetNumOfRequests[tmpTarget] ? 1 : testTargetIndex[tmpTarget] + 1
      end
      (0..requests.size).each do |index|
        Thread.new(index){ |newRequest|
          tmpRequest = requests[index].split(/\|/)
          requestUrl = %x[head -#{tmpRequest[1]} #{@performance_spec[:httperf_logfile]}/log/#{tmpRequest[0]}.hlog | tail -1]
          if requestUrl =~ /method\=POST/
            send_post_request(requestUrl)
          else
            send_get_request(requestUrl)
          end
        }
      end
      sleep 10.0
      requests.clear
      #puts "Number of threads with false status : #{Thread.list.select{ |t| t.status != false }.size}"
    end
  end

  def poll_jmx(output_file)
    csv_file=File.new(output_file,"a+")
    JMX::MBean.establish_connection :host => @performance_spec[:host], :port=>@performance_spec[:jmx_port]
    memory = JMX::MBean.find_by_name "java.lang:type=Memory"
    useOldJMXGCname = false
    begin
      gcConc = JMX::MBean.find_by_name "java.lang:type=GarbageCollector,name=PS MarkSweep"
      gcPn = JMX::MBean.find_by_name "java.lang:type=GarbageCollector,name=PS Scavenge"
    rescue
      puts "Use old JMX GC name"
      useOldJMXGCname = true
    end
    if useOldJMXGCname == true
        gcConc = JMX::MBean.find_by_name "java.lang:type=GarbageCollector,name=MarkSweepCompact"
        gcPn = JMX::MBean.find_by_name "java.lang:type=GarbageCollector,name=Copy"
    end
    heap= memory.heap_memory_usage
    #puts "Heap Memory Max : #{heap['max']}"
    #puts "Heap Memory Used : #{heap['used']}"
    #puts "Heap Memory Committed : #{heap['committed']}"
    #puts "ConcurrentMarkSweep GC Time : #{gcConc.collection_time}"
    #puts "ConcurrentMarkSweep GC Collections : #{gcConc.collection_count}"
    #puts "ParNew GC Time : #{gcPn.collection_time}"
    #puts "ParNew GC Collections : #{gcPn.collection_count}"
    #%x[/bin/echo #{Time.new},#{heap['max']},#{heap['used']},#{heap['committed']},#{gcConc.collection_time},#{gcConc.collection_count},#{gcPn.collection_time},#{gcPn.collection_count} >> #{output_file}]
    csv_file.puts "#{Time.new},#{heap['max']},#{heap['used']},#{heap['committed']},#{gcConc.collection_time},#{gcConc.collection_count},#{gcPn.collection_time},#{gcPn.collection_count}"
    JMX::MBean.remove_connection :host => @performance_spec[:host], :port=>@performance_spec[:jmx_port]
    csv_file.close
  end

  def send_get_request(requestUrl)
    begin
      h = Net::HTTP.new(@performance_spec[:host],@performance_spec[:port])
      h.read_timeout=120
      h.start
      req = Net::HTTP::Get.new(requestUrl.split(/ /)[0].chomp)
      req.basic_auth 'bhkwan','password'
      response = h.request(req)
      h.finish
   rescue TimeoutError
     # Temporary skip this
   end
  end

  def send_post_request(requestUrl)
    begin
      postRequest = requestUrl.split(/ /)
      h = Net::HTTP.new(@performance_spec[:host],@performance_spec[:port])
      h.read_timeout=120
      h.start
      req = Net::HTTP::Post.new("#{postRequest[0]}&#{postRequest[2].split(/=/,2)[1].chomp}")
      req.basic_auth 'bhkwan','password'
      req["Content-Type"] = "application/x-www-form-urlencoded"
      response = h.request(req)
      h.finish
   rescue TimeoutError
     # Temporary skip this
   end
end

  def publish_cruise_properties(property_name, property_value)
    if ENV['CRUISE_SERVER_URL'] != nil
      url = URI.parse("#{ENV['CRUISE_SERVER_URL']}")
      http = Net::HTTP.new(url.host,url.port)
      if (url.scheme == 'https')
        http.use_ssl = true
      end
      http.start(){ |http|
        req = Net::HTTP::Post.new("#{url.path}properties/#{ENV['CRUISE_PIPELINE_NAME']}/#{ENV['CRUISE_PIPELINE_LABEL']}/#{ENV['CRUISE_STAGE_NAME']}/#{ENV['CRUISE_JOB_NAME']}/#{property_name}")
        req.basic_auth "#{ENV['CRUISE_MINGLE_USER']}","#{ENV['CRUISE_MINGLE_USER_PASSWORD']}"
        req.set_form_data({'value'=>property_value},';')
        res = http.request(req)
        case res
          when Net::HTTPSuccess, Net::HTTPRedirection
            puts res.body
          else
            puts res.error!
        end
      }
    else
      puts "#{property_name}:#{property_value}"
    end
  end

end
