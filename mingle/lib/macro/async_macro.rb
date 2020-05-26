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

module AsyncMacro
  attr_accessor :macro_position
  def self.included(base)
    base.extend(ClassMethod)
  end

  module ClassMethod
    MACRO_SYNTAX = /\{\{\s*(?:(table|value)|(?:\S*)):?([^\}]*)\}\}/m
    def extract(template, _, macro_position, options = {})
      options[:host_project] ||= Project.current
      scanner = StringScanner.new(template.to_s)
      1.upto(macro_position) do
        scanner.scan_until(MACRO_SYNTAX)
      end
      raise Macro::ProcessingError, "did not find #{self.name} at position #{macro_position.bold}" unless scanner[1]
      parameters = Macro.parse_parameters(scanner[2])
      project_to_be_charted = parameters && parameters['project'] ? Project.find_by_identifier(project_identifier_from_parameters(parameters, options[:content_provider])) : options[:host_project]

      chart = project_to_be_charted.with_active_project do |p|
        Macro.create(scanner[1], {:project => p, :content_provider => options[:content_provider], :preview => options[:preview], :view_helper => options[:view_helper]}, parameters, scanner[0])
      end
      chart.macro_position = macro_position
      chart
    end

    def extract_and_generate(template, _, macro_position, options = {})
      chart = self.extract(template, _, macro_position, options)
      chart.project.with_active_project do
        chart.execute_macro(false)
      end
    rescue Macro::ProcessingError => e
      Kernel.logger.debug("Ignore macro processing error while extract and generate table macro: #{e.message}\n#{e.backtrace.join("\n")}")
      ''
    end
    send(:include, ::ChartCaching)
  end

  def execute_macro(callback = true)
    if generate_data?(callback)
      return generate_data
    end
    generate_callback
  end

  def generate_callback
    params = {
        :type => name,
        :position => context[:macro_position],
        :project_id => context[:content_provider_project].identifier
    }.merge(content_provider.chart_executing_option)

    macro_id = chart_id(params[:position])
    macro_id += '-preview' if params[:preview]
    data_url = "#{view_helper.url_for(params.merge({:action => 'async_macro_data', :escape => false}))}"
    output = "<div id='#{macro_id}'></div>"
    output << %Q{
    <script type="text/javascript">
      (function renderAsyncMacro(bindTo, dataUrl) {
        var spinner = $j('<img>', {src: '/images/spinner.gif', class: 'async-macro-loader'});
        $j(bindTo).append(spinner);
        $j.get(dataUrl, function( data ) {
            $j(bindTo).replaceWith( data );
        });
      })('##{macro_id}', '#{data_url}' )
    </script>}
    output
  end

  def generate
    project.with_active_project do
      execute_macro(false)
    end
  end

  def chart_id(position)
    "#{name}-macro-#{content_provider.id}-#{position}"
  end


  def generate_data?(callback)
    !MingleConfiguration.async_macro_enabled_for?(name) || context[:preview] || !callback
  end
end
