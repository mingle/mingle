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

class ProjectCreator
  def create(spec)
    spec = HashWithIndifferentAccess.new(spec)
    project_spec = spec['project']

    add_current_user_as_member = project_spec.delete('current_user_as_member')

    project = Project.create!(project_spec.merge('hidden' => true))

    project.add_member(User.current) if add_current_user_as_member

    merge!(project, spec)
  end

  def merge!(project, spec, options={})
    spec = HashWithIndifferentAccess.new(spec)
    project.with_active_project do
      project.card_types.destroy_all
      project.card_defaults.destroy_all

      Array(spec['card_types']).each do |card_type_spec|
        create_card_type(project, card_type_spec.except('property_definitions'))
      end

      Array(spec['property_definitions']).each do |property_definition_spec|
        create_property_definition(project, property_definition_spec)
      end

      project.reload.update_card_schema

      (spec['trees'] || []).each do |tree_spec|
        create_tree(project, tree_spec)
      end

      Array(spec['card_types']).each do |card_type_spec|
        type = project.find_card_type(card_type_spec['name'])
        pds = Array(card_type_spec['property_definitions']).map do |pd|
          project.all_property_definitions.detect do |prop_def|
            prop_def.name == pd['name']
          end || raise("Could not find prop named #{pd['name'].inspect} in #{project.all_property_definitions.map(&:name).inspect}")
        end
        if pds.any?
          type.property_definitions = pds
        end
      end
      project.reload

      if options[:include_cards].nil? || options[:include_cards]
        (spec['cards'] || []).each do |card_spec|
          create_card(project, card_spec)
        end
        project.reset_card_number_sequence
      end

      (spec['plvs'] || []).each do |plv_spec|
        create_plv(project, plv_spec)
      end

      (spec['card_defaults'] || []).each do |card_defaults_spec|
        create_card_defaults(project, card_defaults_spec)
      end

      if options[:include_pages].nil? || options[:include_pages]
        (spec['pages'] || []).each do |page_spec|
          favorited = page_spec.delete('favorite')
          page = project.pages.create!(page_spec)
          create_favorited_page(project, page, favorited)
        end
      end

      (spec['tabs'] || []).each do |tab_spec|
        create_tab(project, tab_spec)
      end

      (spec['favorites'] || []).each do |favorite_spec|
        create_favorite(project, favorite_spec)
      end

      order_tabs(project, spec)

      (spec['murmurs'] || []).each do |murmur_spec|
        create_murmur(project, murmur_spec)
      end

      project.update_attribute(:hidden, false)
      project
    end
  end

  private

  def create_favorited_page(project, page, favorited)
    if favorited
      favorite = Favorite.new(:project_id => project.id, :favorited => page)
      favorite.adjust({:tab => true, :favorite => false})
      favorite.save
    end
  end

  def order_tabs(project, spec)
    ordered_tab_identifiers = []
    (spec['ordered_tab_identifiers'] || []).each do |identifier|
      if project.tabs.detect {|t| t.name == identifier}
        ordered_tab_identifiers << project.tabs.detect {|t| t.name == identifier}.id
      else
        ordered_tab_identifiers << identifier
      end
    end

    if ordered_tab_identifiers.blank?
      ordered_tab_identifiers = [DisplayTabs::OverviewTab::NAME] + project.user_defined_tab_favorites.map(&:id) + [DisplayTabs::AllTab::NAME, DisplayTabs::HistoryTab::NAME, DisplayTabs::SourceTab::NAME]
    end
    project.ordered_tab_identifiers = ordered_tab_identifiers
  end

  def create_card_defaults(project, spec)
    card_type_name = spec['card_type_name']
    card_type = project.find_card_type(card_type_name)

    defaults = card_type.card_defaults
    defaults.description = spec['description']
    defaults.update_properties spec['properties']
    defaults.save!
  end

  def create_property_definition(project, spec)
    property_values = spec.delete('property_value_details')
    pd = ApiPropertyDefinition.create(project, spec)
    raise pd.errors.full_messages.join("\n") unless pd.valid?
    project.all_property_definitions.reload
    create_enum_values(pd, property_values || [])
  end

  def create_card_type(project, type_spec)
    project.card_types.create!({:nature_reorder_disabled => true}.merge(type_spec))
  end

  def create_enum_values(pd, specs)
    specs.each do |spec|
      EnumerationValue.new(spec.merge(:nature_reorder_disabled => true, :property_definition_id => pd.id)).save!
    end
  end

  def create_card(project, card_spec)
    properties = card_spec.delete('properties') || {}
    tags = card_spec.delete('tags') || {}
    relationship_specs = card_spec.delete('card_relationships') || {}
    relationship_properties = resolved_card_relationships(project, relationship_specs)
    properties.merge!(relationship_properties)

    card = project.cards.build(card_spec)
    if properties.values.any?{|v| v == PropertyType::UserType::CURRENT_USER}
      @added_current_user_as_member ||= project.add_member(User.current)
    end
    card.update_properties(properties, :include_hidden => true) unless properties.blank?
    card.tag_with(tags.keys) if tags.keys.present?
    card_tags = card.tags
    tags.each do |name, color|
      tag = card_tags.select {|t| t.name == name}.first
      tag.update_attributes(:color => color)
    end
    card.save(false) || raise(ActiveRecord::RecordInvalid.new(card))
    card
  end

  def resolved_card_relationships(project, specs)
    specs.inject({}) do |relationships, entry|
      property, value = entry
      next if value.blank?
      if card = project.cards.find_by_number(value.to_i)
        relationships[property] = card.id
      else
        raise "can't find card by number #{value.inspect}"
      end

      relationships
    end
  end

  def create_plv(project, spec)
    pd_ids = spec['property_definitions'].map do |pd_name|
      project.find_property_definition(pd_name).id
    end

    value = translate_value(project, spec['data_type'], spec['value'])
    plv_attributes = {
      :name => spec['name'],
      :data_type => "ProjectVariable::#{spec['data_type']}".constantize,
      :value => value,
      :property_definition_ids => pd_ids,
      :card_type => project.find_card_type(spec['card_type'])
    }
    project.project_variables.create!(plv_attributes)
  end

  def translate_value(project, data_type, value)
    if data_type == 'CARD_DATA_TYPE'
      card = project.cards.find_by_number(value.to_i)
      card.id unless card.nil?
    else
      value
    end
  end

  def create_tab(project, spec)
    project_landing_tab = spec.delete :project_landing_tab
    view = create_view(project, spec, true)

    if !view.invalid? && project_landing_tab
      project.landing_tab = view.favorite
      project.save!
    end
  end

  def create_favorite(project, spec)
    create_view(project, spec)
  end

  def create_murmur(project, spec)
    project.murmurs.create(:body => spec['body'], :author => (User.find_by_login(spec['author'])))
  end

  def create_view(project, spec, tab_view = false)
    view = CardListView.construct_from_params(project, spec)
    view.tab_view = tab_view
    view.save! unless view.invalid?
    view
  end

  def create_tree(project, spec)
    tree_config = project.tree_configurations.create!(:name => spec['name'], :description => spec['description'])
    card_types = spec['configuration'].inject({}) do |card_types, type_config|
      card_type = project.find_card_type(type_config.delete('card_type_name'))
      card_types[card_type] = type_config
      card_types
    end
    tree_config.update_card_types(card_types)
    tree_config.create_tree

    (spec['aggregate_properties'] || []).each do |aggregate_property_spec|
      create_aggregate_properties(project, tree_config, aggregate_property_spec)
    end
    project.reload.update_card_schema
  end


  def create_aggregate_properties(project, tree_config, spec)
    # we need clean of scope in existing yaml specs
    # ignore spec['scope'], because the value is just null, and
    # not good for setup the value to be the right scope card type
    scope_card_type = if spec['scope_card_type_name']
                        project.find_card_type(spec['scope_card_type_name'])
                      end
    options = { :name => spec['name'],
      :aggregate_scope => scope_card_type,
      :aggregate_type => "AggregateType::#{spec['type']}".constantize,
      :aggregate_card_type_id => project.find_card_type(spec['card_type_name']).id,
      :tree_configuration_id => tree_config.id,
      :target_property_definition => project.find_property_definition(spec['target_property_name'])
    }
    options.merge!({:aggregate_condition => spec['condition']}) unless spec['condition'].nil?

    aggregate_property_def = project.all_property_definitions.create_aggregate_property_definition(options)
    aggregate_property_def.save!
    project.all_property_definitions.reload
  end
end
