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

module EasyCharts
  class MacroParams
    CHART_MACROS = {
        'pie-chart' => EasyCharts::PieChartMacroParams
    }
    def self.extract(macro)
      scanner = StringScanner.new(macro)
      scanner.scan_until(::Chart::MACRO_SYNTAX)
      raise MacroEditorNotSupported.new("#{scanner[1]} not supported for edit") unless CHART_MACROS[scanner[1]] && MingleConfiguration.easy_charts_macro_editor_enabled_for?(scanner[1])

      macro_params = ::Macro.parse_parameters(scanner[2]).with_indifferent_access
      CHART_MACROS[scanner[1]].from(macro_params)
    end
  end

  class MacroEditorNotSupported < Exception
  end
end
