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

class RemoveOrphanedTaggingsOnCardVersions < ActiveRecord::Migration
  def self.up
    # turn on to drop index on taggings table and recreate.
    # this might make inserting with large taggings data faster.
    # note that if this migration fails before indexes are recreated,
    # subsequent runs will not be able to recover any missing indexes.
    recreate_indexes_optimization = true

    taggings_table = safe_table_name('taggings')
    tags_table = safe_table_name('tags')
    temp_table = safe_table_name("temp_taggings")

    indexes_to_recreate = ActiveRecord::Base.connection.indexes(taggings_table).inject({}) do |hash, i|
      hash[i.name] = i.columns
      hash
    end

    # Any row containing NULLs in any column is invalid
    execute("DELETE FROM #{taggings_table} WHERE tag_id IS NULL OR taggable_id IS NULL OR taggable_type IS NULL")

    # drop temp table in case it exists from a previously unsuccessful run
    drop_table('temp_taggings') if table_exists?('temp_taggings')

    # create a temporary table to build our good tagging set
    create_table 'temp_taggings', :force => true do |t|
      t.column "tag_id",        :integer
      t.column "taggable_id",   :integer
      t.column "taggable_type", :string
    end

    MigrationContent::M20090403Project.all.each do |project|
      p_id = project.id
      versions_table = safe_table_name(project.card_versions_table_name)

      # collect good taggings data for each project into our temp table
      execute <<-SQL
        INSERT INTO #{temp_table} (id, tag_id, taggable_id, taggable_type)
             SELECT tg.id, tg.tag_id, tg.taggable_id, tg.taggable_type
               FROM #{taggings_table} tg, #{tags_table} t, #{versions_table} v
              WHERE tg.taggable_type = 'Card::Version'
                AND tg.tag_id = t.id
                AND t.project_id = #{p_id}
                AND tg.taggable_id = v.id
      SQL
    end

    if recreate_indexes_optimization
      indexes_to_recreate.each_pair do |idx_name, columns|
        remove_index 'taggings', :name => idx_name
      end
    end

    execute("DELETE FROM #{taggings_table} WHERE taggable_type = 'Card::Version'")

    execute <<-SQL
      INSERT INTO #{taggings_table} (id, tag_id, taggable_id, taggable_type)
           SELECT id, tag_id, taggable_id, taggable_type
             FROM #{temp_table}
    SQL

    if recreate_indexes_optimization
      indexes_to_recreate.each_pair do |idx_name, columns|
        add_index 'taggings', columns, :name => idx_name
      end
    end

    # clean up our temp table
    drop_table 'temp_taggings'
  end

  def self.down
    # drop temp table in case it exists from a previously unsuccessful run
    drop_table('temp_taggings') if table_exists?('temp_taggings')
  end

  module MigrationContent
    include MigrationHelper

    class M20090403Project < ActiveRecord::Base
      set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
      def card_versions_table_name
        ActiveRecord::Base.connection.db_specific_table_name("#{identifier}_card_versions")
      end
    end
  end

  extend MigrationContent
end
