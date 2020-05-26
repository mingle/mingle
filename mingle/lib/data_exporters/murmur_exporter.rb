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

class MurmurExporter < BaseDataExporter

  def name
    'Murmurs'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    comment_column_name = SqlHelper.not_null_or_empty(SqlHelper.quote_column_name('comment'))
    if Card::Version.count(conditions: comment_column_name) > Project.current.murmurs.count
      compare_hash = {}
      Project.current.murmurs.order_by_origin_id_and_created_at.each do |murmur|
        compare_hash[[murmur.author, murmur.murmur, murmur.origin_id]] = murmur
        index = insert_murmur_data(
            index, sheet, murmur.id, murmur.murmur, murmur.author, murmur.created_at, murmur.origin_type_description
        )
      end
      Card::Version.all(conditions: comment_column_name, order: SqlHelper.quote_column_name('updated_at')).each do |version|
        author = version.modified_by
        created_at = version.updated_at
        match = compare_hash[[author, version.comment, version.card_id]]
        unless match && (match.created_at - created_at).abs < 10.seconds
          index = insert_murmur_data(
              index, sheet, version.id, version.comment, author, created_at, "##{version.number}"
          )
        end
      end
    else
      Project.current.murmurs.order_by_origin_id_and_created_at.each do |murmur|
        index = insert_murmur_data(
            index, sheet, murmur.id, murmur.murmur, murmur.author, murmur.created_at, murmur.origin_type_description
        )
      end
    end
  end

  def exportable?
    Project.current.murmurs.count > 0
  end

  def external_file_data_possible?
    true
  end

  private

  def insert_murmur_data(index, sheet, id, murmur, author, created_at, origin_type_description)
    sheet.insert_row(
        index,
        @row_data.cells([
                            murmur, Project.current.format_time(created_at),
                            author_name(author), origin_type_description
                        ].flatten,
                        "Murmur - #{id}"
        )
    )
    index.next
  end

  def headings
    %w(Murmur Timestamp User Card)
  end

  def author_name(author)
    author.nil? ? '' : author.name
  end
end
