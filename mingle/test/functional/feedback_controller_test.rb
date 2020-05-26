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

class FeedbackControllerTest < ActionController::TestCase

  def setup
    ActionMailer::Base.deliveries = []
    @user = login_as_member
  end

  def test_feedback_is_sent_as_email
    @request.env['HTTP_REFERER'] = 'http://localhost:3000/sessions/new'
    post :create, :"user-email" => "foo@bar.com", :message => "oh so blue!"
    assert_response :success
    assert_include "http://localhost:3000/sessions/new", ActionMailer::Base.deliveries.first.body
    assert_include "oh so blue!", ActionMailer::Base.deliveries.first.body
    assert_equal ["support@thoughtworks.com"], ActionMailer::Base.deliveries.first.cc
  end

  def test_validating_empty_params
    @request.env['HTTP_REFERER'] = 'http://localhost:3000/sessions/new'
    post :create, :message => "oh so blue!"
    assert_response :unprocessable_entity

    @request.env['HTTP_REFERER'] = 'http://localhost:3000/sessions/new'
    post :create, :"user-email" => "foo@bar.com"
    assert_response :unprocessable_entity

    @request.env['HTTP_REFERER'] = 'http://localhost:3000/sessions/new'
    post :create
    assert_response :unprocessable_entity
  end

  def test_validating_invalid_emails
    @request.env['HTTP_REFERER'] = 'http://localhost:3000/sessions/new'
    post :create, :"user-email" => "foobar.com", :message => "foo"
    assert_response :unprocessable_entity
  end

end
