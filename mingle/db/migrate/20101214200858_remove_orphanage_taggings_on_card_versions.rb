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

require File.expand_path(File.join(File.dirname(__FILE__), '20090403202000_remove_orphaned_taggings_on_card_versions'))

# Support case #4494
# Customer is having issues with 'cannot insert NULL into (“MINGLE_APP_OWNER”.”TAGGINGS”.”TAGGABLE_ID”)'. This is due to taggings that should
#   have been deleted but still remain in the DB. The migration to fix such bad data already existed in an earlier migration. There is a 3.3
#   bug for it, bug #5512, which is attached with the problematic customer export.

class RemoveOrphanageTaggingsOnCardVersions < ActiveRecord::Migration
  extend RemoveOrphanedTaggingsOnCardVersions::MigrationContent
  
  def self.up
    RemoveOrphanedTaggingsOnCardVersions.up
  end

  def self.down
    RemoveOrphanedTaggingsOnCardVersions.down
  end
end
