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

#tags:
class MultiMemberSelectionTest < ActiveSupport::TestCase

  def setup
    @member = login_as_member
  end

  def test_extract_should_return_smart_sorted_results
    with_new_project do |project|
      project.add_member(@member)
      dev = setup_user_definition 'dev'
      owner = setup_user_definition 'owner'
      create_card!(:name => '1', :dev => @member.id, :owner => @member.id)
      assert_equal ['dev', 'owner'], select_all_members(project).property_usages
    end
  end

  def select_all_members(project)
    MultiMemberSelection.for_user_selection(project, project.users.map(&:id))
  end

  def test_extract_should_return_transitions_used
    with_first_project do |project|
      create_transition(project, 'open', :set_properties => {:status => 'open', :dev => @member.id})
      create_transition(project, 'close', :set_properties => {:status => 'close', :dev => @member.id})
      assert_equal ['close', 'open'], select_all_members(project).transitions_used
    end
  end

  def test_extract_should_return_transitions_specified
    with_first_project do |project|
      transition_open = create_transition(project, 'open', :set_properties => {:status => 'open'}, :user_prerequisites => [@member.id])
      transition_close = create_transition(project, 'close', :set_properties => {:status => 'close'}, :user_prerequisites => [@member.id])
      assert_equal ['close', 'open'], select_all_members(project).transitions_specified
    end
  end

  def test_extract_should_return_sorted_and_uniq_card_defaults
    with_new_project do |project|
      project.add_member(@member)
      dev = setup_user_definition 'dev'
      owner = setup_user_definition 'owner'

      card_defaults_one = project.card_types.first.card_defaults
      card_defaults_one.update_properties :dev => @member.id, :owner => @member.id
      card_defaults_one.save!

      card_defaults_two = project.card_types.create(:name => 'Story').card_defaults
      card_defaults_two.update_properties :dev => @member.id, :owner => @member.id
      card_defaults_two.save!

      assert_equal ['Card', 'Story'], select_all_members(project).card_defaults_usages
    end
  end
end
