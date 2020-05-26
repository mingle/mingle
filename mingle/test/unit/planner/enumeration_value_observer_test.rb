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

class EnumerationValueObserverTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_reorder_enumeration_value_updates_work_completion_status
    with_sp_first_project do |project|
      first_card = project.cards.find_by_number(1)
      first_card.update_attributes(:cp_status => 'closed')
      second_card = project.cards.find_by_number(2)
      second_card.update_attributes(:cp_status => 'new')

      @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'open')
      @plan.assign_cards(sp_first_project, [1, 2], @program.objectives.first)
      assert @plan.works.created_from_card(first_card).first.completed?
      assert_false @plan.works.created_from_card(second_card).first.completed?

      status_prop_def = sp_first_project.find_property_definition('status')
      new_value, open_value, in_progress_value, closed_value = status_prop_def.enumeration_values
      status_prop_def.reorder [closed_value, in_progress_value, open_value, new_value]
      assert_false @plan.works.created_from_card(first_card).first.completed?
      assert @plan.works.created_from_card(second_card).first.completed?
    end
  end
  
  def test_reorder_enumeration_value_updates_work_completion_status_in_objective_snapshot
    with_sp_first_project do |project|
      @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')
      first_card = project.cards.find_by_number(1)
      first_card.update_attributes(:cp_status => 'closed')
      second_card = project.cards.find_by_number(2)
      second_card.update_attributes(:cp_status => 'open')

      today = Clock.today
      Clock.fake_now((today + 1).to_s)
      
      objective = @program.objectives.planned.create!({:name => 'objective new day', :start_at => today - 1, :end_at => today + 2})
      @plan.assign_cards(sp_first_project, [1, 2], objective)
      ObjectiveSnapshot.rebuild_snapshots_for(objective.id, project.id)
      assert_equal 1, ObjectiveSnapshot.find_by_dated(today).completed

      status_prop_def = sp_first_project.find_property_definition('status')
      new_value, open_value, in_progress_value, closed_value = status_prop_def.enumeration_values

      with_messaging_enable do
        status_prop_def.reorder [closed_value, in_progress_value, open_value, new_value]
        assert_equal(1, Messaging::Mailbox.instance.pending_mails.size)
        assert_equal(["mingle.rebuild.snapshots"], Messaging::Mailbox.instance.pending_mails.recipients)
      end

      ObjectiveSnapshot.rebuild_snapshots_for(objective.id, project.id)
      assert_equal 2, ObjectiveSnapshot.find_by_dated(today).completed
    end
  ensure
    Clock.reset_fake
  end


end
