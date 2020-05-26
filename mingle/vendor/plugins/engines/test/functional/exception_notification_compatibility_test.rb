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

require File.dirname(__FILE__) + '/../test_helper'

class ExceptionNotificationCompatibilityTest < ActionController::TestCase
  ExceptionNotifier.exception_recipients = %w(joe@schmoe.com bill@schmoe.com)
  class SimpleController < ApplicationController
    include ExceptionNotifiable
    local_addresses.clear
    consider_all_requests_local = false
    def index
      begin
        raise "Fail!"
      rescue Exception => e
        rescue_action_in_public(e)
      end
    end
  end
  
  def setup
    @controller = SimpleController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  def test_should_work
    assert_nothing_raised do
      get :index
    end
  end
end
