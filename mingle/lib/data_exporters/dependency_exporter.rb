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

class DependencyExporter < BaseDataExporter
  def initialize(base_dir, message={})
    super(base_dir, message)
    @attachment_exporter = has_attachments? ? AttachmentExporter.new(base_dir) : AttachmentExporter::Empty.new(base_dir)
  end

  def name
    'Dependencies'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
    index = 1
    Dependency.find_each_with_order(order_by_column: :number, batch_size: 500) do |dependency|
      sheet.insert_row(index, dependency_data(dependency))
      index = index.next
    end
  end

  def external_file_data_possible?
    true
  end

  def exportable?
    Dependency.count > 0
  end

  private
  def dependency_data(dep)
    description = dep.description
    plain_text_description = description ? Nokogiri.HTML(dep.description).text : ''
    @row_data.cells([
        dep.number, dep.name, plain_text_description, dep.description,
        dep.status, dep.created_at.strftime('%d %b %Y'), dep.desired_end_date && dep.desired_end_date.strftime('%d %b %Y'),
        dep.raising_project && dep.raising_project.name, dep.raising_card.number_and_name, dep.raising_user.login, dep.resolving_project && dep.resolving_project.name,
        resolving_cards(dep), @attachment_exporter.export_for(dep).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
    ], unique_key(dep))
  end

  def unique_key(dep)
    "dependency_#{dep.number}"
  end

  def resolving_cards(dep)
    dep.resolving_cards.map(&:number_and_name).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
  end

  def headings
    ['Number', 'Name', 'Description (Plain text)', 'Description (HTML)',
     'Status	', 'Date raised', 'Desired completion date', 'Raising project',
     'Raising card', 'Raising user', 'Resolving project', 'Resolving cards', 'Attachments']
  end

  def has_attachments?
    Attaching.count(conditions: "attachable_type = 'Dependency'") > 0
  end
end
