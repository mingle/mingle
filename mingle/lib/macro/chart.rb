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

class Chart < Macro
  MACRO_SYNTAX = /\{\{\s*(?:(\S*-chart|cumulative-flow-graph)?|(?:\S*)):?([^\}]*)\}\}/m
  
  # standard HTML colors from http://www.w3schools.com/html/html_colornames.asp
  HTML_COLORS = {
    "AliceBlue" => 0xF0F8FF,
    "AntiqueWhite" => 0xFAEBD7,
    "Aqua" => 0x00FFFF,
    "Aquamarine" => 0x7FFFD4,
    "Azure" => 0xF0FFFF,
    "Beige" => 0xF5F5DC,
    "Bisque" => 0xFFE4C4,
    "Black" => 0x000000,
    "BlanchedAlmond" => 0xFFEBCD,
    "Blue" => 0x0000FF,
    "BlueViolet" => 0x8A2BE2,
    "Brown" => 0xA52A2A,
    "BurlyWood" => 0xDEB887,
    "CadetBlue" => 0x5F9EA0,
    "Chartreuse" => 0x7FFF00,
    "Chocolate" => 0xD2691E,
    "Coral" => 0xFF7F50,
    "CornflowerBlue" => 0x6495ED,
    "Cornsilk" => 0xFFF8DC,
    "Crimson" => 0xDC143C,
    "Cyan" => 0x00FFFF,
    "DarkBlue" => 0x00008B,
    "DarkCyan" => 0x008B8B,
    "DarkGoldenRod" => 0xB8860B,
    "DarkGray" => 0xA9A9A9,
    "DarkGrey" => 0xA9A9A9,
    "DarkGreen" => 0x006400,
    "DarkKhaki" => 0xBDB76B,
    "DarkMagenta" => 0x8B008B,
    "DarkOliveGreen" => 0x556B2F,
    "Darkorange" => 0xFF8C00,
    "DarkOrchid" => 0x9932CC,
    "DarkRed" => 0x8B0000,
    "DarkSalmon" => 0xE9967A,
    "DarkSeaGreen" => 0x8FBC8F,
    "DarkSlateBlue" => 0x483D8B,
    "DarkSlateGray" => 0x2F4F4F,
    "DarkSlateGrey" => 0x2F4F4F,
    "DarkTurquoise" => 0x00CED1,
    "DarkViolet" => 0x9400D3,
    "DeepPink" => 0xFF1493,
    "DeepSkyBlue" => 0x00BFFF,
    "DimGray" => 0x696969,
    "DimGrey" => 0x696969,
    "DodgerBlue" => 0x1E90FF,
    "FireBrick" => 0xB22222,
    "FloralWhite" => 0xFFFAF0,
    "ForestGreen" => 0x228B22,
    "Fuchsia" => 0xFF00FF,
    "Gainsboro" => 0xDCDCDC,
    "GhostWhite" => 0xF8F8FF,
    "Gold" => 0xFFD700,
    "GoldenRod" => 0xDAA520,
    "Gray" => 0x808080,
    "Grey" => 0x808080,
    "Green" => 0x008000,
    "GreenYellow" => 0xADFF2F,
    "HoneyDew" => 0xF0FFF0,
    "HotPink" => 0xFF69B4,
    "IndianRed" => 0xCD5C5C,
    "Indigo" => 0x4B0082,
    "Ivory" => 0xFFFFF0,
    "Khaki" => 0xF0E68C,
    "Lavender" => 0xE6E6FA,
    "LavenderBlush" => 0xFFF0F5,
    "LawnGreen" => 0x7CFC00,
    "LemonChiffon" => 0xFFFACD,
    "LightBlue" => 0xADD8E6,
    "LightCoral" => 0xF08080,
    "LightCyan" => 0xE0FFFF,
    "LightGoldenRodYellow" => 0xFAFAD2,
    "LightGray" => 0xD3D3D3,
    "LightGrey" => 0xD3D3D3,
    "LightGreen" => 0x90EE90,
    "LightPink" => 0xFFB6C1,
    "LightSalmon" => 0xFFA07A,
    "LightSeaGreen" => 0x20B2AA,
    "LightSkyBlue" => 0x87CEFA,
    "LightSlateGray" => 0x778899,
    "LightSlateGrey" => 0x778899,
    "LightSteelBlue" => 0xB0C4DE,
    "LightYellow" => 0xFFFFE0,
    "Lime" => 0x00FF00,
    "LimeGreen" => 0x32CD32,
    "Linen" => 0xFAF0E6,
    "Magenta" => 0xFF00FF,
    "Maroon" => 0x800000,
    "MediumAquaMarine" => 0x66CDAA,
    "MediumBlue" => 0x0000CD,
    "MediumOrchid" => 0xBA55D3,
    "MediumPurple" => 0x9370D8,
    "MediumSeaGreen" => 0x3CB371,
    "MediumSlateBlue" => 0x7B68EE,
    "MediumSpringGreen" => 0x00FA9A,
    "MediumTurquoise" => 0x48D1CC,
    "MediumVioletRed" => 0xC71585,
    "MidnightBlue" => 0x191970,
    "MintCream" => 0xF5FFFA,
    "MistyRose" => 0xFFE4E1,
    "Moccasin" => 0xFFE4B5,
    "NavajoWhite" => 0xFFDEAD,
    "Navy" => 0x000080,
    "OldLace" => 0xFDF5E6,
    "Olive" => 0x808000,
    "OliveDrab" => 0x6B8E23,
    "Orange" => 0xFFA500,
    "OrangeRed" => 0xFF4500,
    "Orchid" => 0xDA70D6,
    "PaleGoldenRod" => 0xEEE8AA,
    "PaleGreen" => 0x98FB98,
    "PaleTurquoise" => 0xAFEEEE,
    "PaleVioletRed" => 0xD87093,
    "PapayaWhip" => 0xFFEFD5,
    "PeachPuff" => 0xFFDAB9,
    "Peru" => 0xCD853F,
    "Pink" => 0xFFC0CB,
    "Plum" => 0xDDA0DD,
    "PowderBlue" => 0xB0E0E6,
    "Purple" => 0x800080,
    "Red" => 0xFF0000,
    "RosyBrown" => 0xBC8F8F,
    "RoyalBlue" => 0x4169E1,
    "SaddleBrown" => 0x8B4513,
    "Salmon" => 0xFA8072,
    "SandyBrown" => 0xF4A460,
    "SeaGreen" => 0x2E8B57,
    "SeaShell" => 0xFFF5EE,
    "Sienna" => 0xA0522D,
    "Silver" => 0xC0C0C0,
    "SkyBlue" => 0x87CEEB,
    "SlateBlue" => 0x6A5ACD,
    "SlateGray" => 0x708090,
    "SlateGrey" => 0x708090,
    "Snow" => 0xFFFAFA,
    "SpringGreen" => 0x00FF7F,
    "SteelBlue" => 0x4682B4,
    "Tan" => 0xD2B48C,
    "Teal" => 0x008080,
    "Thistle" => 0xD8BFD8,
    "Tomato" => 0xFF6347,
    "Turquoise" => 0x40E0D0,
    "Violet" => 0xEE82EE,
    "Wheat" => 0xF5DEB3,
    "White" => 0xFFFFFF,
    "WhiteSmoke" => 0xF5F5F5,
    "Yellow" => 0xFFFF00,
    "YellowGreen" => 0x9ACD32,
  }

  MINGLE_COLORS = {
    "Red" => 0xEA0200,
    "LightRed" => 0xEA5800,
    "Orange" => 0xEA8D00,
    "DarkYellow" => 0xEABB00,
    "Yellow" => 0xE9EA00,
    "LightGreen" => 0xAAD306,
    "Green" => 0x2ABA0B,
    "LightBlue" => 0x0B8ABA,
    "Blue" => 0x0B53BA,
    "DarkBlue" => 0x1B0BBA,
    "Purple" => 0x730BBA,
    "Magenta" => 0xBA0B76,
    "Gray" => 0xD8D7C8,
    "Black" => 0x000000
  }
  
  module Style
    AREA_CHART_ICON = 'icon-graph-area.gif'
    BAR_CHART_ICON = 'icon-graph-bar.gif'
    LINE_CHART_ICON = 'icon-graph-line.gif'
    
    DASHED_LINE_STYLE_ICON = 'icon-line-dashed.gif'
    SOLID_LINE_STYLE_ICON = 'icon-line-solid.gif'
    
    DIAMOND_POINT_ICON = 'icon-point-diamond.gif'
    SQUARE_POINT_ICON = 'icon-point-square.gif'
  end
  
  # downcase all the keys to make comparision simpler
  COLORS = Hash[*HTML_COLORS.merge(MINGLE_COLORS).collect {|k,v| [k.downcase, v] }.flatten]

  attr_accessor :macro_position
  cattr_reader :charts

  @@charts = {}
  
  class << self
    def color(name)
      return -1 if name.blank?
      return -1 if name == -1
      parse_color(name)
    end
    
    def import_fonts
      fonts_dir = "#{MINGLE_DATA_DIR}/fonts"
      if File.directory?(fonts_dir)
        Dir.glob(File.join(fonts_dir, "*.*")).join(';')
      end
    end

    def extract(template, type, macro_position, options = {})
      options[:host_project] ||= Project.current
      scanner = StringScanner.new(template.to_s)
      1.upto(macro_position) do
        scanner.scan_until(MACRO_SYNTAX)
      end
      raise Macro::ProcessingError, "did not find #{type.bold} at position #{macro_position.bold}" unless scanner[1]
      parameters = Macro.parse_parameters(scanner[2])
      project_to_be_charted = parameters && parameters['project'] ? Project.find_by_identifier(project_identifier_from_parameters(parameters, options[:content_provider])) : options[:host_project]
      
      chart = project_to_be_charted.with_active_project do |p|
        Macro.create(scanner[1], {:project => p, :content_provider => options[:content_provider], :preview  => options[:preview]}, parameters, scanner[0])
      end
      chart.macro_position = macro_position
      chart
    end
    
    def extract_and_generate(template, type, macro_position, options = {})
      chart = self.extract(template, type, macro_position, options)
      chart.generate
    rescue Macro::ProcessingError => e
      Kernel.logger.debug("Ignore macro processing error while extract and generate chart: #{e.message}\n#{e.backtrace.join("\n")}")
      ''
    end
    send(:include, ::ChartCaching)
    
    private
    def parse_color(name)
      if name =~ Macro::WEB_COLOR_REGEXP
        return $1.to_i(16)
      end
      COLORS[name.downcase] || raise("no such color: #{name}")
    end
  end

  def execute_macro
    params = {
      :type => name, 
      :position => context[:macro_position],
      :project_id => context[:content_provider_project].identifier
    }.merge(content_provider.chart_executing_option)
    
    if context[:preview]
      params[:preview] = true
      # put in the current time to prevent caching
      params[:time] = Time.now.to_i
    end
    if (context[:embed_chart])
      embedded_output(params)
    elsif (defined?(::RENDER_CHARTS_AS_TEXT) && ::RENDER_CHARTS_AS_TEXT && @parameters["render_as_text"])
      params[:type] == 'daily-history-chart'? render_chart_for_dhc(params) : render_chart(params)
    else
      chart_callback(params)
    end
  end

  def embedded_output(params)
    view_helper.content_tag('img', nil, :src => "data:image/png;base64,#{base64_encoded_chart}", :alt => self.name)
  end

  def chart_callback(params)
    view_helper.content_tag('img', nil, :src => view_helper.url_for(params.merge({:time => Time.now.to_i})), :alt => self.name)
  end

  def generate
    generate_chart(::C3Renderers)
  end

  def generate_as_text
    generate_chart(::TextChartRenderers)
  end
  
  def font
    Chart.import_fonts
  end
  
  def distinct_property_query(property_name)
    prop_column = CardQuery::Column.new(property_name)
    CardQuery.new(:distinct => true, :columns => [prop_column], :order_by => [prop_column])
  end
  
  def unique_numeric_values_for(prop_def)
    values = distinct_property_query(prop_def.name).single_values
    prop_def.make_uniq(values)
  end
  
  def escape_leading_minus(labels)
    labels.collect do |label|
      label.to_s.gsub(/^-/) { |match| '\-' }
    end
  end

  def parse_date(override, parameter_name)    
    Date.parse_with_hint(override.to_s, project.date_format)
  rescue => e
    raise StandardError.new("Parameter #{parameter_name.to_s.bold} must be a valid date.")
  end

  def set_unique_labels(project, unique_numeric_labels)
    ( @data or [] ).collect! do |(initial_label, value)|
      label = unique_label_name(unique_numeric_labels, initial_label, project)
      [label, value]
    end
    @region_data = @region_data.inject({}) do |new_data, (initial_label, cards)|
      label = unique_label_name(unique_numeric_labels, initial_label, project)
      new_data[label] = cards
      new_data
    end
    @region_mql['conditions'] = @region_mql['conditions'].inject({}) do |new_data, (initial_label, cards)|
      label = unique_label_name(unique_numeric_labels, initial_label, project)
      new_data[label] = cards
      new_data
    end
  end

  def unique_label_name(unique_numeric_labels, initial_label, project)
    unique_numeric_labels.detect do |label|
      next false unless label && initial_label
      label.to_s.to_num(project.precision) == initial_label.to_s.trim.to_num(project.precision)
    end
  end

  def extract_data(data_query = nil, data = nil )
    query = (data_query || @data_query)
    conditions = {}
    ( data or @data ).each do |key, _|
      unless conditions[key]
        conditions[key] = CardQuery::MqlGeneration.new(query.restrict_with(query_restriction([key], query.columns.first)).conditions).execute
      end
    end
    @region_mql['conditions'] = conditions
    @region_mql['project_identifier'] = Project.current.identifier
    @region_data = query.find_cards_ordered_by_property(:limit => 10)
  end


  def replace_nil_labels
    ( @data or [] ).collect! { |(label, value)| label ? [label, value] : [PropertyValue::NOT_SET, value] }
    @region_data.keys.each do |k|
      unless k
        @region_data[PropertyValue::NOT_SET] = @region_data.delete(k)
      end
    end
    @region_mql['conditions'].keys.each do |k|
      unless k
        @region_mql['conditions'][PropertyValue::NOT_SET] = @region_mql['conditions'].delete(k)
      end
    end
  end

  protected
  def query_restriction(keys, column)
    if keys.size == 1
      value =  is_not_set?(keys.first) ? 'NULL' : format(keys.first, column.property_definition)
      return "#{column.mql_name} = #{value}"
    end
    if column.property_definition.is_a?(AssociationPropertyDefinition)
      create_in_query(keys, column)
    else
      create_comparison_query(keys, column)
    end
  end

  def mql_key(key)
    return key.gsub("'", "\\\\'").gsub('"', '\\\\"') if key && key.is_a?(String)
    key
  end

  private
  def render_chart(params)
    view_helper.content_tag(:div, :id => "chart-data") do
      view_helper.link_to_remote("Chart Data", :method => 'get', :url => params.merge({:action => 'chart_as_text'}))
    end
  end

  def render_chart_for_dhc(params)
    chart_callback(params) << view_helper.content_tag(:div, :id => "chart-data") do
      params.merge({:nocache => Time.now.to_i.to_s})
      view_helper.link_to_remote("Chart Data", :method => 'get', :url => params.merge({:action => 'chart_as_text'}))
    end
  end

  def is_not_set?(key)
    key.nil? || key.blank? || key == PropertyValue::NOT_SET
  end

  def create_in_query(keys, column)
    empty_keys = keys.select {|key| is_not_set?(key)}
    comma_separated_keys = (keys - empty_keys).map.each {|key| format(key, column.property_definition, true)}.join(',')
    numbers_selection = card_property_definition?(column.property_definition) ? 'NUMBER' : ''
    null_condition = empty_keys.empty? ? '' : "OR (#{column.mql_name} IS NULL)"
    "(#{column.mql_name} #{numbers_selection} IN (#{comma_separated_keys}) #{null_condition})"
  end

  def create_comparison_query(keys, column)
    lowest_value = format(keys.first, column.property_definition)
    largest_value = format(keys.last, column.property_definition)
    condition = 'AND'
    if is_not_set?(keys.first) || is_not_set?(keys.last)
      # Use OR condition when there is a NULL comparison because the the expression will become (a >= value AND a IS NULL) which
      # wont match, so using OR case.
      condition = 'OR'
    end
    "(#{column.mql_name} >= #{lowest_value} #{condition} #{column.mql_name} <= #{largest_value})"
  end

  def format(key, prop_def, for_in_query = false)
    if user_property_definition?(prop_def) && key
      # Extracting login from the format: "name (login)" only for user property
      "'#{key.match(/[^(]+\(([^)]+)\)/).captures[0]}'"
    elsif card_property_definition?(prop_def) && key
      # Extracting card number from the format: "#number card name" for card property
      key = key.match(/#(\d+).*/).captures[0]
      for_in_query ? key : 'NUMBER ' + key
    elsif is_not_set?(key)
      "''"
    else
      "'#{mql_key(key)}'"
    end
  end

  def user_property_definition?(prop_def)
    prop_def.is_a?(UserPropertyDefinition)
  end

  def card_property_definition?(prop_def)
    prop_def.is_a?(CardPropertyDefinition) || prop_def.is_a?(CardRelationshipPropertyDefinition)
  end

  def self.default_chart_width
    EasyCharts::Style::Sizes::DEFAULT_WIDTH
  end

  def self.default_chart_height
    EasyCharts::Style::Sizes::DEFAULT_HEIGHT
  end

  def generate_chart(renderers)
    project.with_active_project do
      self.class.with_error_handling { do_generate(renderers) }
    end
  end
end
require 'macro/chart_style'
