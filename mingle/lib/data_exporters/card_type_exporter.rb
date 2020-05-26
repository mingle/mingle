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

class CardTypeExporter < BaseDataExporter

  def name
    'Card types'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Project.current.card_types.order_by_name.each do |card_type|
      description = card_type.card_defaults.description
      plain_text_description = description ? Nokogiri.HTML(card_type.card_defaults.description).text : ''
      sheet.insert_row(index, [card_type.name, plain_text_description, description])
      index = index.next
    end
    Rails.logger.info("Exported card types to sheet")
  end

  def exports_to_sheet?
    true
  end

  def exportable?
    Project.current.card_types.count > 0
  end

  private

  def headings
    ['Card types', 'Default Description(Plain text)', 'Default Description(HTML)']
  end

end
