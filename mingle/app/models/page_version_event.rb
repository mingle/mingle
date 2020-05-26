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

class PageVersionEvent < Event
  include Messaging::MessageProvider

  include AttachmentChangesGenerator

  def do_generate_changes(options = {})
    return if origin.nil?
    changes.destroy_all
    page_version = origin
    prev = page_version.first? ? Page::Version::NULL.extend(ActiveRecord::Acts::Attachable::InstanceMethods) : page_version.previous
    changes.create_name_change(prev.name, page_version.name) if prev.name != page_version.name
    changes.create_description_change('Content') if prev.content.to_s != page_version.content.to_s
    (page_version.tags - prev.tags).each { |added_tag| changes.create_tag_addition_change(added_tag) }
    (prev.tags - page_version.tags).each { |removed_tag| changes.create_tag_deletion_change(removed_tag) }
    generate_changes_for_attachments(page_version, prev)
  end

  def origin_description
    origin.nil? ? "Deleted page" : "Page #{self.origin.name}"
  end

  def action_description
    origin.nil? ? "" : super
  end

  def source_type
    'page'
  end

  def source_link
    origin.page_resource_link unless origin.nil?
  end

  def version_link
    origin.resource_link unless origin.nil?
  end
end
