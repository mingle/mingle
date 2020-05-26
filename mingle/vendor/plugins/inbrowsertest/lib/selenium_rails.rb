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

require File.dirname(__FILE__) + '/selenium'

require 'rbconfig'
require 'test/unit'
require File.dirname(__FILE__) + '/selenium_runner'
require 'net/http'
require 'uri'
require File.expand_path("../../../../test/server_starter", File.dirname(__FILE__))

SELENIUM_PROXY_PORT = ENV['SELENIUM_SERVER_PORT'] || 4444

module SeleniumRails

  mattr_accessor :server_startup_hooks
  self.server_startup_hooks = []

  module XPathSugar

    HTML_ELEMENTS = %w[ textarea input select h1 h2 h3 h4 h5 h6 a link p div ul ol li ]

    def build_xpath(method_name,*values)
      match, element, att_str = */([a-z]*)_with_([_a-z]*)/.match(method_name.to_s)
      if match && HTML_ELEMENTS.include?(element)
        element = 'a' if element == 'link'
        attributes = att_str.split('_and_')
        attributes = attributes.map {|a| "@#{a}='#{values.shift}'"}
        xpath = "//#{element}[#{attributes.join(' and ')}]"
      else
        non_xpath_method_missing(method_name,*values)
      end
    end

    def any_element_containing_text(text)
      "//.[contains(text(),\"#{text}\")]"
    end

    def h2_containing_text(text)
      "//h2[text()=\"#{text}\"]"
    end

    def h4_containing_text(text)
      "//h4[text()=\"#{text}\"]"
    end

    def link_containing_text(text)
      "//a[text()=\"#{text}\"]"
    end

    def self.included(base)
        base.class_eval do
          alias_method :non_xpath_method_missing, :method_missing unless method_defined?(:non_xpath_method_missing)
          alias_method :method_missing, :build_xpath
        end
    end
  end

  module WithMethod
    def with(object, &block)
      object.instance_eval(&block)
    end
  end

  module TestCase

    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        cattr_accessor :selenium_baseurl
        cattr_accessor :selenium_browser
        cattr_accessor :selenium_proxy_host
        cattr_accessor :selenium_proxy_port
      end

      base.selenium_baseurl = ServerStarter.base_url

      target_os = Config::CONFIG["target_os"] or raise 'Cannot determine operating system'
      if target_os =~ /mswin32/ || target_os =~ /Win/
        base.selenium_browser = "*iexploreproxy"
      elsif ENV['BROWSER'] == "firefox" || ENV['BROWSER'] == "*firefox"
        base.selenium_browser = "*firefox"
      else
        base.selenium_browser = "*googlechrome"
      end
      base.selenium_proxy_host = "127.0.0.1"
      base.selenium_proxy_port = SELENIUM_PROXY_PORT
    end

    def selenium_session
      self.class.selenium_session
    end

    module ClassMethods
      @@sessions = []

      def acceptance_test(name, &block)
       class_eval do
         define_method("test_"+name.underscore) do
           selenium_session.instance_eval(&block)
         end
       end
      end

      def new_selenium_session(session, skip = false)
        yield session if block_given?
        retryable(:on => Exception, :tries => 5, :sleep => 1) do
          session.start
          unless skip
            @@sessions << session
          end
          session.get_eval("this.browserbot.getCurrentWindow().moveTo(0,0)")
          session.get_eval("this.browserbot.getCurrentWindow().resizeTo(window.screen.availWidth, window.screen.availHeight)")
          return session
        end
      end

      def create_selenium_session
        if $debug
          puts "selenium_proxy_host: #{selenium_proxy_host}"
          puts "selenium_proxy_port: #{selenium_proxy_port}"
          puts "selenium_browser: #{selenium_browser}"
          puts "selenium_baseurl: #{selenium_baseurl}"
        end
        Selenium::SeleneseInterpreter.new(selenium_proxy_host, selenium_proxy_port, selenium_browser, selenium_baseurl)
      end

      def selenium_session
        @@sessions.last || new_selenium_session(create_selenium_session)
      end

      def close_selenium_sessions
        while (s = @@sessions.pop) do
          s.stop
        end
      end
    end
  end

  module ManageGoogleChromeMemory
    def self.included(base)
      base.setup :close_previous_test_case_browser_session
      base.cattr_accessor :already_cleaned_up
    end

    # close chrome every time we change scenarios - possibly may free up RAM during test runs
    def close_previous_test_case_browser_session
      unless self.class.already_cleaned_up == self.class.name
        ActiveSupport::TestCase.close_selenium_sessions
        sleep 1 # cool down
      end
      self.class.already_cleaned_up = self.class.name
    end

  end
end

module Selenium

  module PageObjectSupport
    def visits(page_class)
      extend(page_class)
      open(page_class.location)
    end

    def sees(page_class)
      extend(page_class)
      assert_location
    end
  end

  module BackwardsCompatability
    def type_into(location,text)
      type(location,text)
    end

    # def click_and_wait(location)
    #   click(location)
    #   wait_for_page_to_load
    # end
  end

  module Assertions
    def assert_text_present(text)
      raise SeleniumCommandError.new("#{text} not found in page") unless is_text_present(text)
    end

    def assert_text(location, expected)
      actual = get_text(location)
      actual = actual.force_encoding("utf-8") if MingleUpgradeHelper.ruby_1_9?
      msg = %Q{
        At location: #{location}
          Expected text: #{expected}
          Actual text:   #{actual}
      }
      raise SeleniumCommandError.new(msg) unless actual == expected
    end

    def assert_location(location)
      relative_path = get_location.gsub(/http:\/\/[^:]*:[^\/]*\//,'/')
      if location[-1,1]=='*'
        location_root = location.gsub('*','')
        raise SeleniumCommandError.new("#{relative_path} does not match not #{location}") unless relative_path.include?(location_root)
      else
        raise SeleniumCommandError.new("#{relative_path} is not #{location}") unless relative_path == location
      end
    end

    def assert_element_not_present(location)
        raise SeleniumCommandError.new("#{location} found in page") if is_element_present(location)
      end

    def assert_element_present(location)
      raise SeleniumCommandError.new("#{location} not found in page") unless is_element_present(location)
    end

    def assert_attribute(location,attribute)
      attribute_on_page = get_attribute(location)
      raise SeleniumCommandError.new("#{attribute} not on #{location}") unless attribute_on_page && attribute_on_page == attribute.to_s
    end
  end


  class SeleneseInterpreter
    include BackwardsCompatability
    include Assertions
    include SeleniumRails::XPathSugar
    include PageObjectSupport
  end

end

class ActiveSupport::TestCase

  include SeleniumRails::TestCase unless ancestors.include?(SeleniumRails::TestCase)
  include SeleniumRails::XPathSugar
  include SeleniumRails::WithMethod
  include SeleniumRails::ManageGoogleChromeMemory

end


unless ENV['skip_autorunner'] == 'true'
at_exit do
  unless $! || Test::Unit.run? then
    r = Test::Unit::AutoRunner.new(false)
    r.process_args
    r.runner = proc do |r|
      require File.dirname(__FILE__) + '/selenium_runner'
      SeleniumRails::Runner
    end
    begin
      result = r.run
    rescue Exception => e
      puts e.message
      puts e.backtrace
      exit(-1)
    end
    exit! result
  end
end
end
