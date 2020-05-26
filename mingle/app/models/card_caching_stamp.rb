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

class CardCachingStamp
  class << self
    def expiry
      12.hours
    end

    def stamp(id)
      Cache.get(key(id), expiry) { generate }
    end

    def update(card_ids)
      case card_ids
      when String
        update(ActiveRecord::Base.connection.select_values("SELECT ID FROM #{Card.quoted_table_name} WHERE #{card_ids}"))
      when Array
        card_ids.each do |id|
          Cache.put(key(id), generate, expiry)
        end
      else
        raise "please passin card id array or a sql condition"
      end
    end

    def generate
      'stamp'.uniquify
    end

    def key(id)
      "card_caching_stamp/#{id}"
    end
  end

end
