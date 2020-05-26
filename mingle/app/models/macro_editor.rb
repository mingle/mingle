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

class MacroEditor

  class ContentProvider
    attr_reader :provider_type, :id

    def self.to_params(target)
      {:provider_type => target.class.name, :id => target.id, :redcloth => false }
    end

    def initialize(project, attrs)
      @project = project
      @provider_type = attrs[:provider_type]
      @target = attrs[:content_provider] if attrs[:content_provider]
      @id = attrs[:id]
    end

    def to_params
      { :provider_type => @provider_type, :id => @id }
    end

    def preview(content, view_helper)
      target.content = content
      target.formatted_content_preview(view_helper)
    end

    private
    def target
      return @target if @target
      provider_class = @provider_type.constantize
      @target = if @id.blank?
        provider_class.new.respond_to?(:project=) ? provider_class.new(:project => @project) : provider_class.new(:project => @project)
      else
        provider_class.find(@id)
      end
    end
  end

  attr_reader :macro_def, :content_provider, :project

  def self.supported_macros
    @macros ||= [
      MacroDef.new('average', [Macro::ParameterDefinition.new('query', :required => true, :example => "SELECT property WHERE condition"), Macro::ParameterDefinition.new('project')]),
      MacroDef.new('data-series-chart', DataSeriesChart.parameter_definitions, :series_parameter_definitions => Series.parameter_definitions_for_data_series_chart),
      MacroDef.new('daily-history-chart', DailyHistoryChart.parameter_definitions, :series_parameter_definitions => DailyHistorySeries.parameter_definitions),
      MacroDef.new('pie-chart', PieChart.parameter_definitions),
      MacroDef.new('pivot-table', PivotTableMacro.parameter_definitions),
      MacroDef.new('project', ProjectMacro.parameter_definitions),
      MacroDef.new('project-variable', ProjectVariableMacro.parameter_definitions),
      MacroDef.new('ratio-bar-chart', RatioBarChart.parameter_definitions),
      MacroDef.new('stack-bar-chart', StackBarChart.parameter_definitions, :series_parameter_definitions => Series.parameter_definitions_for_stack_bar_chart),
      MacroDef.new('stacked-bar-chart', StackBarChart.parameter_definitions, :series_parameter_definitions => Series.parameter_definitions_for_stack_bar_chart),
      MacroDef.new('cumulative-flow-graph', StackBarChart.parameter_definitions, :series_parameter_definitions => Series.parameter_definitions_for_stack_bar_chart),
      MacroDef.new('table-query', TableMacro.query_parameter_definitions, {:type => 'table'}),
      MacroDef.new('table-view', TableMacro.view_parameter_definitions, {:type => 'table'}),
      MacroDef.new('value', ValueMacro.parameter_definitions)
    ]
  end

  def self.macro_as_json(macro_type_name)
    macro_def = macro_def_for(macro_type_name)
    macro_def.to_json
  end

  def self.macro_def_for(name)
    supported_macros.find{|macro_def| macro_def.name == name}
  end

  def initialize(project, macro_name, params = {}, content_provider = {})
    @project = project
    @macro_def = MacroEditor.macro_def_for macro_name
    @content_provider = ContentProvider.new(@project, content_provider)
    @params = params
  end

  def preview(view_helper)
    @content_provider.preview(content, view_helper)
  end

  def content_with_example
    content(:with_example => true)
  end
  memoize :content_with_example

  def content(options={})
    param_defs = @macro_def.parameter_definitions
    if @macro_def.support_series?
      @params['series'] = series_data_from_params(@params['series'] || {})
      param_defs << @macro_def.parameter_definition_for_series
    end

    result = "{{\n"
    result << "  #{@macro_def.macro_type}"
    result << "\n#{OrderedYAMLWriter.new(param_defs).write(@params, '    ')}".gsub('}}', '') if param_defs.any?
    result << "}}"
  end
  memoize :content

  private

  def series_data_from_params(series_data)
     return series_data unless series_data.is_a? Hash
      series_data.keys.smart_sort.map do |series_index|
        series_data[series_index]
      end

  end

  class MacroDef
    attr_reader :name, :macro_type, :series_parameter_definitions

    def initialize(name, parameter_definitions, options = {})
      @name = name
      @macro_type = options[:type] || name
      @parameter_definitions = parameter_definitions
      @series_parameter_definitions = Array(options[:series_parameter_definitions])
    end

    def parameter_definitions
      @parameter_definitions.reject {|pd| pd.name.to_s == 'series'}
    end

    def parameter_definition_for_series
      @parameter_definitions.detect { |pd| pd.name.to_s == 'series' }
    end

    def edit_panel_html_id
      "#{@name}_macro_panel"
    end

    def support_series?
      @series_parameter_definitions.any?
    end

    def to_hash
      macro_def_as_hash = {}
      macro_def_as_hash[name] = parameter_definitions.map(&:to_hash)
      macro_def_as_hash["#{name}-series"] = series_parameter_definitions.map(&:to_hash) if support_series?
      macro_def_as_hash
    end

    def to_json
      to_hash.to_json
    end
  end
end
