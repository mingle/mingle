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

#Copyright 2010 ThoughtWorks, Inc.  All rights reserved.

module CrossProjectRollup
  class HtmlTable

    def initialize(main_project, options)
      @main_project = main_project
      @builder = Builder::XmlMarkup.new(:indent => 2)
      @zero_value_rows = options[:zero_value_rows]
    end
    
    def add_table(&block)
      @builder.div do
        @builder.table do
          yield
        end
      end
    end
    
    def add_header_row(head_labels)
      @builder.tr do
        head_labels.each do |head|
          @builder.th { @builder << head }
        end
      end
    end

    def add_data_row(row_header, row_data)
      add_row(ERB::Util.h(row_header), row_data)
    end
    
    def add_subtotal_row(row_header, row_data)
      add_row(italicize(row_header), row_data)
    end

    private
    
    def add_row(row_header, row_data)
      if @zero_value_rows || row_has_data(row_data)
        format_data_row(row_header, row_data)
      end
    end
    
    def row_has_data(row_data)
      row_data.any? { |value| value != 0 }
    end
  
    def format_data_row(row_header, row_data)
      data_with_correct_precision = format_with_project_precision(row_data)
      data_with_header = data_with_correct_precision.unshift(row_header)
      format_row(data_with_header)
    end
  
    def format_with_project_precision(row_data)
      row_data.map { |value| @main_project.format_number_with_project_precision(value) }
    end
  
    def format_row(row_data)
      @builder.tr do
        row_data.each do |data|
          @builder.td { @builder << data.to_s }
        end
      end
    end
      
    def italicize(header)
      "<i>#{header}</i>"
    end
  end
end
