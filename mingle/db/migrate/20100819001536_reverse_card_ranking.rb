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

class M20100819001536Project < ActiveRecord::Base
  include MigrationHelper
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  
  def card_table_name
    safe_table_name(CardSchema.generate_cards_table_name(self.identifier))
  end
  
end

class ReverseCardRanking < ActiveRecord::Migration
  class << self
    def up
      reverse_rank
    end

    def down
      reverse_rank
    end

    def reverse_rank
      M20100819001536Project.all.each do |project|
        max_rank = ActiveRecord::Base.connection.select_value("SELECT max(project_card_rank + 1) FROM #{project.card_table_name}")
        ActiveRecord::Base.connection.execute(<<-SQL)
          UPDATE #{project.card_table_name}
          SET project_card_rank = #{max_rank} - project_card_rank
        SQL
      end
    end
  end
end
