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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

#Tags: help
class Scenario164ShowContextualHelpTest< ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_admin_user
    @project = create_project(:prefix => 'scenario_164')
    UserDisplayPreference.destroy_all
  end

  def test_first_visit_to_list_view_should_have_hidden_contextual_help_but_not_on_maximized_view
    @project.with_active_project do |project|
      create_card!(:name => 'one', :card_type_name => project.card_types.first.name)
    end
    navigate_to_a_card_view("list")
    assert_contextual_help_is_invisible
    show_contextual_help
    assert_contextual_help_is_visible
    hide_contextual_help
    assert_contextual_help_is_invisible
    show_contextual_help
    assert_contextual_help_is_visible
    maximize_current_view
    assert_contextual_help_is_invisible
  end
end
