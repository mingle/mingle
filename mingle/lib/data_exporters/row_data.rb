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

class RowData
  FILE_DATA_COLUMN_HEADER = 'Data exceeding 32767 character limit'
  LARGE_DATA_DIR = 'Large descriptions'
  MAX_CELL_CHAR_LIMIT = 32750

  def initialize(base_dir, headers = [], external_file_data_possible = false)
    @base_dir = base_dir
    @external_file_data_possible = external_file_data_possible
    @headers = @external_file_data_possible ? headers << FILE_DATA_COLUMN_HEADER : headers
  end


  def cells(data, file_prefix = '')
    columns_above_char_limit = []
    cells = []
    data.each_with_index do |cell_data, index|
      if @external_file_data_possible && cell_data.to_s.length > MAX_CELL_CHAR_LIMIT
        cells << generate_data_file(cell_data.to_s, file_prefix, @headers[index])
        columns_above_char_limit << @headers[index]
      else
        cells << cell_data
      end
    end

    cells << columns_above_char_limit.join(CardExport::LIST_ITEM_EXPORT_SEPARATOR) if columns_above_char_limit.size > 0
    cells
  end

  def header_names
    @headers
  end

  private

  def generate_data_file(text, file_prefix, header_name)
    file_name = file_prefix.blank? ? UUID.generate : "#{file_prefix}_#{header_name}"
    FileUtils.mkdir_p(large_data_dir)
    File.write(file_path(file_name), text)
    "Content too large. Written to file:#{relative_file_path(file_name)}"
  end

  def relative_file_path(file_prefix)
    File.join(LARGE_DATA_DIR, file_name(file_prefix))
  end

  def file_path(file_prefix)
    File.join(large_data_dir, file_name(file_prefix))
  end

  def file_name(file_prefix)
    "#{file_prefix}.txt"
  end

  def large_data_dir
    File.join @base_dir, LARGE_DATA_DIR
  end
end
