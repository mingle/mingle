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

module AttachmentChangesGenerator
  
  private
  
  def generate_changes_for_attachments(version, prev)
    added = version.attachment_changes_against(prev)
    removed = prev.attachment_changes_against(version)
    replaced = added.select {|attachment| removed.any? {|removed_attachemt| removed_attachemt.file_name == attachment.file_name ? attachment : nil}}.compact
      
    replaced.each { |replaced_attachment| changes.create_attachment_replaced_change(replaced_attachment) }
    attachments_without_replaced(added, replaced) {|attachment| changes.create_attachment_added_change(attachment)}
    attachments_without_replaced(removed, replaced) {|attachment| changes.create_attachment_removed_change(attachment)}
  end
  
  def attachments_without_replaced(attachments, replaced_attachments)
    attachments.each do |attachment| 
      yield(attachment) unless replaced_attachments.any? {|replaced_attachment| replaced_attachment.file_name == attachment.file_name}
    end
  end
  
end
