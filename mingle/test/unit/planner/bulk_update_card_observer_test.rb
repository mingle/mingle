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

class BulkUpdateCardObserverTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
    @project = sp_first_project
  end
  
  def test_should_update_work_completed_status_when_bulk_update_card_status
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    work = @plan.works.first
    assert !work.completed?

    @project.with_active_project do |project|
      card_selection = CardSelection.new(@project.reload, @project.cards.to_a)
      card_selection.update_property('status', 'closed')
      assert card_selection.errors.empty?
    end

    work.reload
    
    assert work.completed?

    @project.with_active_project do |project|
      card_selection = CardSelection.new(@project.reload, @project.cards.to_a)
      card_selection.update_property('status', 'new')
      assert card_selection.errors.empty?
    end

    work.reload
    assert !work.completed?
  end
  
  # bug 11947
  def test_completed_status_not_changed_by_bulk_update_other_property
    @project.with_active_project do |project|
      @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
      work = @plan.works.first
      
      card = @project.cards.find_by_number(1)
      card.update_properties(:status => 'closed')
      card.save!
      assert work.reload.completed?
      
      card_selection = CardSelection.new(@project.reload, @project.cards.to_a)
      card_selection.update_property('priority', 'low')
      assert card_selection.errors.empty?
      
      work.reload
      assert work.completed?
    end
  end
  
  def test_bulk_delete_card_should_delete_work
    objective = @program.objectives.first
    @plan.assign_cards(@project, [1, 2], objective)
    
    assert_equal 2, @plan.works.size
    
    @project.with_active_project do |project|
      card_to_delete = project.cards.to_a.first
      card_selection = CardSelection.new(project.reload, [card_to_delete])
      card_selection.destroy
      assert card_selection.errors.empty?
      
      assert @plan.works.find_all_by_card_number(card_to_delete.number).empty?
    end
  end
  
  def test_should_bulk_update_card_attributes_even_when_done_status_is_not_defined_on_program_project
    sp_second_project.with_active_project do |project|
      @plan.assign_cards(project, 1, @program.objectives.first)
      work = @plan.works.first
      assert_false work.completed?

      card = project.cards.find_by_number(1)
      card.update_properties(:status => 'closed')
      card.save!
      assert_equal 'closed', card.cp_status

      card_selection = CardSelection.new(project.reload, project.cards.to_a)
      card_selection.update_property('priority', 'low')
      assert card_selection.errors.empty?

      work.reload
      assert_false work.completed?
    end
  end

end
