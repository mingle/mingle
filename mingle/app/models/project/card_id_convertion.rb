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

class Project
  module CardIdConvertion
    def card_id_to_number(card_id)
      card_id_to('number', card_id)
    end

    def card_id_to_name(card_id)
      card_id_to('name', card_id)
    end

    def card_number_to_name(card_number)
      card_number_to('name', card_number)
    end

    def card_number_to_id(card_number)
      card_number_to('id', card_number)
    end

    def card_name_to_id(name)
      return if name.blank?
      key = "card-name-id-#{id}-#{name.md5}"
      id = ThreadLocalCache.get(key) do
        Cache.get(key) do
          cards.find(:first, :select => 'id', :conditions => ["LOWER(name) = ?", name.downcase]).try(:id) || -1
        end
      end
      id == -1 ? nil : id
    end

    private
    def card_id_to(column, card_id)
      connection.select_value(SqlHelper.sanitize_sql(
        "SELECT #{connection.quote_column_name column} from #{Card.quoted_table_name} WHERE project_id = ? AND id = ? ", self.id, card_id)).to_s
    end
    memoize :card_id_to

    def card_number_to(column, card_number)
      return nil unless card_number.numeric?
      connection.select_value(SqlHelper.sanitize_sql(
        "SELECT #{connection.quote_column_name column} from #{Card.quoted_table_name} WHERE project_id = ? AND #{connection.quote_column_name('number')} = ? ", self.id, card_number))
    end
    memoize :card_number_to
  end
end
