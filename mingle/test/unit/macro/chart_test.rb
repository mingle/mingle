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

class ChartTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  class DummyChart < Chart
    parameter :param, :required => true
  end
  class FunnyChart < Chart
    parameter :param, :required => true
  end

  class ChartGeneratePng < Chart
    def do_generate(renderers)
      renderer = renderers.pie_chart_renderer(10, 20)
      renderer.make_chart
    end
  end

  def setup
    login_as_member
    @project = first_project
    @project.activate
    Macro.register('dummy-chart', DummyChart)
    Macro.register('funny-chart', FunnyChart)
    Macro.register('chart-generate-png', ChartGeneratePng)
  end

  def teardown
    Macro.unregister('dummy-chart')
    Macro.unregister('funny-chart')
    Macro.unregister('chart-generate-png')
  end

  def test_renders_link_to_chart
    assert_match /<img alt=\"dummy-chart\" src=\"\/projects\/first_project\/wiki\/Dashboard\/chart\/1\/dummy-chart.png/,
      render("{{ dummy-chart param: a }}", @project)
  end

  def test_renders_link_to_host_project_when_charting_for_another_project
    template = %{
      {{
        dummy-chart
          project:  project_without_cards
          param: foo
      }}

      {{
        dummy-chart
          project:  #{data_series_chart_project.identifier}
          param: foo
      }}
    }
    assert_match /<img alt=\"dummy-chart\" src=\"\/projects\/first_project\/wiki\/Dashboard\/chart\/1\/dummy-chart.png/, render(template, @project)
    assert_match /<img alt=\"dummy-chart\" src=\"\/projects\/first_project\/wiki\/Dashboard\/chart\/1\/dummy-chart.png/, render(template, @project)
  end

  def test_can_extract_chart_with_project_other_than_host_project
    template = %{
      {{
        dummy-chart
          project:  project_without_cards
          param: foo
      }}
    }

    assert_equal project_without_cards, Chart.extract(template, 'dummy', 1, @project).project
    assert_equal project_without_cards, Chart.extract(template, 'dummy', 1).project
  end

  def test_should_not_raise_error_if_the_template_is_nil
    assert_raise Macro::ProcessingError do
      Chart.extract(nil, 'dummy', 1, @project)
    end
  end

  def test_validates_chart_before_inserting_link
    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')

    assert_dom_content %{Error in dummy-chart macro: Parameter #{'param'.bold} is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax.},
      render("{{ dummy-chart }}", @project)
  end

  def test_inserts_image_links_with_correct_sequence_even_if_one_chart_fails
    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')

    content = Nokogiri::HTML::DocumentFragment.parse(render("{{ dummy-chart }}{{ dummy-chart param: valid }}", @project))
    assert_equal "Error in dummy-chart macro: Parameter #{'param'.bold} is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax.", content.search(".error").first.inner_text
    assert_match /<img alt=\"dummy-chart\" src=\"\/projects\/first_project\/wiki\/Dashboard\/chart\/2\/dummy-chart.png/, content.search("img").first.to_xhtml
  end

  def test_should_extract_chart_specification
    content = "{{ dummy-chart param: 1 }} \n blah blah \n {{ dummy-chart param: 2 }} \n {{ dummy-chart param: 3}}"

    chart = Chart.extract(content, 'dummy', 3)
    assert_equal DummyChart, chart.class
    assert_equal 3, chart.param

    chart = Chart.extract(content, 'dummy', 2)
    assert_equal DummyChart, chart.class
    assert_equal 2, chart.param

    chart = Chart.extract(content, 'dummy', 1)
    assert_equal DummyChart, chart.class
    assert_equal 1, chart.param
  end

  def test_should_extract_chart_specification_when_there_are_page_variables_first
    template_with_two_variables_and_a_chart = %{
      {{
        project-variable
          name: Current Release
      }}
      <br>
      Current Sprint:
      {{
        project-variable
          name: Current Sprint
      }}
      <-- Click here to see the Sprint Burndown
      {% panel-content %}
      {% dashboard-panel %}
      {% dashboard-panel %}
      {% panel-heading %}
      Burnup - Current Release
      {% panel-heading %}
      {% panel-content %}
      {{
        dummy-chart
          project:  project_without_cards
          param: grangerize
      }}
      {{
        funny-chart
          project:  project_without_cards
          param: winnow
      }}
    }

    assert_equal "dummy-chart", Chart.extract(template_with_two_variables_and_a_chart, 'dummy', 3, @project).name
    assert_equal "funny-chart", Chart.extract(template_with_two_variables_and_a_chart, 'funny', 4, @project).name
  end

  def test_should_extract_cumulative_flow_graph
    template = %{
      {{
        cumulative-flow-graph
          project:  #{data_series_chart_project.identifier}
          series :
              - data : 'Select status, count(*) where type = Story'
      }}
    }

    assert_equal 'cumulative-flow-graph', Chart.extract(template, 'cumulative-flow-graph', 1).name
  end

  def test_can_extract_and_provide_proper_error_when_no_parameters
    template = %{
      {{ pie-chart }}
    }

    begin
      Chart.extract(template, 'dummy', 1, @project).project
    rescue Macro::ProcessingError => e
      assert e.message.include?("Parameter #{'data'.bold} is required")
      return
    end
    fail "should have failed"
  end

  def test_import_fonts
    FileUtils.mkdir_p(File.join(MINGLE_DATA_DIR, 'fonts'))
    Dir["#{File.join(Rails.root, 'test/data/fonts')}/*.*"].each do |font|
      FileUtils.cp(font, File.join(MINGLE_DATA_DIR, 'fonts'))
    end
    assert_equal "#{MINGLE_DATA_DIR}/fonts/font.ttf;#{MINGLE_DATA_DIR}/fonts/font2.ttf;#{MINGLE_DATA_DIR}/fonts/sanf.dfont".split(';').sort, Chart.import_fonts.split(';').sort
  end
end
