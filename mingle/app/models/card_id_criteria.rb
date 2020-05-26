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

class CardIdCriteria
  include SqlHelper
  
  NO_CARDS_CRITERIA = "= 1.5"
  
  class << self
    def no_cards_criteria
      CardIdCriteria.new(NO_CARDS_CRITERIA)
    end
    
    def from_cards(cards)
      CardIdCriteria.new("IN (#{cards_in(cards)})")
    end
    
    def cards_in(cards)
      cards.collect(&:id).join(',')
    end
  end
  
  def initialize(criteria_string)
    @card_id_criteria = criteria_string
  end
  
  def to_sql(full_column_name = "#{Card.quoted_table_name}.id")
    @card_id_criteria.gsub(/[?]/, full_column_name)
  end
  
  def and_not_in(criteria_string)
    CardIdCriteria.new("#{@card_id_criteria} AND ? NOT IN (#{criteria_string})")
  end
  
  def matches_no_cards_criteria?
    @card_id_criteria == NO_CARDS_CRITERIA
  end
  
  def update_from(cards)
    if (cards.size == 0 || matches_no_cards_criteria?)
      CardIdCriteria.no_cards_criteria
    else
      CardIdCriteria.new("#{@card_id_criteria} AND ? IN (#{CardIdCriteria.cards_in(cards)})")
    end
  end
end
