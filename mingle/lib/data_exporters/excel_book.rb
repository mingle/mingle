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

class ExcelBook
  def initialize(name)
    @name = name
    @book ||= create_book
  end

  def create_sheet(name)
    Sheet.new(@book, name, heading_style)
  end

  def write(path)
    begin
      output = java.io.FileOutputStream.new("#{path}/#{@name}.xlsx")
      @book.write(output)
    ensure
      @book.dispose
      output && output.close
    end
  end

  def heading_style
    style = @book.create_cell_style
    font = @book.create_font
    font.set_bold(true)
    style.setFont(font)
    style
  end

  private
  def create_book
    org.apache.poi.xssf.streaming.SXSSFWorkbook.new(1000)
  end

  class Sheet
    ROW_LIMIT = 1048575

    def initialize(book, name, headings_style, row_limit=ROW_LIMIT)
      @book = book
      @name = name
      @sheets = [book.create_sheet(name)]
      @headings_style = headings_style
      @row_limit = row_limit
      @heading_data = []
    end

    def add_headings(data)
      @heading_data = data
      insert_row(0, data, {style: @headings_style})
    end

    def insert_row(row_number, data, options={})
      sheet_count, row_number = row_number.divmod(@row_limit)
      if row_number == 0 && sheet_count > @sheets.count - 1
        create_new_sheet
      end
      row_number += 1 if @sheets.count > 1

      insert_into_sheet(sheet, row_number, data, options)
    end

    def create_hyperlink
      org.apache.poi.xssf.usermodel.XSSFWorkbook.new.getCreationHelper.create_hyperlink(org.apache.poi.common.usermodel.HyperlinkType::URL)
    end

    def insert_link(url, cell)
      hyper_link = create_hyperlink
      hyper_link.set_address(url)
      cell.set_hyperlink(hyper_link)
    end

    def number_of_rows
      sheet.physical_number_of_rows
    end

    def row(index)
      row = sheet.get_row(index)
      it = row.cell_iterator
      cells = []
      cells << cast_value(it.next.get_string_cell_value) while it.has_next
      cells
    end

    def cell_link_address(row_number, cell_number)
      cell(row_number, cell_number).get_hyperlink.get_address
    end

    def headings
      row(0)
    end

    private
    def create_new_sheet
      @sheets << @book.create_sheet("#{@name}#{@sheets.count + 1}")
      insert_into_sheet(sheet, 0, @heading_data, {style: @headings_style})
    end

    def insert_into_sheet(sheet, row_number, data, options={})
      row = sheet.create_row(row_number)
      data.each_with_index do |cell_data, cell_number|
        cell = row.create_cell(cell_number)
        cell.set_cell_value(cell_data.to_s)
        cell.set_cell_style(options[:style]) if options[:style]
        insert_link(options[:link][:url], cell) if options[:link] && (cell_number == options[:link][:index])
      end
    end

    def sheet
      @sheets.last
    end

    def cast_value(value)
      value.match(/^\d+$/) ? value.to_i : value
    end

    def cell(row_number, cell_number)
      sheet.get_row(row_number).get_cell(cell_number)
    end
  end
end
