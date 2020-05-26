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
class CardsPlansHelperTest < ActiveSupport::TestCase
  include CardsPlansHelper
  
  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_programs_associated_with_project
    sp_first_project.with_active_project do |project|
      assert_equal ['simple program'], programs(project).map(&:name)
    end
  end

  def test_returns_the_objectives_that_a_card_is_associated_with_if_exists
    sp_first_project.with_active_project do |project|
      card = project.cards.find_by_number 1
      @plan.assign_cards(project, [1], @program.objectives.find_by_name('objective a'))
      @plan.assign_cards(project, [1], @program.objectives.find_by_name('objective b'))
      assert_equal ['objective a', 'objective b'], plan_objectives_of_card(@plan, card).map(&:name).sort
    end
  end
  
  def test_returns_blank_when_a_card_is_not_associated_with_any_objective
    sp_first_project.with_active_project do |project|
      card = project.cards.find_by_number 1
      assert_equal [], plan_objectives_of_card(@plan, card).map(&:name)
    end 
  end

  def test_plan_objectives_for_ui_should_fill_in_not_set_when_given_objectives_are_blank
    sp_first_project.with_active_project do |project|
      card = project.cards.find_by_number 1
      assert_equal ['objective'], plan_objectives_for_ui(['objective'])
      assert_equal ['(not set)'], plan_objectives_for_ui([]).map(&:name)
    end 
  end

  def test_overwrite_card_objective_info_by_given_plan_objectives_map
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    sp_first_project.with_active_project do |project|
      card = project.cards.find_by_number 1
      @plan.assign_cards(project, [1], objective_b)

      assert_equal ['objective b'], plan_objectives_of_card(@plan, card).map(&:name)
      assert_equal [], plan_objectives_of_card(@plan, card, {@plan.id.to_s => nil}).map(&:name)
      assert_equal [], plan_objectives_of_card(@plan, card, {@plan.id.to_s => ''}).map(&:name)
      assert_equal [], plan_objectives_of_card(@plan, card, {@plan.id.to_s => '2323423423423'}).map(&:name)
      assert_equal ['objective a', 'objective b'], plan_objectives_of_card(@plan, card, {@plan.id.to_s => [objective_a, objective_b].map(&:id).join(',')}).map(&:name).sort
    end
  end

  def test_have_objectives_available_for_selection_when_there_is_objective_no_autosync_with_project
    project = sp_first_project
    assert_false no_objectives_available_for_selection?(@plan, project)

    objectives = @program.objectives
    objectives[0].filters.create!(:project => project, :params => {:filters => ["[number][is][1]"]})
    objectives[1].filters.create!(:project => project, :params => {:filters => ["[number][is][1000]"]})
    objectives[2].filters.create!(:project => project, :params => {:filters => ["[number][is][1]"]})

    assert no_objectives_available_for_selection?(@plan.reload, project)
    @program.objectives.each(&:destroy)
    assert no_objectives_available_for_selection?(@plan.reload, project)
  end
end
