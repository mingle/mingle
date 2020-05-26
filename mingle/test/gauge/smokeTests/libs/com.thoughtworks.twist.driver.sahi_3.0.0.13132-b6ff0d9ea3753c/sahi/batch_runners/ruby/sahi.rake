require "local_build_properties/properties"

desc 'Tasks for running Sahi tests. Create a <user_name>_props.rb file based on default_props.rb.'

def sahi_test(browser, browser_exe, browser_options, start_url)
  cmd = "java -cp #{SAHI_DIR}/lib/ant-sahi.jar net.sf.sahi.test.TestRunner #{SAHI_SCRIPTS_DIR}/#{SAHI_TEST_SUITE} \"#{browser}\" #{start_url} default localhost 9999 1 #{browser_exe} \"#{browser_options}\""
  c = `#{cmd}`
  if /Status:FAILURE/ =~ c
    if cruise?
      Thread.new{
        system "\"#{browser}\" http://localhost:9999/_s/logs/"
      }
    end
    fail("tests failed!")
  end
end

def cruise?
  "#{ENV['LOGNAME']}" == "cruise"
end

desc "Runs sahi tests on IE"
task :sahi_tests_ie do
#  Rake::Task[:start_proxy].invoke
  proxyon
  sahi_test IE, IE_EXE, IE_OPTIONS, START_URL
  proxyoff
#  Rake::Task[:stop_proxy].invoke
end

desc "Runs sahi tests on Firefox"
task :sahi_tests_ff do
  sahi_test FIREFOX, FIREFOX_EXE, FIREFOX_OPTIONS, START_URL
end

task :sahi_tests_qa do
  sahi_test FIREFOX, "http://qa.url.com/"
end

desc "Starts webrick server"
task :start_server do
  Thread.new{
    system('ruby script/server')
  }
  sleep 3
end

desc "Starts webrick server with QA environment"
task :start_server_qa do
  Thread.new{
    system('ruby script/server -e qa')
  }
  sleep 3
end

desc "Stops webrick server"
task :stop_server do
  `ps ax | grep -i 'ruby script/server' | grep -i -v grep | awk '{print $1}' | xargs kill -9`
end

def proxyon
  system "#{SAHI_DIR}/tools/toggle_IE_proxy.exe enable"
end

task :proxyon do
  proxyon
end

task :proxyoff do
  proxyoff
end

def proxyoff
  system "#{SAHI_DIR}/tools/toggle_IE_proxy.exe disable"
end

desc "Starts Sahi proxy server"
task :start_proxy=>[:stop_proxy] do
  if (ENV["OS"] == 'Windows_NT')
    cmd  = "cd #{SAHI_DIR}\\bin & sahi.bat>..\\logs\\start.txt"
    cmd = cmd.gsub(/\//, '\\\\')
  else
    cmd  = "cd #{SAHI_DIR}/bin ;java -cp ../lib/sahi.jar net.sf.sahi.Proxy
>../logs/start.txt"
  end
  puts cmd
  Thread.new{
    system "#{cmd}"
  }
end

desc "Stops Sahi proxy server"
task :stop_proxy do
  require 'net/http'
  require 'uri'
  begin
    Net::HTTP.get URI.parse('http://localhost:9999/_s_/dyn/stopserver')
  rescue
  ensure
    puts 'Stopped Sahi'
  end
end
