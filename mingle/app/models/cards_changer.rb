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

module CardsChanger
  def self.included(base)
    base.class_eval do
      class << self
        include Observable
      end
    end
  end
  
  def notify_cards_changing(project)
    self.class.changed
    self.class.notify_observers(project)
  end

  def notify_before_cards_destroy(project, card_id_criteria)
    self.class.changed
    self.class.notify_observers(project, card_id_criteria)
  end

  def notify_cards_properties_changing(project, card_id_criteria, property_name_and_values)
    self.class.changed
    self.class.notify_observers(project, card_id_criteria, property_name_and_values)
  end
end
