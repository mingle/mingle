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

module Dependency::IndexableDependencyMethods

  def number_and_name
    "##{prefixed_number} #{name}"
  end

  def raised_by_project
    raising_project.name
  end

  def resolved_by_project
    resolving_project ? resolving_project.name : ""
  end

  def raised_by_card
    raising_card.number_and_name
  end

  def resolved_by_cards
    cards = []
    columns = %w(number name).map{|c| Dependency.connection.quote_column_name(c)}.join(",")
    return cards unless resolving_project
    resolving_project.with_active_project do |project|
      dependency_resolving_cards.find_each do |drc|
        cards << project.cards.find_by_number(drc.card_number, :select => columns).number_and_name
      end
    end
    cards
  end
end
