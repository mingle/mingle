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

require File.expand_path('../../test_helper', __FILE__)

class UserDisplayPreferenceControllerTest < ActionDispatch::IntegrationTest

  def setup
    @user = login(create(:user))
  end

  def teardown
    Thread.current[:rollback_only] = nil
    logout_as_nil
  end

  def test_can_update_display_preference_when_no_existing_preference
    post update_user_display_preference_url, params: {user_display_preference: {:favorites_visible => 'true'} }
    assert_response(:success)
    assert_equal 1, UserDisplayPreference.count
    assert @user.display_preference.read_preference(:favorites_visible)
  end

  def test_can_update_existing_display_prefernece
    existing_pref = @user.display_preference
    existing_pref.update_preference(:favorites_visible, true)
    post update_user_display_preference_url, params: {user_display_preference: {:favorites_visible => 'false'} }

    assert_response(:success)
    assert_false existing_pref.reload.read_preference(:favorites_visible)
  end

  def test_can_update_export_excel_include_description_through_user_display_prefernece
    existing_pref = @user.display_preference
    existing_pref.update_preference(:include_description, false)

    post update_user_display_preference_url, params: {user_display_preference: {:include_description => 'false', :excel_import_export_visible => 'true'} }

    assert_response(:success)
    assert_false existing_pref.reload.read_preference(:include_description)
    assert existing_pref.reload.read_preference(:excel_import_export_visible)
  end

  def test_update_timeline_granularity
    assert_nil UserDisplayPreference.default_for(@user).read_preference(:timeline_granularity)

    post update_user_display_preference_url, params: {user_display_preference: {:timeline_granularity => 'weeks'}}
    assert_equal 'weeks', @user.reload.user_display_preference.read_preference(:timeline_granularity)
  end

  def test_can_sets_the_i_hate_holiday_preference_for_user
    assert_nil @user.display_preference.read_preference(:i_hate_holidays)
    post update_holiday_effects_preference_url, params: {holiday: 'Diwali 2015'}
    assert_response(:success)
    assert_equal "Diwali 2015", @user.reload.display_preference.read_preference(:i_hate_holidays)
  end

  def test_update_show_deactivated_users
    assert @user.display_preference.read_preference(:show_deactived_users)

    post update_show_deactived_users_url, params: {:search => { :show_deactivated => '0' }}
    assert_false @user.reload.display_preference.read_preference(:show_deactived_users)
    assert_redirected_to '/users/list?' + {escape: false, search: {show_deactivated: '0'}}.to_query
  end

  def test_update_show_deactived_users_should_retain_params
    post update_show_deactived_users_url, params: {:search => { :query => 'a' , :show_deactivated => '0' }, :page => 2}

    assert_redirected_to '/users/list?'+ {escape: false, search: {query: 'a', show_deactivated: '0'}, page: 2}.to_query
  end

  def test_can_update_show_murmurs_in_sidebar
    assert @user.display_preference.read_preference(:show_murmurs_in_sidebar)

    post update_user_display_preference_url, params: {:user_display_preference => {:show_murmurs_in_sidebar => 'false'}}
    assert_response(:success)
    assert_false @user.reload.user_display_preference.read_preference(:show_murmurs_in_sidebar)
  end

  def test_should_update_project_preference
    first_project = create(:project)
    assert @user.display_preference.read_project_preference(first_project,:slack_murmur_subscription)
    post update_user_project_preference_url, params:{project_id: first_project.id, user_project_preference: {preference: :slack_murmur_subscription, value: false}}

    assert_response(:success)
    assert_false @user.reload.display_preference.read_project_preference(first_project, :slack_murmur_subscription)

    post update_user_project_preference_url, params: {project_id: first_project.id, user_project_preference: {preference: :slack_murmur_subscription, value: true}}

    assert_response(:success)
    assert @user.reload.display_preference.read_project_preference(first_project, :slack_murmur_subscription)
  end

  def test_should_update_project_preference_should_send_404
    assert @user.display_preference.read_project_preference(build(:project),:slack_murmur_subscription)
    post update_user_project_preference_url, params: {user_project_preference: {preference: :slack_murmur_subscription, value: false}}

    assert_response 401
  end

end
