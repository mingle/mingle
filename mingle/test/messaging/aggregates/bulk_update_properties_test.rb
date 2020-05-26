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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../messaging_test_helper')

class BulkUpdatePropertiesTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper
  
  def test_bulk_updating_properties_only_sends_out_the_minimum_messages
    login_as_admin
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types
      size_property = setup_numeric_text_property_definition('nsize')
      aggregate = setup_aggregate_property_definition('task size sum for story', AggregateType::SUM, size_property, configuration.id, type_story.id, type_task)

      task1 = project.cards.find_by_name('task1')
      task2 = project.cards.find_by_name('task2')
      tasks = [task1, task2]
      tasks.each { |t| t.update_properties('nsize' => 4) }.each(&:save!)
      story1 = project.cards.find_by_name('story1')

      all_messages_from_queue('mingle.compute_aggregates.cards')

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (#{tasks.collect(&:id).join(',')})"))
      updater.update_properties({'nsize' => 2}, {:compute_aggregates_using_card_ancestors => true})
      card_ids = all_messages_from_queue('mingle.compute_aggregates.cards').collect { |m| m[:card_id] }
      assert_equal [story1.id], card_ids.sort
    end
  end
end
