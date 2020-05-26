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

require File.expand_path(File.join(File.dirname(__FILE__), '20090430225248_deleted_orphaned_attachings_and_attachments'))

# WARNING: THIS MIGRATION MUST BE KEPT IN SYNC WITH MIGRATION 20090430225248_deleted_orphaned_attachings_and_attachments.rb.
# 
# This migration exists purely because of of ticket http://twstudios.zendesk.com/tickets/1034
# The customer, while on Mingle 2.2, provided an export file m-13.mingle and reporting an AR error:
#        ActiveRecord::ActiveRecordError: Column 'attachable_id' cannot be null: 
#        INSERT INTO `attachings` 
#        (`attachment_id`,`attachable_id`,`attachable_type`) 
#        VALUES (1,NULL,'Card')
# Mike was then able to reproduce it locally, and the migration fix 20090430225248_deleted_orphaned_attachings_and_attachments.rb for this problem
# was at the time only for PostgreSQL and not MySQL, which the customer was using. Mike therefore release to them a patch to update this migration
# such that when they upgrade from 2.2 to 2.3.1, they will be able to import this m-13.mingle file.
# 
# However, the customer in the mean time has already upgraded their Mingle instance, and has generated a new export file m-15.mingle. The customer
# then subsequently dropped in Mike's migration patch file, and try to import this new m-15.mingle file. However, since the new m-15.mingle file
# has already had its migration 20090430225248 run, the patched migration will obviously not run.
#
# The solution is, create a new migration in trunk (3.0) that replicates exactly the content of the patched migration
# 20090430225248_deleted_orphaned_attachings_and_attachments.rb, and then send this newly generated migration to the customer, so that their table
# schema_migrations will not be left with anything that only exists for them but not to anyone else.

class SupportCase1034MigrationRerun < ActiveRecord::Migration
  extend DeletedOrphanedAttachingsAndAttachments::MigrationContent
  
  def self.up
    DeletedOrphanedAttachingsAndAttachments.up
  end
  
  def self.down
    DeletedOrphanedAttachingsAndAttachments.down
  end
end
