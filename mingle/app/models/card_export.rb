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

class CardExport
  attr_accessor :project
  attr_accessor :cards_to_export
  attr_accessor :view
  TAGS_HEADER = "Tags"
  INCOMPLETE_CHECKLIST_ITEMS_HEADER = "Incomplete Checklist Items"
  COMPLETED_CHECKLIST_ITEMS_HEADER = "Completed Checklist Items"
  CHECKLIST_ITEMS_HEADERS = [INCOMPLETE_CHECKLIST_ITEMS_HEADER, COMPLETED_CHECKLIST_ITEMS_HEADER]
  LIST_ITEM_EXPORT_SEPARATOR = "\r"

  def initialize(project, view)
    self.project = project
    view.fetch_descriptions = true
    self.cards_to_export = view.all_cards
    self.view = view
  end

  def export(include_description, include_all_columns)
    headers = export_headers(include_description, include_all_columns)
    result = ""
    csv_writer = MingleUpgradeHelper.ruby_1_9? ? CSV : CSV::Writer
    csv_writer.generate(result) do |csv|
      csv << headers
      cards_to_export.each do |card|
        card.convert_redcloth_to_html! if card.redcloth?
        non_property_headers = [TAGS_HEADER] + CHECKLIST_ITEMS_HEADERS
        card_property_headers = headers.reject { |header| non_property_headers.include?(header) }
        export_options = {:include_tags => headers.include?(TAGS_HEADER), :include_checklist_items => (headers & CHECKLIST_ITEMS_HEADERS).present? }
        csv << card.export_attributes(card_property_headers, export_options)
      end
    end
    result
  end

  private

  def export_headers(include_description, include_all_columns)
    headers = if (!view.support_columns? || include_all_columns)
      Card::STANDARD_PROPERTIES +
      properties_sorted_for_export +
      PredefinedPropertyDefinitions::tracing_column_names +
      (has_tagged_card? ? [TAGS_HEADER] : []) + CHECKLIST_ITEMS_HEADERS
    else
      Card::STANDARD_PROPERTIES - [project.card_type_definition.name] + view.columns
    end
    headers.uniq!
    headers = headers.without('Description') unless include_description
    headers
  end

  def properties_sorted_for_export
    properties_grouped_by_tree = properties_to_export_grouped_by_tree
    result = properties_grouped_by_tree.keys.smart_sort.collect do |tree_cfg_id|
      properties = properties_grouped_by_tree[tree_cfg_id]
      tree_cfg_id ? sort_tree_properties(properties, tree_cfg_id) : sort_non_tree_properties(properties)
    end
    result.flatten.collect(&:name)
  end

  def sort_non_tree_properties(properties)
    properties.smart_sort_by(&:name)
  end

  def sort_tree_properties(properties, tree_configuration_id)
    aggregates, relationships = properties.partition(&:aggregated?)
    [project.tree_configurations.find(tree_configuration_id)] + relationships.sort_by(&:position) + aggregates.smart_sort_by(&:name)
  end

  def properties_to_export_grouped_by_tree
    project.find_property_definitions_by_card_types(card_types_to_export).group_by(&:tree_configuration_id)
  end

  def card_types_to_export
    card_types_used_by_tree = project.tree_configurations.collect(&:all_card_types).flatten.uniq
    (cards_to_export.collect(&:card_type) + card_types_used_by_tree).uniq
  end

  def has_tagged_card?
    !cards_to_export.all? { |card| card.tags.empty? }
  end

end
