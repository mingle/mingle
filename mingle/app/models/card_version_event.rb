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

# event that presenting card creation or changes (card deletion is in CardDeletionEvent)
class CardVersionEvent < Event
  include AttachmentChangesGenerator
  include Messaging::MessageProvider
  include PushableNotificationEmitter

  def do_generate_changes(options = {})
    return unless origin

    changes.destroy_all
    card_version = origin
    prev = card_version.first? ? Card::Version::NULL.extend(ActiveRecord::Acts::Attachable::InstanceMethods) : card_version.previous
    changes.create_name_change(prev.name, card_version.name) if prev.name != card_version.name

    old_card_type = prev.card_type.nil? ? nil : prev.card_type.name
    changes.create_card_type_change(old_card_type, card_version.card_type.name) if old_card_type != card_version.card_type.name
    changes.create_description_change if prev.description.to_s != card_version.description.to_s
    changes.create_comment_change(card_version.comment) unless card_version.comment.blank?
    changes.create_system_generated_comment_change(card_version.system_generated_comment) unless card_version.system_generated_comment.blank?

    prop_defs = options[:property_definitions] || all_properties
    prop_defs.each do |definition|
      next if definition.aggregated?
      column_name = definition.column_name
      prev_value = prev[column_name]
      card_version_value = card_version[column_name]
      if (prev_value != card_version_value)
        prev_value = prev_value.strftime('%Y-%m-%d') if prev_value.is_a?(Date) || prev_value.is_a?(Time)
        card_version_value = card_version_value.strftime('%Y-%m-%d') if card_version_value.is_a?(Date) || card_version_value.is_a?(Time)
        changes.create_property_change(definition.name, prev_value, card_version_value)
      end
    end

    (card_version.tags - prev.tags).each { |added_tag| changes.create_tag_addition_change(added_tag) }
    (prev.tags - card_version.tags).each { |removed_tag| changes.create_tag_deletion_change(removed_tag) }
    generate_changes_for_attachments(card_version, prev)
  end

  def all_properties
    PropertyDefinition.find(:all, :conditions => ["project_id = #{project.id}"])
  end

  def origin_description
    origin ? origin.short_description : "Deleted card"
  end

  def source_type
    'card'
  end

  def source_link
    origin.card_resource_link if origin
  end

  def version_link
    origin.resource_link if origin
  end

  def snapshot
    if ("deleted" == action_description)
      return {
        :Number => origin.number
      }
    end

    origin.card_snapshot
  end

end
