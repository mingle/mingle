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

class M126SubversionConfiguration < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}subversion_configurations"
end

class RenameInvalidRevisionsFlag < ActiveRecord::Migration 
  
  def self.up
    add_column :subversion_configurations, :initialized, :boolean
    M126SubversionConfiguration.reset_column_information
    M126SubversionConfiguration.find(:all).each do |config|
      initialized = config.revisions_invalid.nil? || !config.revisions_invalid
      config.update_attribute(:initialized, initialized)
    end
    remove_column :subversion_configurations, :revisions_invalid
    M126SubversionConfiguration.reset_column_information
    SubversionConfiguration.reset_column_information
  end

  def self.down
    add_column :subversion_configurations, :revisions_invalid, :boolean
    M126SubversionConfiguration.reset_column_information
    M126SubversionConfiguration.find(:all).each do |config|
      revisions_invalid = config.initialized.nil? || !config.initialized
      config.update_attribute(:revisions_invalid, revisions_invalid)
    end
    remove_column :subversion_configurations, :initialized
    M126SubversionConfiguration.reset_column_information
    SubversionConfiguration.reset_column_information
  end
end
