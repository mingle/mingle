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

module CardImport
  class ExcelContent

    END_OF_LINE = "2859bab66bf39c5055c3e23600a7e04b4fe293cf"
    BLANK = "4083504aab26e0af833dacfd1a12f20e047ccc45"
    TAB = "8cdadba3f455a08559a3a2191a29e0a67ca830fc"

    attr_reader :file_path

    def initialize(file_path, ignores = [])
      @file_path = file_path
      @parsed_file_path = nil
      @ignores = ignores
    end

    def reset
      @parsed_file_path = nil
    end

    def blank?
      if File.exist? @file_path
        File.open(@file_path, "r") do |file|
          file.each do |line|
            return false if !line.strip.blank?
          end
        end
      end
      true
    end
  
    def raw_content
      File.read(@file_path)
    end
  
    def parse_file
      @parsed_file_path = @file_path + "parsed"
      parser = Parser.new(self, @file_path, @ignores)
      File.open(@parsed_file_path, "w") do |file|
        header = parser.header
        file.write(header.join(TAB).gsub(/\n/, END_OF_LINE) + "\n")
        parser.each do |line|
          line = line.map { |cell| cell.blank? ? BLANK : cell }
          file.write(line.join(TAB).gsub(/\n/, END_OF_LINE) + "\n")
        end
      end
    end
  
    def size
      count = 0
      cells.each { count += 1 }
      count
    end
  
    def cells
      parse_file unless @parsed_file_path
      Cells.new(self, @parsed_file_path, @ignores)
    end
  
    def lines(project, ignore_fields, headers)
      parse_file unless @parsed_file_path
      Lines.new(self, @parsed_file_path, @ignores, project, ignore_fields, headers)
    end
  
    def columns
      parse_file unless @parsed_file_path
      @columns ||= Columns.new(self, @parsed_file_path, @ignores)
    end
  
    class Mode
    
      def initialize(excel_content, file_path, ignores = [])
        @excel_content = excel_content
        @file_path = file_path
        @ignores = ignores
      end
    
    end
  
    class Parser < Mode
    
      def header
        each(:yield_header => true) { |line| return line }
      end
    
      def next_excel_line(file)
        buffer = Buffer.new
        lines = []
        begin
          line = file.gets
        
          ch_index = 0
          while ch_index < line.size
            buffer << line[ch_index].ord
            ch_index += 1
          end
        
          lines << line
        end until buffer.has_reached_end_of_line || file.eof?
        lines.join
      end
    
      def each(options = { :yield_header => false })
        first_line_number = nil
        line_number = 0
        File.open(@file_path, "r") do |file|
          header_has_not_been_processed = true
          until file.eof?
            excel_line = next_excel_line(file)
            next if excel_line.blank?
            if header_has_not_been_processed
              @header = excel_line
              parsed_header = CardImport::ExcelParser.parse(@header.strip)
              yield(parsed_header) if options[:yield_header]
              header_has_not_been_processed = false
            else
              line_number += 1
              next if @ignores.include?(line_number)
              parsed_lines = CardImport::ExcelParser.parse(((@header || "") + excel_line).strip)
              if parsed_lines.size > 1
                content_line = parsed_lines.last
                yield(content_line)
              end
            end
          end
        end
      end
    end
  
    class Cells < Mode
      include Enumerable
    
      def header
        each(:yield_header => true) do |line|
          return line
        end
      end
    
      def each(options = { :yield_header => false })
        File.open(@file_path, 'r') do |file|
          file.each do |encoded_line|
            line_as_cells = encoded_line.gsub(/#{CardImport::ExcelContent::END_OF_LINE}/, "\n").chomp.split(CardImport::ExcelContent::TAB).map do |cell|
              cell == CardImport::ExcelContent::BLANK ? nil : cell
            end
            yield(line_as_cells) unless file.lineno == 1 && !options[:yield_header]
          end
        end
      end
    
    end
  
    class Columns < Mode
      include Enumerable
    
      def initialize(excel_content, file_path, ignores)
        @transposed_file_path = file_path + "transposed"
        super(excel_content, file_path, ignores)
      end
    
      def each
        write_transposed_file unless File.exist?(@transposed_file_path)
        Cells.new(@excel_content, @transposed_file_path, @ignores).each(:yield_header => true) do |line|
          yield(line)
        end
      end
    
      private
    
      def write_transposed_file
        line_index = 0
        file_index = 0
        current_file_name = nil
        @excel_content.cells.each do |line|
          previous_file_name = current_file_name
          current_file_name = @transposed_file_path + (file_index % 2).to_s
          if line_index == 0
            File.open(current_file_name, "w") do |file|
              line.each do |cell|
                cell = cell ? cell.gsub(/\n/, CardImport::ExcelContent::END_OF_LINE) : CardImport::ExcelContent::BLANK
                file.write(cell + "\n")
              end
            end
          else
            File.open(current_file_name, "w") do |write_file|
              File.open(previous_file_name, "r") do |read_file|
                line.each do |cell|
                  old_cells = read_file.readline
                  cell = cell ? cell.gsub(/\n/, CardImport::ExcelContent::END_OF_LINE) : CardImport::ExcelContent::BLANK
                  write_file.write(old_cells.chomp + CardImport::ExcelContent::TAB + cell + "\n")
                end
              end
            end
          end
          line_index += 1
          file_index += 1
        end
      
        # create empty file if there were no rows to tranpose
        unless current_file_name
          current_file_name = @transposed_file_path
          File.open(current_file_name, "w") { }
        end
      
        @transposed_file_path = current_file_name
      end
    
    end
  
    class Lines < Mode
      include Enumerable
    
      def initialize(excel_content, file_path, ignores, project, ignore_fields, headers)
        @project = project
        @ignore_fields = ignore_fields
        @headers = headers
        super(excel_content, file_path, ignores)
      end
    
      def each
        index = 1
        @excel_content.cells.each do |line|
          yield CardImport::Line.new(line, @headers, @project, @ignore_fields, index)
          index += 1
        end
      end
    
      def [](index)
        counter = 0
        each do |line|
          return line if counter == index
          counter += 1
        end
      end
    
      def each_sorted_by_card_type(tree_configuration)
        value_index_array = []
        each_with_index do |line, index|
          value_index_array << [tree_configuration.card_type_index(line.card_type), index]
        end
        value_index_array = value_index_array.sort_with_nil_by { |value_and_index| value_and_index.first }
      
        value_index_array.each do |value, index|
          line = self[index]
          line.row_number = index + 1
          yield(line)
        end
      end
    end
  end
end
