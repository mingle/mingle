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

class UnderTheHoodControllerTest < ActionController::TestCase

  def setup
    login_as_admin
  end

  def test_index_renders
    get :index
    assert_select 'input[id=logger__disabled]', :count => 1
  end

  def test_toggle_default_logger_should_show_its_enabled_status
    put :toggle_logging_level, :logger => ''
    assert_redirected_to :action => :index
    follow_redirect
    assert_select 'input[id=logger__enabled][checked]', :count => 1
  end

  def test_should_include_search
    requires_jruby do
      get :index
      assert_select 'input[id=logger_search_enabled]', :count => 1
    end
  end

  def test_should_use_specific_logger_if_specified
    requires_jruby do
      Log4j::Logger.new(:namespace => "com.thoughtworks.mingle", :name => "pool").level = Logger::INFO
      Log4j::Logger.new(:namespace => "com.thoughtworks.mingle").level = Logger::INFO

      get :index

      assert_select 'input[id=logger_pool_disabled][checked]', :count => 1
      assert_select 'input[id=logger__disabled][checked]', :count => 1

      put :toggle_logging_level, :logger  => "pool"

      assert_redirected_to :action => :index
      follow_redirect
      assert_select 'input[id=logger__disabled][checked]', :count => 1
      assert_select 'input[id=logger_pool_enabled][checked]', :count => 1
    end
  end

  def test_blocks_non_admin
    login_as_member
    [:index, :toggle_logging_level].each do |admin_only_action|
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        get admin_only_action
      end
    end
  end

  def test_disabled_in_multitenant_mode
    MingleConfiguration.with_multitenancy_mode_overridden_to(true) do
      get :index
      assert_response :not_found
    end
  end
end
