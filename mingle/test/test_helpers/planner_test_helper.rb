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

module PlannerTestHelper
  def program(identifier)
    if program = Program.find_by_identifier(identifier)
      program
    elsif identifier == 'simple_program'
      script = File.expand_path("../data/load_project", File.dirname(__FILE__))
      system("ruby #{script} simple_program")
      Program.find_by_identifier(identifier)
    end
  end

  def create_planned_objective(program, attributes={})
    default_attributes = {:name => 'objective a', :start_at => Clock.now, :end_at => 2.days.from_now(Clock.now)}
    program.objectives.planned.create!(default_attributes.merge(attributes))
  end

  def create_simple_objective(attributes={})
    plan = create_program.plan
    projects = attributes.delete(:projects)
    plan.program.projects << projects if projects.present?
    create_planned_objective(plan.program, attributes)
  end

  def create_program(identifier='prog'.uniquify[0..20])
    Program.create!(:identifier => identifier, :name => identifier)
  end

  def create_objective_type(name='obj_type'.uniquify[0..20], value_statement='some text', program_id)
    ObjectiveType.create!(:name => name, :value_statement => value_statement, :program_id => program_id)
  end

  def with_project_cards(project)
    cards = project.with_active_project { |project| project.cards.to_a }
    yield(cards)
  end

  def assign_project_cards(objective, project)
    with_project_cards(project) do |cards|
      if block_given?
        objective.program.plan.assign_cards(project, yield(cards).collect(&:number), objective)
      else
        objective.program.plan.assign_cards(project, cards.collect(&:number), objective)
      end
    end
  end

  def assign_all_work_to_new_objective(program, project)
    program.projects << project
    objective = create_planned_objective(program)
    assign_project_cards(objective, project)
  end

  def update_card_properties(project, properties)
    project.with_active_project do |project|
      card = project.cards.find_by_number(properties.delete(:number))
      card.update_properties(properties)
      card.save!
    end
  end

  def export_file(name)
    File.join(Rails.root, 'test', 'data', 'program_exports', name)
  end

end
