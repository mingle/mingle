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

class BaseDataExporter
  def initialize(basedir, message = {})
    @basedir = basedir
    @message = message
    @row_data = RowData.new(@basedir, headings, external_file_data_possible?)
  end

  def export_count
    1
  end

  def name
    raise 'Implement in child class'
  end

  def export(sheet)
    raise 'Implement in child class'
  end

  def headings
    raise 'Implement in child class'
  end

  def external_file_data_possible?
    false
  end

  def sheet_headings
    @row_data.header_names
  end

  def exports_to_sheet?
    true
  end

  def exportable?
    true
  end

end
