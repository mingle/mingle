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
include UserDisplayPreferenceHelper

class UserDisplayPreferenceControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller UserDisplayPreferenceController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    rescue_action_in_public!
    ActionMailer::Base.deliveries = []
    @member_user = create_user!
    @member_name = @member_user.name
    @admin = User.find_by_login('admin')
    @bob = User.find_by_login('bob')
    Project.find(:all).each{ |p| set_anonymous_access_for(p, false) }
    login(@member_user)
    UserDisplayPreference.destroy_all
  end

  def teardown
    Authenticator.authentication = MingleDBAuthentication.new
  end

  def test_can_update_display_preference_when_no_existing_preference
     post :update_user_display_preference, :user_display_preference => {:favorites_visible => 'true'}
     assert_response(:success)
     assert_equal 1, UserDisplayPreference.count
     assert @member_user.reload.display_preference.read_preference(:favorites_visible)
   end

   def test_can_update_existing_display_prefernece
     existing_pref = UserDisplayPreference.default_for(@member_user)
     existing_pref.update_preference(:favorites_visible, true)
     post :update_user_display_preference, :user_display_preference => {:favorites_visible => 'false'}
     assert_response(:success)
     assert !existing_pref.reload.read_preference(:favorites_visible)
   end

   def test_can_update_export_excel_include_description_through_user_display_prefernece
     existing_pref = UserDisplayPreference.default_for(@member_user)
     existing_pref.update_preference(:include_description, false)
     post :update_user_display_preference, :user_display_preference => {:include_description => 'true'}
     assert_response(:success)
     assert existing_pref.reload.read_preference(:include_description)
   end

   def test_can_update_show_murmurs_in_sidebar
     assert UserDisplayPreference.default_for(@member_user).read_preference(:show_murmurs_in_sidebar)

     post :update_user_display_preference, :user_display_preference => {:show_murmurs_in_sidebar => 'false'}
     assert_response(:success)
     assert !@member_user.user_display_preference.read_preference(:show_murmurs_in_sidebar)
   end

  def test_should_update_project_preference
    assert UserDisplayPreference.default_for(@member_user).read_project_preference(Project.first,:slack_murmur_subscription)
    post :update_user_project_preference, project_id: Project.first.id, user_project_preference: {preference: :slack_murmur_subscription, value: false}
    assert_response(:success)
    assert !@member_user.reload.display_preference.read_project_preference(Project.first, :slack_murmur_subscription)

    post :update_user_project_preference, project_id: Project.first.id, user_project_preference: {preference: :slack_murmur_subscription, value: true}
    assert_response(:success)
    assert @member_user.reload.display_preference.read_project_preference(Project.first, :slack_murmur_subscription)
  end

  def test_should_update_project_preference_should_send_404
    assert UserDisplayPreference.default_for(@member_user).read_project_preference(Project.first,:slack_murmur_subscription)
    post :update_user_project_preference, user_project_preference: {preference: :slack_murmur_subscription, value: false}
    assert_response 401
  end

   def test_can_sets_the_i_hate_holiday_preference_for_user
     assert_nil @member_user.display_preference.read_preference(:i_hate_holidays)
     post :update_holiday_effects_preference, :holiday => "Diwali 2015"
     assert_response(:success)
     assert_equal "Diwali 2015", @member_user.reload.display_preference.read_preference(:i_hate_holidays)
   end

   def test_update_show_deactived_users
     assert UserDisplayPreference.default_for(@member_user).read_preference(:show_deactived_users)

     xhr :post, :update_show_deactived_users, :search => { :show_deactivated => '0' }
     assert !@member_user.user_display_preference.read_preference(:show_deactived_users)
     assert_rjs :redirect_to, :controller => 'users', :action => 'index', :search => { :show_deactivated => '0' }, :escape => false
   end

   def test_update_show_deactived_users_should_retain_params
     xhr :post, :update_show_deactived_users, :search => { :query => 'a' , :show_deactivated => '0' }, :page => 2
     assert_rjs :redirect_to, :controller => 'users', :action => 'index', :search => { :query => 'a' , :show_deactivated => '0' }, :page => 2, :escape => false
   end

   def test_update_timeline_granularity
     assert_nil UserDisplayPreference.default_for(@member_user).read_preference(:timeline_granularity)

     xhr :post, :update_user_display_preference, :user_display_preference => {:timeline_granularity => 'weeks'}
     assert_equal 'weeks', @member_user.user_display_preference.read_preference(:timeline_granularity)
   end

   def test_update_user_preferences
     xhr :post, :update_new_user_display_preferences
   end

  def test_should_display_retirement_banner_if_preference_not_set
    MingleConfiguration.overridden_to(:display_export_banner => true, :multitenancy_mode => true, :saas_env => true) do
      Timecop.freeze(2018, 8, 10) do
        @project = first_project
        current_month = Date.today.strftime("%B")
        login_as_bob

        assert_equal Hash.new, UserDisplayPreference.default_for(@bob).read_preference(:preferences)
        assert display_export_notice?
        assert_equal ({"last_displayed_retirement_banner_on"=>"#{current_month}"}), @bob.user_display_preference.read_preference(:preferences)
      end
    end
  end

  def test_should_not_display_retirement_banner_if_preference_not_set_for_installer
    MingleConfiguration.overridden_to(:display_export_banner => true) do
      Timecop.freeze(2018, 8, 10) do
        @project = first_project
        current_month = Date.today.strftime("%B")
        login_as_bob
        assert_equal Hash.new, UserDisplayPreference.default_for(@bob).read_preference(:preferences)
        assert_false display_export_notice?
      end
    end
  end

  def test_should_display_retirement_banner_if_preference_is_set_to_a_different_month
    Timecop.freeze(2018, 8, 4) do
      MingleConfiguration.overridden_to(:display_export_banner => true,  :multitenancy_mode => true, :saas_env => true) do
        @project = first_project
        current_month = Date.today.strftime("%B")
        login_as_bob
        UserDisplayPreference.default_for(@bob).update_preference(:preferences, {:last_displayed_retirement_banner_on => "July"})
        assert display_export_notice?
        assert_equal ({:last_displayed_retirement_banner_on => "#{current_month}"}), @bob.reload.user_display_preference.read_preference(:preferences)
      end
    end
  end
end
