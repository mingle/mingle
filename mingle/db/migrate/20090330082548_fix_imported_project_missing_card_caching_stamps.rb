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

class FixImportedProjectMissingCardCachingStamps < ActiveRecord::Migration
  include MigrationHelper

  class M165Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"

    def card_table_name
      CardSchema.generate_cards_table_name(self.identifier)
    end
  end

  def self.up
    select_columns = [ActiveRecord::Base.connection.quote_column_name('id')]
    insert_columns = [ActiveRecord::Base.connection.quote_column_name('card_id')]
    if ActiveRecord::Base.connection.prefetch_primary_key?
      select_columns.unshift(ActiveRecord::Base.connection.next_id_sql(safe_table_name("card_caching_stamps")))
      insert_columns.unshift('id')
    end
    
    M165Project.find(:all).each do |project|
      execute %{ INSERT INTO #{safe_table_name("card_caching_stamps")} (#{insert_columns.join(', ')}) 
                 SELECT #{select_columns.join(', ')} FROM #{safe_table_name(project.card_table_name)} WHERE id NOT IN (SELECT card_id FROM #{safe_table_name("card_caching_stamps")}) }
    end
  end

  def self.down
  end
end
