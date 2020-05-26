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

class RenameProjectIdentifierColumnOnAsyncRequestsTableRerun < ActiveRecord::Migration
  #Re-running migration 20120820184628 as it was added on the 12_2_2 branch and may have a timestamp earlier than the current migration. Which means it maynot run when an installation with the 12_2_2 branch is upgraded.

  def self.up
    unless column_exists? :asynch_requests, :deliverable_identifier
      rename_column :asynch_requests, :project_identifier, :deliverable_identifier
    end
    AsynchRequest.reset_column_information
  end

  def self.down
    unless column_exists? :asynch_requests, :project_identifier
      rename_column :asynch_requests, :deliverable_identifier, :project_identifier
    end
  end
end
