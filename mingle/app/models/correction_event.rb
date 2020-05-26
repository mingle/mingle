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

class CorrectionEvent < Event
  include Messaging::MessageProvider

  has_many :changes, :foreign_key => "event_id", :class_name => "CorrectionChange"
  
  def self.create_for_repository_settings_change(project)
    create_for_project(project, project) do |event|
      event.changes.create(:change_type => 'repository-settings-change', :resource_1 => project.id)
    end
  end
  
  def self.create_for_project(project, origin, &block)
    with_project_scope(project.id, Clock.now.utc, User.current.id) do
      # This is cause we are using single table inheritance for Project and Plan
      # It is not a good solution, and we are open to change this solution
      event = if origin.is_a?(Project)
        create(:origin_id => origin.id, :origin_type => 'Project')
      else
        create(:origin => origin)
      end
      yield(event) if block_given?
    end    
  end
  
  def origin_description
    origin_type.constantize.model_name.underscore.humanize
  end

  def source_link
    origin_type == 'Project' ? project.resource_link :  origin_type.constantize.resource_link(nil, :id => origin_id)
  end
  
  def do_generate_changes
  end
  
  def source_type
    "feed-correction"
  end
  
  class EnumerationValueObserver < ActiveRecord::Observer
    observe EnumerationValue
    
    on_callback(:after_update) do |enumeration_value|
      if enumeration_value.value_changed?
        CorrectionEvent.create_for_project(enumeration_value.project, enumeration_value.property_definition) do |event|
          event.changes.create(
            :change_type => 'managed-property-value-change',
            :old_value => enumeration_value.changes["value"].first,
            :new_value => enumeration_value.changes["value"].last,
            :resource_1 => enumeration_value.property_definition.id
          )
        end
      end
    end
    self.instance
  end
  
  class PropertyDefinitionObserver < ActiveRecord::Observer
    observe PropertyDefinition
    
    on_callback(:after_update) do |property_definition|
      return unless property_definition.name_changed?
      return if property_definition.is_a?(AggregatePropertyDefinition)
      
      CorrectionEvent.create_for_project(property_definition.project, property_definition) do |event|
        event.changes.create(
              :change_type => 'property-rename',
              :old_value => property_definition.changes["name"].first, 
              :new_value => property_definition.changes["name"].last, 
              :resource_1 => property_definition.id
        )
      end
    end
    
    on_callback(:after_destroy) do |destroyed_property|
      CorrectionEvent.create_for_project(destroyed_property.project, destroyed_property) do |event|
        event.changes.create(
          :change_type => 'property-deletion',
          :resource_1 => destroyed_property.id
        )
      end
    end
    
    self.instance
  end
  
  class PropertyTypeMappingObserver < ActiveRecord::Observer
    observe PropertyTypeMapping
    on_callback(:after_destroy) do |removed_mapping|
      CorrectionEvent.create_for_project(removed_mapping.project, removed_mapping.card_type) do |event|
        event.changes.create(
          :change_type => 'card-type-and-property-disassociation',
          :resource_1 => removed_mapping.card_type.id,
          :resource_2 => removed_mapping.property_definition.id
        )
      end
    end
    self.instance
  end
  
  class TagObserver < ActiveRecord::Observer
    observe Tag
    on_callback(:after_update) do |tag|
      if tag.name_changed?
        CorrectionEvent.create_for_project(tag.project, tag) do |event|
          event.changes.create(
            :change_type => 'tag-rename',
            :old_value => tag.changes["name"].first, 
            :new_value => tag.changes["name"].last
          )
        end
      end
    end
    self.instance
  end
  
  class CardTypeObserver < ActiveRecord::Observer
    observe CardType
    
    on_callback(:after_update) do |card_type|
      if card_type.name_changed?
        CorrectionEvent.create_for_project(card_type.project, card_type) do |event|
          event.changes.create(
              :change_type => 'card-type-rename',
              :old_value => card_type.changes["name"].first,
              :new_value => card_type.changes["name"].last,
              :resource_1 => card_type.id
          )
        end
      end
    end
    on_callback(:after_destroy) do |deleted_card_type|
      CorrectionEvent.create_for_project(deleted_card_type.project, deleted_card_type) do |event|
        event.changes.create(
          :change_type => 'card-type-deletion',
          :resource_1 => deleted_card_type.id
        )
      end
    end
    
    self.instance
  end
  
  class ProjectObserver < ActiveRecord::Observer
    observe Project
    
    on_callback(:after_update) do |project|
      return if(!project.card_keywords_changed? && !project.precision_changed?)
      
      CorrectionEvent.create_for_project(project, project) do |event|
        event.changes.create(
            :change_type => 'card-keywords-change',
            :old_value => CardKeywords.new(project, project.changes["card_keywords"].first.to_s).to_s,
            :new_value => project.changes["card_keywords"].last.to_s,
            :resource_1 => project.id
        ) if project.card_keywords_changed?
        event.changes.create(
            :change_type => 'numeric-precision-change',
            :old_value => project.changes["precision"].first,
            :new_value => project.changes["precision"].last,
            :resource_1 => project.id
        ) if project.precision_changed?
      end
    end

    self.instance
  end
end
