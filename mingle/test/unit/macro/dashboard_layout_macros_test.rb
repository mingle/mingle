#encoding: UTF-8

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

class DashboardLayoutMacrosTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    login_as_member
    @project = create_project(:users => [User.current])
    setup_property_definitions('feature' => [], 'status' => ['New', 'In Progress', 'Done', 'Closed'], 'release' => (1..5).to_a,
      'Came Into Scope on Iteration' => (1..20).to_a, 'old_type' => ["Story"], 'iteration' => (1..20).to_a)
    setup_numeric_property_definition 'size' , (1..10).to_a
  end

  def test_renders_link_to_chart
    template = %{
      Blah blah blah

      {% two-columns %}
        {% left-column %}
          {% dashboard-panel %}
          {% dashboard-panel %}

          {% dashboard-panel %}
          {% dashboard-panel %}
        {% left-column %}

        {% right-column %}
          {% dashboard-panel %}
          {% dashboard-panel %}

          {% dashboard-panel %}
          {% dashboard-panel %}
        {% right-column %}
      {% two-columns %}
    }
    expected = %{
        <p>Blah blah blah</p>

        <div class="yui-g">
            <div class="yui-u first">
              <div class="dashboard-panel">
              </div>

              <div class="dashboard-panel">
              </div>
            </div>
            <div class="yui-u">
              <div class="dashboard-panel">
              </div>

              <div class="dashboard-panel">
              </div>
           </div>
        </div>

        <div class="clear-both clear_float"></div>
    }
    page = @project.pages.create!(:name => 'links_to_chart', :content => template)
    page.redcloth = true
    page.convert_redcloth_to_html!
    assert_equal_ignoring_spaces expected, page.content
  end

  def test_works_with_chart_macros_too
    template = %{
      {% two-columns %}

        {% left-column %}

          {% dashboard-panel %}
h2. Overall progress

{{
  stack-bar-chart
    conditions  : old_type = Story AND Release = 1
    labels      : SELECT DISTINCT Iteration
    cumulative  : true
    series:
      - label       : Original
        color       : Yellow
        combine     : total
        data        : >
          SELECT 'Came Into Scope on Iteration', SUM(Size)
      - label       : Completed
        color       : Green
        combine     : overlay-bottom
        data        : >
          SELECT Iteration, SUM(Size)
          WHERE Status = 'Closed'
      - label       : In Progress
        color       : LightBlue
        combine     : overlay-bottom
        data        : >
          SELECT Iteration, SUM(Size)
          WHERE Status = 'In Progress'
      - label       : New
        color       : Red
        combine     : overlay-top
        data        : >
          SELECT 'Came Into Scope on Iteration', SUM(Size)
          WHERE NOT 'Came Into Scope on Iteration' = 1
}}
          {% dashboard-panel %}

          {% dashboard-panel %}
h2. Progress - Last Iteration

TODO
          {% dashboard-panel %}

        {% left-column %}

        {% right-column %}

          {% dashboard-panel %}
h2. Feature completeness

{{
  ratio-bar-chart
    totals : SELECT Feature, SUM(Size) WHERE old_type = Story AND Release = 1 GROUP BY Feature
    restrict-ratio-with : Status = Closed
}}
          {% dashboard-panel %}

          {% dashboard-panel %}
h2. Milestones

|_. Description |_. Date |_. Status |
| Internal alpha to all departments | 20th March 2007 | On track |
| Public beta | 15th May 2007 | On track |

          {% dashboard-panel %}

        {% right-column %}

      {% two-columns %}


      {% dashboard-panel %}
h2. Risks and Issues

      {% dashboard-panel %}

    }

    page = @project.pages.create!(:name => 'big page', :content => template)

    expected = %{

      <div class="yui-g">
          <div class="yui-u first">
            <div class="dashboard-panel">

            <h2>Overall progress</h2>

            {{
              stack-bar-chart
                conditions  : old_type = Story AND Release = 1
                labels      : SELECT DISTINCT Iteration
                cumulative  : true
                series:
                  - label       : Original
                    color       : Yellow
                    combine     : total
                    data        : >
                      SELECT 'Came Into Scope on Iteration', SUM(Size)
                  - label       : Completed
                    color       : Green
                    combine     : overlay-bottom
                    data        : >
                      SELECT Iteration, SUM(Size)
                      WHERE Status = 'Closed'
                  - label       : In Progress
                    color       : LightBlue
                    combine     : overlay-bottom
                    data        : >
                      SELECT Iteration, SUM(Size)
                      WHERE Status = 'In Progress'
                  - label       : New
                    color       : Red
                    combine     : overlay-top
                    data        : >
                      SELECT 'Came Into Scope on Iteration', SUM(Size)
                      WHERE NOT 'Came Into Scope on Iteration' = 1
            }}

            </div>

            <div class="dashboard-panel">

            <h2>Progress – Last Iteration</h2>


            <p>TODO</p>

            </div>
          </div>
          <div class="yui-u">
            <div class="dashboard-panel">

            <h2>Feature completeness</h2>

            {{
              ratio-bar-chart
                totals : SELECT Feature, SUM(Size) WHERE old_type = Story AND Release = 1 GROUP BY Feature
                restrict-ratio-with : Status = Closed
            }}

            </div>

            <div class="dashboard-panel">

            <h2>Milestones</h2>


            <table>
              <tbody>
              <tr>
                <th>Description </th>
                <th>Date </th>
                <th>Status </th>
              </tr>
              <tr>
                <td> Internal alpha to all departments </td>
                <td> 20th March 2007 </td>
                <td> On track </td>
              </tr>
              <tr>
                <td> Public beta </td>
                <td> 15th May 2007 </td>
                <td> On track </td>
              </tr>
              </tbody>
            </table>

            </div>
         </div>
      </div>

      <div class="clear-both clear_float"></div>

      <div class="dashboard-panel">

      <h2>Risks and Issues</h2>



      </div>
    }
    page.redcloth = true
    page.convert_redcloth_to_html!
    assert_equal_ignoring_spaces expected, page.content
  end

  def test_body_macros_dont_get_quoted_during_conversion_to_html
    template = "Blah\n\n  {% dashboard-panel %}\n  {% dashboard-panel %}\n\n"
    page = @project.pages.create!(:name => 'with some body macros', :content => template)
    page.convert_redcloth_to_html!
    expected = %{
      <p>Blah</p>


      <div class="dashboard-panel">

      </div>
    }
    assert_equal_ignoring_spaces expected, page.content
  end

end
