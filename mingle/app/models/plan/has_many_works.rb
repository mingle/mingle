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

class Plan
  module HasManyWorks
    def assign_cards(project, cards, objective)
      project_cards = ProjectCards.new(project, cards)
      bulk_updater = Work::BulkUpdater.new(project, project_cards.criteria_not_in(objective))
      bulk_updater.insert(program.program_project(project), objective.id).tap do
        program.reload
      end
    end

    def assign_card_to_objectives(project, card, objectives)
      self.works.created_from_card(card).reject(&:auto_sync?).reject { |work| work.in(objectives) }.each(&:destroy)
      objectives.each do |objective|
        assign_cards(project, [card.number], objective)
      end
    end

    def work_completed?(card)
      program.program_project(card.project).completed?(card)
    end
  end
end
