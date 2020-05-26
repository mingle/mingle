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

class ActionMailerTest < ActiveSupport::TestCase
  def test_action_mailer_base_defaul_url_options_should_be_threadsafe

    ActionMailer::Base.default_url_options = { :host => "http://override_everything" }

    thread_1 = Thread.new do
      ActionMailer::Base.default_url_options = { :host => "http://site1" }
      assert_equal  "http://site1", ActionMailer::Base.default_url_options[:host]
    end

    thread_2 = Thread.new do
      ActionMailer::Base.default_url_options = { :host => "http://site2" }
      assert_equal  "http://site2", ActionMailer::Base.default_url_options[:host]
    end

    thread_1.join
    thread_2.join

    assert_equal  "http://override_everything", ActionMailer::Base.default_url_options[:host]
  end
end
