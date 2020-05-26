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

class Work < ActiveRecord::Base
  class CardObserver < ActiveRecord::Observer
    observe Card
    
    on_callback(:after_update) do |card|
      Work.created_from_card(card).each do |work|
        work.copy_card(card)
        work.save! if work.changed?
      end
    end
    on_callback(:after_destroy) do |card|
      Work.delete_all(:project_id => card.project_id, :card_number => card.number)
    end

    CardObserver.instance
  end
end
