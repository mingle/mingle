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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class CumulativeFLowGraphTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    login_as_member
    @project = stack_bar_chart_project
    @project.activate
  end


  test 'chart_callback_should_return_div_with_chart_renderer_for_cumulative_flow_graph' do
    template = ' {{
    cumulative-flow-graph
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

    card = @project.cards.first
    chart = CumulativeFlowGraph.new({content_provider: card, view_helper: view_helper}, 'cumulative-flow-graph', {'series' => [{'data' => 'select status, count(*)',
                                                                                                                                'label' => 'Projects',
                                                                                                                                'color' => '#FF0000',
                                                                                                                                'combine' => 'overlay-bottom'}]}, template)
    expected_chart_container_and_script = %Q{<div id='cumulative-flow-graph-Card-#{card.id}-1-preview' class='cumulative-flow-graph medium' style='margin: 0 auto; width: #{chart.chart_width}px; height: #{chart.chart_height}px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1&preview=true'
      var bindTo = '#cumulative-flow-graph-Card-#{card.id}-1-preview'
      ChartRenderer.renderChart('cumulativeFlowGraph', dataUrl, bindTo);
    </script>}

    assert_equal(expected_chart_container_and_script, chart.chart_callback({position: 1, preview: true, controller: :cards}))
  end

  test 'should_generate_chart_json' do
    with_new_project do |project|
      project.add_member(User.current)
      setup_property_definitions status: %w(new done)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

      chart = extract_chart(%{ {{
        cumulative-flow-graph
          labels : Select DISTINCT status
          conditions  : type = Story
          chart-size  : small
          legend-position : bottom
          series:
            - label       : LabelOne
              color       : Yellow
              combine     : overlay-top
              type        : area
              data-point-symbol: diamond
              data        : SELECT status, count(*) WHERE estimate = '2'
            - label       : LabelTwo
              color       : Green
              combine     : overlay-bottom
              type        : line
              data-point-symbol: square
              line-style        : line
              data        : SELECT status, count(*) WHERE estimate = '4'
      }} })

      chart_json = JSON.parse(chart.generate)

      expected_data_json = {"columns"=>[["LabelTwo", 1, 3], ["LabelOne", 1, 1]],
                   "type"=>"area",
                   "order"=>nil,
                   "types"=>{"LabelTwo"=>"line"},
                   "colors"=>{"LabelTwo"=>"green", "LabelOne"=>"yellow"},
                   "groups"=>[%w(LabelTwo LabelOne)],
                   "trends"=>[],
                   "regions"=>{},
                   "labels"=>{"format"=>{}}}

      expected_region_data_json = {"new"=>
                              {"LabelTwo"=>{"cards"=>[{"name"=>"second", "number"=>"2"}], "count"=>1},
                               "LabelOne"=>{"cards"=>[{"name"=>"first", "number"=>"1"}], "count"=>1}},
                          "done"=>
                              {"LabelTwo"=>
                                   {"cards"=>
                                        [{"name"=>"fourth", "number"=>"4"},
                                         {"name"=>"third", "number"=>"3"},
                                         {"name"=>"second", "number"=>"2"}],
                                    "count"=>3},
                               "LabelOne"=>{"cards"=>[{"name"=>"first", "number"=>"1"}], "count"=>1}}}

      expected_region_mql_data = {"conditions"=>
                             {"new"=>
                                  {"LabelTwo"=>"estimate = 4 AND Type = Story AND status = new",
                                   "LabelOne"=>"estimate = 2 AND Type = Story AND status = new"},
                              "done"=>
                                  {"LabelTwo"=>
                                       "estimate = 4 AND Type = Story AND status >= new AND status <= done",
                                   "LabelOne"=>
                                       "estimate = 2 AND Type = Story AND status >= new AND status <= done"}},
                         "project_identifier"=>
                             {"LabelTwo"=>project.identifier, "LabelOne"=>project.identifier}}

      expected_chart_formatting_data = {"legend"=>{"position"=>"bottom"},
                                  "bar"=>{"width"=>{"ratio"=>0.85}},
                                  "size"=>{"width"=>300, "height"=>225},
                                  "axis"=>
                                      {"x"=>
                                           {"type"=>"category",
                                            "label"=>{"text"=>"status", "position"=>"outer-center"},
                                            "categories"=> %w(new done),
                                            "tick"=>{"rotate"=>45, "multiline"=>false, "centered"=>true}},
                                       "y"=>
                                           {"padding"=>{"top"=>25},
                                            "label"=>{"text"=>"Number of cards", "position"=>"outer-middle"}}},
                                  "tooltip"=>{"grouped"=>false},
                                  "interaction"=>{"enabled"=>true},
                                  "point"=>
                                      {"show"=>false,
                                       "symbols"=>{"LabelTwo"=>"square", "LabelOne"=>"diamond"},
                                       "focus"=>{"expand"=>{"enabled"=>false}}},
                                  "title"=>{"text"=>""},
                                  "grid"=>{"y"=>{"show"=>true}, "x"=>{"show"=>false}}}

      actual_data_json = chart_json.delete('data')
      actual_region_data_json = chart_json.delete('region_data')
      actual_region_mql_json = chart_json.delete('region_mql')
      actual_chart_formatting_data = chart_json

      assert_equal(expected_data_json, actual_data_json)
      assert_equal(expected_region_data_json, actual_region_data_json)
      assert_equal(expected_region_mql_data, actual_region_mql_json)
      assert_equal(expected_chart_formatting_data, actual_chart_formatting_data)
    end
  end

  private

  def extract_chart(template, options={})
    Chart.extract(template, 'cumulative-flow-graph', 1, options)
  end
end
