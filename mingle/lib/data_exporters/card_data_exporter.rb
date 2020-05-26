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

class CardDataExporter < BaseDataExporter
  include MacrosSupport
  include ActionController::UrlWriter
  include ExportFailOverSupport

  def initialize(basedir, message = {})
    super(basedir, message)
    @attachment_exporter = has_attachments? ? AttachmentExporter.new(basedir) : AttachmentExporter::Empty.new(basedir)
  end

  def name
    'Cards'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Card.find_each_with_order(order_by_column: :number, batch_size: 500) do |card|
      return if abort_on_export_error?(@message[:export_id]) do
        card_url = card_show_url(Project.current.identifier, card.number, MingleConfiguration.site_url_as_url_options)
        sheet.insert_row(index, card_data(card, property_definitions), {link: {index: 1, url: card_url}})
        index = index.next
      end
    end
    Rails.logger.info("Exported cards data to sheet")
  end

  def exportable?
    Project.current.cards.count > 0
  end

  def external_file_data_possible?
    true
  end

  def export_count
    6
  end

  private
  def property_definitions_name(project_property_definitions)
    project_property_definitions.map do |project_property_definition|
      project_property_definition.hidden? ? "#{project_property_definition.name}(Hidden)" : project_property_definition.name
    end
  end

  def card_data(card, project_property_definitions)
    begin
      card.convert_redcloth_to_html! if card.redcloth?
    rescue => e
      Rails.logger.warn "Failed to convert redcloth to html: #{card.project.name}/#{card.number} #{e.message}"
    end
    description = card.description
    plain_text_description = description ? Nokogiri.HTML(card.description).text : ''
    @row_data.cells([
        card.number, card.name, plain_text_description,
        description, card.card_type.name, property_definitions_for(card, project_property_definitions),
        card.created_by.login, card.modified_by.login, card.tags.join(","), card.incomplete_checklist_items.map(&:text).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR),
        card.completed_checklist_items.map(&:text).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR),
        @attachment_exporter.export_for(card).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR), has_macros(card),
        macros(card).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
    ].flatten, unique_card_key(card))
  end

  def unique_card_key(card)
    "card_#{card.number}"
  end

  def headings
    ['Number', 'Name', 'Description (Plain text)', 'Description (HTML)', 'Type', property_definitions_name(property_definitions), 'Created by', 'Modified by', 'Tags', 'Incomplete checklist items', 'Complete checklist items', 'Attachments', 'Has charts', 'Charts and macros'].flatten
  end

  def property_definitions
    Project.current.property_definitions_with_hidden.smart_sort_by(&:name)
  end
  memoize :property_definitions

  def property_definitions_for(card, project_property_definitions)
    project_property_definitions.map do |property_definition|
      begin
        property_definition.property_value_on(card).export_value
      rescue PropertyDefinition::InvalidValueException => e
        Rails.logger.error("Skipping invalid property definition value while exporting - #{e.message}:\n Property :#{property_definition.inspect}\n Card: #{card.inspect}")
        ''
      end
    end

  end

  def has_attachments?
    Attachment.count(conditions: "project_id=#{Project.current.id}") > 0
  end
end
