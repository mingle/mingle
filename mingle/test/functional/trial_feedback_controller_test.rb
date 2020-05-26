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

class TrialFeedbackControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller TrialFeedbackController
    @user = login_as_member
  end

  def test_feedback_is_sent_as_email
    post :create, :message => "oh so blue!"
    assert_response :success
    assert_nil ActionMailer::Base.deliveries.first.cc
  end

  def test_show_trial_feedback_for_new_user
    fat_bob = create_user! :login => 'fat_bob'
    login(fat_bob.name)
    get :new
    assert_response :success
    assert !fat_bob.reload.trial_feedback_shown?
  end

  def test_trial_feedback_form_should_not_be_displayed_once_submited
    fat_bob = create_user! :login => 'fat_bob'
    login(fat_bob.name)
    post :create, :message => 'dooh!'
    assert_response :success
    assert fat_bob.reload.trial_feedback_shown?
  end


end
