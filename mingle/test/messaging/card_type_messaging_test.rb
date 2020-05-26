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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

# Tags: messaging, history, indexing
class CardTypeMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
  def test_removing_property_defs_will_generate_new_versions_of_cards_with_values_that_are_now_not_applicable
    with_new_project do |project|
      login_as_admin
      setup_property_definitions(:release => ['1','2'], :status => ['new', 'open'], :priority => ['low', 'high'])
      setup_card_type(project, 'story', :properties => ['release', 'status', 'priority'])
      setup_card_type(project, 'bug', :properties => ['release', 'status', 'priority'])
   
      story = project.cards.create!(:card_type_name => 'story', :name => 'story', :cp_release => '1', :cp_status => 'new', :cp_priority => 'high')
      bug_1 = project.cards.create!(:card_type_name => 'bug', :name => 'bug 1', :cp_release => '1', :cp_status => 'new', :cp_priority => 'low')
      bug_2 = project.cards.create!(:card_type_name => 'bug', :name => 'bug 2', :cp_release => '2', :cp_status => 'open', :cp_priority => 'high')
  
      bug = project.find_card_type('bug')
      bug.property_definitions = [project.find_property_definition('status')]  # remove release and priority from bug
      bug.save!
      
      HistoryGeneration.run_once
      FullTextSearch.run_once
  
      assert_equal '1', story.reload.cp_release
      assert_equal 'high', story.cp_priority
    
      assert_nil bug_1.reload.cp_release
      assert_nil bug_1.cp_priority
      assert_equal 'new', bug_1.cp_status
      assert_equal 2, bug_1.versions.size
      assert_contains_change(bug_1.versions.last, 'release', '1', nil)
      assert_contains_change(bug_1.versions.last, 'priority', 'low', nil)

      assert_nil bug_2.reload.cp_release
      assert_nil bug_2.cp_priority
      assert_equal 'open', bug_2.cp_status
      assert_equal 2, bug_2.versions.size
      assert_contains_change(bug_2.versions.last, 'release', '2', nil)
      assert_contains_change(bug_2.versions.last, 'priority', 'high', nil)
    end
  end
  
  def assert_contains_change(version, field, old_value, new_value)
    change = version.changes.detect{|change| change.field == field}
    assert_equal old_value, change.old_value
    assert_equal new_value, change.new_value
  end
end
