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

class UserDisplayPreferenceTest < ActiveSupport::TestCase
  def setup
    @session = {}
    @normal_user_preference = UserDisplayPreference.default_for(User.find_by_login('bob'))
    @anonymous_user_preference = UserDisplayPreference.for_anonymous_user(@session)
  end

  def test_should_convert_string_value_to_bool
    @normal_user_preference.update_preference(:card_flyout_display, "false")
    assert_equal false, @normal_user_preference.read_preference(:card_flyout_display)
  end

  def test_should_be_able_to_get_default_value_of_include_description_from_user_preference
    assert_equal false, @normal_user_preference.read_preference(:include_description)
  end

  def test_should_be_able_to_set_include_description_user_preference
    @normal_user_preference.update_preference(:include_description, true)
    assert_equal true, @normal_user_preference.read_preference(:include_description)
  end

  def test_default_value_for_contextual_help_should_be_empty
    assert_equal({}, @normal_user_preference.read_preference("contextual_help"))
  end

  def test_should_store_state_in_session
    @anonymous_user_preference.update_preference "favorites_visible", true
    assert_equal 'true', @session["favorites_visible"]
    @anonymous_user_preference.update_preference "favorites_visible", false
    assert_equal 'false', @session["favorites_visible"]
  end

  def test_update_to_value_same_with_default
    @anonymous_user_preference.update_preference "excel_import_export_visible", false
    assert_equal 'false', @session["excel_import_export_visible"]
  end

  def test_update_should_be_able_to_figure_out_string_boolean
    @anonymous_user_preference.update_preference "favorites_visible", 'true'
    assert_equal 'true', @session["favorites_visible"]
    assert @anonymous_user_preference.read_preference(:favorites_visible)

    @anonymous_user_preference.update_preference "favorites_visible", 'false'
    assert_equal 'false', @session["favorites_visible"]
    assert !@anonymous_user_preference.read_preference(:favorites_visible)
  end

  def test_give_out_default_attribute_if_there_no_key_in_session
    UserDisplayPreference::DEFAULT_VALUES.each do |key, value|
      assert_equal value, @anonymous_user_preference.read_preference(key.to_s)
    end
  end

  def test_value_in_session_should_overridden_defaults
    @session["favorites_visible"] = "true"
    assert @anonymous_user_preference.read_preference("favorites_visible")
    @session["favorites_visible"] = "false"
    assert !@anonymous_user_preference.read_preference("favorites_visible")
  end

  def test_grid_settings_should_not_be_visible
    assert_false @normal_user_preference.read_preference("grid_settings")
    assert_false @anonymous_user_preference.read_preference("grid_settings")
  end

  def test_update_should_be_able_to_change_grid_settings_preference
    @anonymous_user_preference.update_preference "grid_settings", false
    assert_equal 'false', @session["grid_settings"]
    @anonymous_user_preference.update_preference "grid_settings", true
    assert_equal 'true', @session["grid_settings"]
  end

  def test_can_use_symbol_to_do_attribute_update
    assert @anonymous_user_preference.read_preference(:sidebar_visible)
    @anonymous_user_preference.update_preference :sidebar_visible, false
    assert_false @anonymous_user_preference.read_preference(:sidebar_visible)
  end

  def test_should_be_able_to_use_preference_key_as_method
    assert !@anonymous_user_preference.read_preference(:favorites_visible)
    @anonymous_user_preference.update_preference("favorites_visible", true)
    assert @anonymous_user_preference.read_preference(:favorites_visible)
  end

  def test_store_preference_with_string_key_and_read_with_symbol_key
    @normal_user_preference.update_preference("foo", "bar")
    assert_equal 'bar', @normal_user_preference.read_preference(:foo)
    @normal_user_preference.reload
    assert_equal 'bar', @normal_user_preference.read_preference(:foo)
  end

  def test_store_preference_with_symbol_key_and_read_with_string_key
    @normal_user_preference.update_preference(:foo, "bar")
    assert_equal 'bar', @normal_user_preference.read_preference('foo')
    @normal_user_preference.reload
    assert_equal 'bar', @normal_user_preference.read_preference('foo')
  end

  def test_can_set_value_to_false
    @normal_user_preference.update_preference(:foo, false)
    assert_false @normal_user_preference.read_preference(:foo)
  end

  def test_current_user_prefs_should_return_same_object_after_first_save
    bob = login_as_bob

    p1 = UserDisplayPreference.current_user_prefs
    p1.update_preference(:export_all_columns, true)
    assert_same p1, UserDisplayPreference.current_user_prefs
  end

  def test_should_be_able_to_update_multiple_user_preferences
    bob = login_as_bob
    UserDisplayPreference.current_user_prefs.update_preference(:export_all_columns, true)
    UserDisplayPreference.current_user_prefs.update_preference(:include_description, true)
    assert UserDisplayPreference.current_user_prefs.read_preference(:export_all_columns)
    assert UserDisplayPreference.current_user_prefs.read_preference(:include_description)
  end

  def test_delete_user_should_also_delete_user_display_preference
    user = create_user!
    user_preference = UserDisplayPreference.default_for(user)
    user_preference.save!
    user.destroy
    assert_nil UserDisplayPreference.find_by_id(user_preference.id)
  end

  def test_should_raise_method_not_defined_if_you_use_a_now_nonexistent_ch_method
    user = create_user!
    user_preference = UserDisplayPreference.default_for(user)
    assert_raises NoMethodError do
      user_preference.ch_cards_grid
    end
  end

  def test_preferences_display_preference_is_defaulted_to_an_empty_hash
     assert_equal Hash.new, UserDisplayPreference.default_for(@member_user)[:preferences]
  end

  def test_can_store_user_preferences
    login_as_bob
    UserDisplayPreference.current_user_prefs.update_preference(:card_flyout_display, "murmurs")
    User.current.reload
    assert_equal "murmurs", UserDisplayPreference.current_user_prefs.read_preference(:card_flyout_display)
  end

  def test_prevents_usage_of_ar_update_attributes_method
    login_as_bob
    assert_raises(RuntimeError) { UserDisplayPreference.current_user_prefs.update_attributes(:sidebar_visible => true) }
    assert_raises(RuntimeError) { UserDisplayPreference.current_user_prefs.update_attribute(:sidebar_visible, true) }
  end

  def test_can_update_multiple_preferences
    login_as_bob
    UserDisplayPreference.current_user_prefs.update_preferences({:sidebar_visible => true, :card_flyout_display => "none"})
    User.current.reload
    assert_equal true, UserDisplayPreference.current_user_prefs.read_preference(:sidebar_visible)
    assert_equal "none", UserDisplayPreference.current_user_prefs.read_preference(:card_flyout_display)
  end

  def test_should_create_project_preference
    @project = first_project
    login_as_bob
    UserDisplayPreference.current_user_prefs.update_project_preference(@project,:slack_murmur_notification, true)
    User.current.reload

    assert UserDisplayPreference.current_user_prefs.read_project_preference(@project, :slack_murmur_notification)
  end

  def test_should_update_project_preference
    @project = first_project
    login_as_bob
    UserDisplayPreference.current_user_prefs.update_project_preference(@project,:slack_murmur_notification, true)
    UserDisplayPreference.current_user_prefs.update_project_preference(@project,:slack_murmur_notification, false)
    User.current.reload

    assert !UserDisplayPreference.current_user_prefs.read_project_preference(@project, :slack_murmur_notification)
  end

  def test_default_project_preference_should_be_true_when_project_preference_does_not_exist
    @project = first_project
    login_as_bob
    User.current.reload
    assert_nil UserDisplayPreference.current_user_prefs.read_preference(@project.id)
    assert UserDisplayPreference.current_user_prefs.read_project_preference(@project, :slack_murmur_notification)
  end
end
