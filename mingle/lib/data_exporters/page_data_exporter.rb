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

class PageDataExporter < BaseDataExporter

  include ActionController::UrlWriter
  include MacrosSupport

  def initialize(basedir, message = {})
    super(basedir, message)
    @attachment_exporter = has_attachments? ? AttachmentExporter.new(basedir) : AttachmentExporter::Empty.new(basedir)
  end

  def name
    'Pages'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Project.current.pages.order_by_name.each do |page|
      page_url = url_for(MingleConfiguration.site_url_as_url_options.merge({controller: 'pages', action: 'show', pagename: page.identifier, project_id: Project.current.identifier}))

      html_description = page.content
      plain_description = html_description ? Nokogiri.HTML(html_description).text : ''
      row = [page.name, plain_description, html_description, page_tags(page), page_view(page, 'Tab'), page_view(page, 'Team Favorite'),
                        @attachment_exporter.export_for(page).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR),
                        has_macros(page), macros(page).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)]
      sheet.insert_row(index, @row_data.cells(row, unique_key(page)),
                       {link: {index: 0, url: page_url}})
      index = index.next
    end
  end

  def exportable?
    Project.current.pages.count > 0
  end

  def external_file_data_possible?
    true
  end

  private
  def unique_key(page)
    "#{page.export_dir}_#{page.id}"
  end

  def headings
    ['Title', 'Description(Plain text)', 'Description(HTML)', 'Tags', 'Tab', 'Team favorite', 'Attachments', 'Has macros', 'Charts and macros']
  end

  def page_tags(page)
    page.tags.collect(&:name).join(', ')
  end

  def page_view(page, field)
    return 'N' if page.favorites.empty?
    convert_boolean(field.eql?('Tab') == page.favorites.first.tab_view)
  end

  def convert_boolean(value)
    value ? 'Y' : 'N'
  end

  def has_attachments?
    Attachment.count(conditions: "project_id=#{Project.current.id}") > 0
  end
end
