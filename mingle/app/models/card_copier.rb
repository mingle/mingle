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

PropertyDefinition
class PropertyDefinition
  def allow_copy?(target_project=nil)
    true
  end

  def value_copiable?(card, other)
    true
  end

  def copy_property_fits?(target_property)
    self.same_name_as?(target_property) && copy_property_type_fits?(target_property)
  end

  def same_name_as?(target_property)
    self.name.downcase == target_property.name.downcase
  end

  protected

  def copy_property_type_fits?(target_property)
    self.class == target_property.class
  end
end

UserPropertyDefinition
class UserPropertyDefinition
  def allow_copy?(target_project=nil)
    true
  end

  def value_copiable?(card, other)
    return true unless user = self.value(card)
    other.project.member?(user)
  end
end

FormulaPropertyDefinition
class FormulaPropertyDefinition
  def allow_copy?(target_project=nil)
    false
  end
end

AggregatePropertyDefinition
class AggregatePropertyDefinition
  def allow_copy?(target_project=nil)
    false
  end
end

AssociationPropertyDefinition
class AssociationPropertyDefinition
  def allow_copy?(target_project=nil)
    target_project.present? && target_project == project
  end
end

EnumeratedPropertyDefinition
class EnumeratedPropertyDefinition
  def value_copiable?(card, target_property_definition)
    target_property_definition.contains_value?(self.value(card)) || target_property_definition.support_inline_creating?
  end

  def copy_property_fits?(target_property)
    self.same_name_as?(target_property) && copy_property_type_fits?(target_property)
  end

  protected

  def copy_property_type_fits?(target_property)
    self.class == target_property.class && self.numeric? == target_property.numeric?
  end
end


class CardCopier
  attr_reader :never_copiable_properties, :setting_to_not_set_properties

  include AttachmentNameUniqueness

  def initialize(card, target_project)
    @card, @target_project = card, target_project
    @within_same_project = (card.project == target_project)
    calculate
  end

  def within_same_project?
    @within_same_project
  end

  def never_copiable_properties_for(property_definition_class)
    @never_copiable_properties[property_definition_class]
  end

  def setting_to_not_set_properties_for(property_definition_class)
    @setting_to_not_set_properties[property_definition_class]
  end

  def hidden_properties_that_will_be_copied
    @copy_property_mappings.map(&:first).find_all(&:hidden?)
  end

  def missing_attachments
    @card.attachments.find_all(&:file_missing?)
  end

  def copy_to_target_project
    property_values = @copy_property_mappings.inject({}) do |acc, (from, to)|
      acc[to.column_name] = from.db_identifier(@card)
      acc
    end

    file_name_remapping = {}

    attachment_files = @card.attachments.map do |attachment|
      copy_file(attachment).tap do |new_file|
        file_name_remapping[attachment.file_name] = File.basename(new_file.original_filename) if new_file.present?
      end
    end.compact

    new_card = nil
    @target_project.with_active_project do |target|

      new_name = within_same_project? ? "Copy of #{@card.name}" : @card.name

      new_description = @card.description.blank? ? @card.description : file_name_remapping.inject(@card.description.dup) do |result, old_new_mapping|
        old_filename, new_filename = old_new_mapping
        link_substitution = '[[\1\2 ' + new_filename + ']]' # the space after '\2' is to ensure that a filename starting with a number will not clobber the captured group
        image_substitution = "!#{new_filename}!"
        result.gsub(/(?:\[\[)\s*(?:(.+)\s*(\|)\s*)?(#{Regexp.escape(old_filename)})\s*(?:\]\])/, link_substitution).gsub(/((?:\!)(#{Regexp.escape(old_filename)})(?:\!))/, image_substitution)
      end

      new_card = target.cards.build property_values.merge(:name => new_name, :card_type_name => @card.card_type_name, :description => new_description)
      tags = @card.tags.map(&:name)
      new_card.tag_with(tags) if tags.any?
      new_card.attach_files(*attachment_files) if attachment_files.any?

      new_card.save

      @card.checklist_items.find_each do |cl|
        new_card.checklist_items.create! :text => cl.text, :completed => cl.completed, :position => cl.position, :project_id => target.id
      end

      ProjectCacheFacade.instance.clear_cache(target.identifier) unless within_same_project?
    end
    fire_events(@card, new_card)
    new_card
  end

  protected

  def fire_events(source_card, destination_card)
    Event.with_project_scope(source_card.project_id, destination_card.created_at, destination_card.created_by_user_id) do
      Event.card_copy(source_card, destination_card, CardCopyEvent::To)
    end
    Event.with_project_scope(destination_card.project_id, destination_card.created_at, destination_card.created_by_user_id) do
      Event.card_copy(destination_card, source_card, CardCopyEvent::From)
    end
  end

  def calculate
    source_properties = @card.card_type.property_definitions_with_hidden
    target_properties = if card_type_with_matching_name = @target_project.card_types.find_by_name(@card.card_type.name)
      @target_project.with_active_project { card_type_with_matching_name.property_definitions_with_hidden }
    else
      []
    end

    never_copiable_properties, setting_to_not_set_properties, @copy_property_mappings = [], [], []
    source_properties.each do |source_property|
      never_copiable_properties << source_property           and next if !source_property.allow_copy?(@target_project)

      target_property_by_name = target_properties.find { |target_property| source_property.same_name_as?(target_property) }
      next if target_property_by_name.nil? || !source_property.copy_property_fits?(target_property_by_name)

      setting_to_not_set_properties << source_property       and next if !source_property.value_copiable?(@card, target_property_by_name)

      @copy_property_mappings << [ source_property, target_property_by_name ]
    end

    @never_copiable_properties = group_by_property_type(never_copiable_properties)
    @setting_to_not_set_properties = group_by_property_type(setting_to_not_set_properties)
  end

  def group_by_property_type(property_definitions)
    property_definitions.smart_sort_by(&:name).group_by_with_default([], &:class)
  end

  def copy_file(attachment)
    path = attachment.file
    return unless attachment.file_exists?
    filename = ensure_unique_filename_in_project(target_filename(path), @target_project)
    Tempfile.new(filename).tap do |temp|
      attachment.file_copy_to(temp.path)
      temp.class_eval do
        define_method(:original_filename) { filename }
      end
    end
  end

  def target_filename(path)
    filename = File.basename(path)

    # append copy_{1..integer limit} to the filename when within same project, incrementing as appropriate
    if within_same_project?
      # tarballs are special
      ext = path.downcase.end_with?(".tar.gz") ? ".tar.gz" : File.extname(path)
      basename = File.basename(path, ext)

      if basename =~ /(.+)_copy_(\d+)$/
        num = $2.to_i
        filename = "#{$1}_copy_#{num + 1}#{ext}"
      else
        filename = "#{basename}_copy_1#{ext}"
      end

    end
    filename
  end

end
