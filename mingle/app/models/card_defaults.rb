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

class CardDefaults < ActiveRecord::Base
  include Renderable

  belongs_to :card_type
  belongs_to :project
  has_many :checklist_items, :dependent => :destroy, :order => "position ASC, updated_at DESC, id DESC", :class_name => 'CardDefaultsChecklistItem', :foreign_key => 'card_id'

  has_many :actions, :class_name => "::PropertyDefinitionTransitionAction", :dependent => :destroy, :as => :executor do
    def create_or_update(property_value)
      result = find(:first, :conditions => {:target_id => property_value.property_definition.id})
      if result
        result.target_property = property_value
        result.save
      else
        result = create(:target_property => property_value)
      end
      result
    end
  end

  use_database_limits_for_all_attributes

  def content_changed?
    description_changed?
  end

  def update_card(card, options = {})
    errors = {}
    update_checklists card
    if options[:hidden_only]
      actions.each { |action| action.execute(card) if action.property_definition.hidden? }
    else
      update_description card
      actions.each do |action|
        existing_errors = card.errors.full_messages
        card.errors.clear
        action.execute(card)
        card.validate
        current_errors = card.errors.full_messages
        errors["#{action.property_definition.name.bold} to #{action.value}"] = (current_errors - existing_errors)

        if options[:set_errored_fields_to_not_set] && !errors["#{action.property_definition.name.bold} to #{action.value}"].blank?
          property_value_to_set = PropertyValue.create_from_db_identifier(action.property_definition, PropertyValue::NOT_SET_VALUE_PAIR.last)
          property_value_to_set.assign_to(card)
        end
      end
      card.revise_belonging_tree_structure
      card.errors.clear
      errors.each do |pd_to_value, pd_errors|
        if pd_errors.any?
          card.errors.add_to_base("Unable to set default for #{pd_to_value} because #{pd_errors.collect(&:strip).to_sentence}")
          card.block_errors(pd_errors)
        end
      end
    end
  end

  def update_description(card)
    self.convert_redcloth_to_html! if self.redcloth
    card.description = self.description
  end

  def update_checklists(card)
    card.add_checklist_items(checklists_hash)
  end

  def set_checklist_items(checklist_items)
    self.checklist_items.map(&:destroy)
    self.checklist_items = checklist_items.each_with_index.map do |item_text, index|
      CardDefaultsChecklistItem.new({:text => item_text,
                                     :project_id => project.id,
                                     :position => index})
    end
  end

  def update_properties(property_params)
    property_values = PropertyValueCollection.from_params(project, property_params, {:include_hidden => true})
    property_values.each do |property_value|
      a = actions.create_or_update(property_value)
      a.errors.full_messages.each { |e| self.errors.add_to_base(e) }
    end
  end

  def content
    description
  end

  def content=(value)
    self.description = value
  end

  def has_macros=(has_macros); end

  def stop_using_property_value(property_value)
    actions.select { |a| a.target_property == property_value }.each(&:destroy)
  end

  def stop_using_property_definition(definition)
    actions.select { |action| action.property_definition == definition}.each(&:destroy)
  end

  def uses?(property_value)
    default_property = property_value_for(property_value.property_definition.name)
    return false if default_property && default_property.has_special_value?
    default_property == property_value
  end

  def uses_property_definition?(definition)
    actions.any? { |action| action.property_definition == definition}
  end

  def card_type_name
    card_type.name
  end

  def property_value_for(property_name)
    setting_action = actions.detect { |action| action.property_definition.name.downcase == property_name.downcase }
    setting_action.target_property if setting_action
  end

  def property_definitions
    actions.find_all { |action| action.respond_to?(:property_definition) }.map(&:property_definition)
  end

  def destroy_unused_actions(current_property_defs)
    obsolete_actions = actions.select { |a| a.respond_to?(:property_definition) && !current_property_defs.include?(a.property_definition) }
    obsolete_actions.each(&:destroy)
  end

  def validate
    self.errors.add_to_base("Defaults cannot set more than one relationship property per tree.") if sets_more_than_one_relationship_per_tree
  end

  def chart_executing_option
    {
      :controller => 'card_types',
      :action => 'chart',
      :id => id
    }
  end

  def clean_card_property_definitions!
    actions.each do |action|
      action.destroy if action.uses_any_card?
    end
  end

  def has_tree_belonging_actions?(tree_configuration)
    false
  end

  def this_card_condition_availability
    ThisCardConditionAvailability::Later.new(self)
  end

  def this_card_condition_error_message(usage)
    "Macros using #{usage.bold} will be rendered when card is created using this card default."
  end

  def daily_history_chart_url(view_helper, params)
    view_helper.daily_history_chart_for_unsupported_url({:position => params[:position], :unsupported_content_provider => 'card defaults'})
  end

  def self.any_using_user?(user)
    user_ids = ThreadLocalCache.get("CardDefaults.user_ids") do
      query = %Q{
      SELECT ta.value
      FROM #{TransitionAction.quoted_table_name} ta
        INNER JOIN #{PropertyDefinition.quoted_table_name} pd ON pd.id=ta.target_id AND pd.type='UserPropertyDefinition'
      WHERE ta.executor_type='CardDefaults'
      }
      self.connection.select_values(query).uniq.compact.map(&:to_i)
    end
    user_ids.include?(user.id)
  end

  def checklists_hash
    {CardImport::Mappings::INCOMPLETE_CHECKLIST_ITEMS => checklist_items.map(&:text)}
  end

  private

  def sets_more_than_one_relationship_per_tree
    relationship_actions_that_set_card = actions.select { |action| action.property_definition.is_a?(TreeRelationshipPropertyDefinition) && !action.value.blank? }
    tree_ids = relationship_actions_that_set_card.collect do |action|
      action.property_definition.tree_configuration.id
    end.uniq
    tree_ids.size < relationship_actions_that_set_card.size
  end

end
