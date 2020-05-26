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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')

class CardsPlansControllerTest < ActionController::TestCase
  def setup
    @controller = CardsPlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_should_create_work_for_selected_objectives
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)

      put :assign_to_objectives, :project_id => project.identifier, :program_id => @program.to_param,
                                 :number => card.number, :selected_objectives => [objective_a.id, objective_b.id]
      assert_rjs :replace_html, "plan_#{@program.identifier}_objectives"

      assert_card_assigned(card, objective_a)
      assert_card_assigned(card, objective_b)
    end
  end

  def test_should_not_create_work_for_selected_objectives_when_in_editing_mode
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)

      put :assign_to_objectives, :project_id => project.identifier, :program_id => @program.to_param,
                                 :editing => 'true',
                                 :number => card.number, :selected_objectives => [objective_a.id, objective_b.id]
      assert_rjs :replace_html, "plan_#{@program.identifier}_objectives"

      assert_equal 0, objective_a.works.size
      assert_equal 0, objective_b.works.size
    end
  end

  def test_should_delete_work_for_deselected_objectives
    objective = @program.objectives.find_by_name('objective a')
    @plan.assign_cards(sp_first_project, [1], objective)
    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      put :assign_to_objectives, :project_id => project.identifier, :program_id => @program.to_param,
                                 :number => card.number, :selected_objectives => []
      assert_rjs :replace_html, "plan_#{@program.identifier}_objectives"
      assert objective.reload.works.empty?
    end
  end

  def assert_card_assigned(card, objective)
    assert_equal 1, objective.works.size, "Should have created a work item for the card assigned to this feature"
    work = objective.works.first
    assert_equal work.card_number, card.number
  end
end
