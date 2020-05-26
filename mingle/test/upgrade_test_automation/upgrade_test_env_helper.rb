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

ENV["RAILS_ENV"] = "test"

require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")
require 'test_help'
require 'selenium_rails'
require File.expand_path(File.dirname(__FILE__) + '/../acceptance/mingle_helpers')

ActiveSupport::TestCase.selenium_baseurl = ENV['BASEURL'] unless ENV['BASEURL'].blank?
ActiveSupport::TestCase.selenium_browser = ENV['BROWSER'] unless ENV['BROWSER'].blank?

# Test::Unit::TestCase.selenium_baseurl = "http://10.18.8.80:8080"  # your mingle server port
Test::Unit::TestCase.selenium_baseurl = "http://localhost:18479"  # your mingle server port
SeleniumRails::MRIEnvironment.port = 8080
SeleniumRails::MRIEnvironment.ip = 'localhost'


class ActiveSupport::TestCase #:nodoc:
  self.use_transactional_fixtures = false

  def setup_fixtures; end

  def teardown_fixtures; end

  def css_locator(css, index=0)
    %{dom=this.browserbot.getCurrentWindow().$$(#{css.to_json})[#{index}]}
  end
end



module SeleniumRails
  class JRubyEnvironment
    class << self
      def start(*args)
      end
    end
  end

  class MRIEnvironment
    class << self
      def start(*args)
      end
    end
  end
end
