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

require File.join(File.dirname(__FILE__), '/../../lib/mingle_upgrade_compatibility/scm_data_migration_helper')

class UpdateScmConfigurations < ActiveRecord::Migration

  def self.up
    return unless MingleConfiguration.installer?

    UpdateScmRepository(GitConfiguration)
    UpdateScmRepository(HgConfiguration)
    UpdateScmRepository(TfsscmConfiguration)
    UpdateScmRepository(PerforceConfiguration)
    UpdateScmRepository(SubversionConfiguration)
  end

  def self.down
  end

  def self.UpdateScmRepository(scm_repo)
    return unless scm_repo.table_exists?

    scm_repo.find(:all).each do |scm_config|
      SCMDataMigrationHelper.migrate(scm_config)
    end
  end
end
