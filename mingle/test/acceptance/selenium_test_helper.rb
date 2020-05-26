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

require 'selenium_rails'
require 'erb'

ActiveSupport::TestCase.selenium_baseurl = ENV['BASEURL'] unless ENV['BASEURL'].blank?
ActiveSupport::TestCase.selenium_browser = ENV['BROWSER'] unless ENV['BROWSER'].blank?

def get_local_ip
  return ENV["SERVER_IP"] if ENV["SERVER_IP"]
  require 'socket'
  IPSocket.do_not_reverse_lookup = true
  IPSocket.getaddress Socket.gethostname
end

def switch_to_remote_selenium_proxy(proxy_host, proxy_port, browser, local_ip=get_local_ip)
  ActiveSupport::TestCase.selenium_proxy_host = proxy_host
  ActiveSupport::TestCase.selenium_proxy_port = proxy_port
  ActiveSupport::TestCase.selenium_browser = browser

  ActiveSupport::TestCase.selenium_baseurl = "http://#{local_ip}:4001"
  ServerStarter::RailsEnvironment.port = 4001
  ServerStarter::RailsEnvironment.ip = local_ip
end

if (ENV['USE_QA_MACHINE'])
  ENV['REMOTE_SELENIUM_AGENT'] = "10.2.12.47"
  puts "\n*** Using QA machine ***\n"
end

# Run tests against selenium-rc on a Windows machine
if (ENV['REMOTE_SELENIUM_AGENT'].present?)
  puts %Q{

    *** Using REMOTE_SELENIUM_AGENT #{ENV['REMOTE_SELENIUM_AGENT']} ***

    If running in TextMate, go to the Shell Variables tab under Preferences to modify

  }
  switch_to_remote_selenium_proxy("#{ENV['REMOTE_SELENIUM_AGENT']}", "4444", "iexploreproxy")
end

SeleniumRails.server_startup_hooks << proc do |host, port|
   Net::HTTP.get_print(URI.parse("http://#{host}:#{port}/_class_method_call?class=Messaging&method=enable"))
end

class ActiveSupport::TestCase
  cattr_accessor :current_user

  class << self
    def new_selenium_session_with_set_default_timeout(session, skip=false, &block)
      new_selenium_session_without_set_default_timeout(session, skip, &block).tap do |browser|
        timeout = 100
        browser.get_eval("selenium.defaultTimeout = #{timeout} * 1000;")
      end
    end
    safe_alias_method_chain :new_selenium_session, :set_default_timeout
  end

  setup :mingle_setup
  teardown :mingle_teardown

  def mingle_setup
    @start_time = Time.now
    puts "\n#{name}"
  end

  def mingle_teardown
    puts "took #{Time.now - @start_time} seconds"
    clear_project_cache
    reset_license
  end

  alias_method :add_error_without_selenium_snapshot, :add_error
  def add_error(exception)
    puts "\n#{exception.message}: \n#{exception.backtrace.join("\n")}\n"
    add_error_without_selenium_snapshot(exception)
    save_browser_snapshot
    refresh_selenium_sessions
    @has_error = true
  end

  alias_method :old_add_failure, :add_failure
   def add_failure(message, all_locations=caller())
     puts "\nFailure: #{message}: \n#{all_locations.join("\n")}\n"
     old_add_failure(message, all_locations)
     save_browser_snapshot
     refresh_selenium_sessions
     @has_error = true
   end

  def refresh_selenium_sessions
    self.class.close_selenium_sessions
    self.class.new_selenium_session(self.class.create_selenium_session)
  end

  def clear_project_cache
    # rescue all exception here so that these error would not hide really error in reports
    ProjectCacheFacade.instance.clear
  rescue Exception => e
    puts message = <<-EOS
      Clear project cache failed.
        Exception: #{e}
        Message  : #{e.message}
        Trace    : #{e.backtrace.join("\n")}
    EOS
    ActiveRecord::Base.logger.debug(message)
  end

  private
  def using_ie?
    ActiveSupport::TestCase.selenium_browser =~ /iexplore/
  end

  def reset_license
    # rescue all exception here so that these error would not hide really error in reports
    LicenseDecrypt.reset_license
  rescue Exception => e
    puts "reset license failed with reason of #{e}:#{e.message}"
  end

  def save_browser_snapshot
    return unless @browser
    snapshot_basename = File.join(Rails.root, 'test', 'reports', 'snapshots', "#{self.name}")
    snapshot_markup = "#{snapshot_basename}.html"
    return if File.exist?(snapshot_markup)

    FileUtils.mkdir_p(File.dirname(snapshot_markup))
    File.open(snapshot_markup, 'w') { |f|  f << @browser.take_snapshot }
    # @browser.take_screenshot("#{snapshot_basename}.png")
  rescue Exception => e
    puts "saving browser snapshot failed with reason of #{e}:#{e.message}"
  end
end
