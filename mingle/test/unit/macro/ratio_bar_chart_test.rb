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

class RatioBarChartTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include RenderableTestHelper::Unit

  def setup
    @member = login_as_member
    @project = ratio_bar_chart_project
    @project.activate
    @project.update_attributes(:date_format => '%Y-%m-%d', :precision => 3)
    @ratio_bar_chart_y_axis_options = {'min' => 0, 'max' => 100,
                                       'tick' => {'format' => ''},
                                       'padding' => {'top' => 5, 'bottom' => 0},
                                       'label'=>{'text'=>'', 'position'=>'outer-middle'}}
  end

  def test_can_render_chart_for_non_host_project
    Card.destroy_all
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'story')

    first_project.with_active_project do |active_project|
      template = '
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = story
            restrict-ratio-with: Status = Closed
            project: ratio_bar_chart_project
        }}
      '

      chart = Chart.extract(template, 'ratio-bar-chart', 1)

      chart_options = JSON.parse(chart.generate)

        assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
      assert_equal ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'], chart.labels
      assert_equal [100, 0, 40, 0], chart.data
      assert template_can_be_cached?(template, active_project)
    end
  end

  def test_can_use_plvs
    Card.destroy_all
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'story')
    create_plv!(@project, :name => 'my_restrict_ratio_wtih', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Status = Closed')

    first_project.with_active_project do |active_project|
      create_plv!(active_project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'ratio_bar_chart_project')

      template = '
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = story
            restrict-ratio-with: (my_restrict_ratio_wtih)
            project: (my_project)
        }}
      '

      chart = Chart.extract(template, 'ratio-bar-chart', 1)

      chart_options = JSON.parse(chart.generate)

      assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
      assert_equal ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'], chart.labels
      assert_equal [100, 0, 40, 0], chart.data
      assert template_can_be_cached?(template, active_project)
    end
  end

  def test_handles_division_by_zero
    @project.connection.delete('DELETE FROM first_project_cards')
    create_card!(:name => 'Blah', :feature => 'Dashboard')
    create_card!(:name => 'Blah', :feature => 'Dashboard')

    template = ' {{
      ratio-bar-chart:
        totals: SELECT Feature, SUM(Size)
        restrict-ratio-with: Status = Closed
    }} '
    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert template_can_be_cached?(template, @project)
    assert_equal ['Dashboard'], chart.labels
    assert_equal [0], chart.data

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  def test_dont_plot_empty_label
    @project.connection.delete('DELETE FROM first_project_cards')
    create_card!(:name => 'Blah', :feature => '   ')

    chart = Chart.extract(' {{
      ratio-bar-chart:
        totals: SELECT Feature, SUM(Size)
        restrict-ratio-with: Status = Closed
    }} ', 'ratio-bar-chart', 1)

    assert_equal [], chart.labels
    assert_equal [], chart.data
  end

  def test_can_work_out_labels_and_calculate_ratios
    Card.destroy_all
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'story')

    chart = Chart.extract(' {{
      ratio-bar-chart:
        totals: SELECT Feature, SUM(Size) WHERE old_type = story
        restrict-ratio-with: Status = Closed
    }} ', 'ratio-bar-chart', 1)
    assert_equal ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'], chart.labels
    assert_equal [100, 0, 40, 0], chart.data

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  def test_validates_required_params
    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')

    assert_dom_content %{Error in ratio-bar-chart macro: Parameters #{'restrict-ratio-with, totals'.bold} are required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax.},
      render('{{ ratio-bar-chart }}', @project)
  end

  def test_can_use_user_property_in_select
    template = %{
      {{
      ratio-bar-chart
      totals: SELECT 'Assigned To', SUM(size) WHERE old_type = Story AND Release = 1
      restrict-ratio-with: Status = Closed
      }}
    }

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_include expected_chart_container_id_attr, render(template, @project)

    assert_equal ['member@email.com (member)'], chart.labels

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  def test_can_use_quotes_on_every_property
    template = %{
      {{
      ratio-bar-chart
      totals: SELECT 'Assigned To', SUM('Size') WHERE 'old_type' = 'Story' AND 'Release' = 1
      restrict-ratio-with: 'Status' = 'Closed' \t
      }}
    }

    assert_include expected_chart_container_id_attr, render(template, @project)
  end

  def test_can_use_quotes_for_initial_property
    template = %{
      {{
      ratio-bar-chart
      totals: SELECT 'Assigned To', SUM('Size') WHERE 'old_type' = 'Story' AND 'Release' = 1
      restrict-ratio-with: 'Status' = Closed
      }}
    }

    assert_include expected_chart_container_id_attr, render(template, @project)
  end

  def test_can_use_property_with_single_quote_in
    status = @project.find_property_definition("status's")
    status.create_value_if_not_exist('Closed')
    status.save!

    template = %{
      {{
      ratio-bar-chart
      totals: SELECT feature, SUM(size) WHERE old_type = story AND release = 1
      restrict-ratio-with: "status's" = closed
      }}
    }

    assert_include expected_chart_container_id_attr, render(template, @project)
  end

  def test_doesnt_report_same_property_required_twice
    template = '{{
      ratio-bar-chart
        totals: SELECT Feature, SUM(Size) WHERE old_type = Story and Release = 1
    }}'

    assert_dom_content "Error in ratio-bar-chart macro: Parameter #{'restrict-ratio-with'.bold} is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax.",
                       render(template, @project)
  end

  def test_parsing_error
    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')

    template = '{{
      ratio-bar-chart
        totals: SELECT Feature, SUM(Size) WHERE old_type = Story and Release = 1
        restrict
    }}'

    assert_dom_content 'Error in ratio-bar-chart macro: Please check the syntax of this macro. The macro markup has to be valid YAML syntax.',
                       render(template, @project)
  end

  def test_can_use_text_properties
    create_card!(:name => 'Blah #1', :size => '1', :iteration => '10', :freetext1 => 'two')
    create_card!(:name => 'Blah #2', :size => '2', :iteration => '11', :freetext1 => 'one')
    create_card!(:name => 'Blah #3', :size => '3', :iteration => '11', :freetext1 => 'two')

    template = '
      {{
        ratio-bar-chart
          totals: SELECT freetext1, SUM(Size) WHERE iteration in (10,11)
          restrict-ratio-with: freetext1 = two
      }}
    '

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_equal %w(one two), chart.labels
    assert_equal [0, 100], chart.data

    assert_include expected_chart_container_id_attr, render(template, @project)

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  def test_can_use_date_properties
    create_card!(:name => 'Blah #1', :size => '1', :iteration => '10', :date_created => '2007-01-02')
    create_card!(:name => 'Blah #2', :size => '2', :iteration => '11', :date_created => '2007-01-01')
    create_card!(:name => 'Blah #3', :size => '3', :iteration => '11', :date_created => '2007-01-02')

    template = %{
      {{
        ratio-bar-chart
          totals: SELECT date_created, SUM(Size) WHERE date_created in ('2007-01-01', '2007-01-02')
          restrict-ratio-with: date_created = '2007-01-02'
      }}
    }

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_equal %w(2007-01-01 2007-01-02), chart.labels
    assert_equal [0, 100], chart.data

    assert_include expected_chart_container_id_attr, render(template, @project)

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  def test_numeric_properties_should_use_project_precision
    create_card!(:name => 'Blah #0', :accurate_estimate => '1.00')
    create_card!(:name => 'Blah #1', :accurate_estimate => '1.2345')
    create_card!(:name => 'Blah #2', :accurate_estimate => '2.3456')
    create_card!(:name => 'Blah #3', :accurate_estimate => '3.6666')
    create_card!(:name => 'Blah #4', :accurate_estimate => '4.6779')

    template = %{
      {{
        ratio-bar-chart
          totals: SELECT accurate_estimate, SUM(accurate_estimate)
          restrict-ratio-with: accurate_estimate = '4.678'
      }}
    }

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_equal %w(1.00 1.235 2.346 3.667 4.678), chart.labels
    assert_equal [0, 0, 0, 0, 100], chart.data

    assert_include expected_chart_container_id_attr, render(template, @project)

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  def test_unmanaged_numeric_properties_should_group_correctly
    create_card!(:name => 'Blah #0', :numeric_free_text => '1.00', :status => 'complete')
    create_card!(:name => 'Blah #2', :numeric_free_text => '1.0', :status => 'open')
    create_card!(:name => 'Blah #1', :numeric_free_text => '1.2', :status => 'new')
    create_card!(:name => 'Blah #3', :numeric_free_text => '3.6', :status => 'complete')
    create_card!(:name => 'Blah #4', :numeric_free_text => '4.6', :status => 'open')
    create_card!(:name => 'Blah #5', :numeric_free_text => '4.600', :status => 'complete')

    template = %{
      {{
        ratio-bar-chart
          totals: SELECT numeric_free_text, SUM(numeric_free_text)
          restrict-ratio-with: status = 'complete'
      }}
    }

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_equal %w(1.00 1.2 3.6 4.600), chart.labels
    assert_equal [50, 0, 100, 50], chart.data
  end

  def test_unmanaged_numeric_properties_should_group_correctly_when_resctrict_conditions_and_totals_conditions_are_in_opposition
    create_card!(:name => 'Blah #0', :numeric_free_text => '1.00', :status => 'complete')
    create_card!(:name => 'Blah #2', :numeric_free_text => '1.0', :status => 'open')
    create_card!(:name => 'Blah #1', :numeric_free_text => '1.2', :status => 'new')
    create_card!(:name => 'Blah #3', :numeric_free_text => '3.6', :status => 'complete')
    create_card!(:name => 'Blah #4', :numeric_free_text => '4.6', :status => 'open')
    create_card!(:name => 'Blah #5', :numeric_free_text => '4.600', :status => 'complete')

    template = %{
      {{
        ratio-bar-chart
          totals: SELECT numeric_free_text, SUM(numeric_free_text) WHERE status != 'complete'
          restrict-ratio-with: status = 'complete'
      }}
    }

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_equal %w(1.00 1.2 4.600), chart.labels
    assert_equal [0, 0, 0], chart.data
  end

  def test_should_use_project_date_format_for_date_label
    create_card!(:name => 'Blah #1', :size => '1', :iteration => '10', :date_created => '2007-01-02')
    create_card!(:name => 'Blah #2', :size => '2', :iteration => '11', :date_created => '2007-01-01')
    create_card!(:name => 'Blah #3', :size => '3', :iteration => '11', :date_created => '2007-01-02')

    template = %{
      {{
        ratio-bar-chart
          totals: SELECT date_created, SUM(Size) WHERE date_created in ('2007-01-01', '2007-01-02')
          restrict-ratio-with: date_created = '2007-01-02'
      }}
    }

    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    chart = Chart.extract(template, 'ratio-bar-chart', 1)
    assert_equal ['01 Jan 2007', '02 Jan 2007'], chart.labels

    chart_options = JSON.parse(chart.generate)

    assert_equal @ratio_bar_chart_y_axis_options, chart_options['axis']['y']
  end

  # bug 2813.
  def test_should_fail_when_more_than_two_totals_columns_are_used
    template = %{
      {{
        ratio-bar-chart
          totals: SELECT 'Assigned To', SUM(size), date_created
          restrict-ratio-with: Status = Closed
      }}
    }

    assert_raise_message(Macro::ProcessingError, /A two-dimensional \(two columns\) query must be supplied for the totals\. The totals contains 3 columns/) do
      chart = Chart.extract(template, 'ratio-bar-chart', 1)
    end
  end

  # bug 2813.
  def test_should_fail_when_less_than_two_totals_columns_are_used
    template = %{
      {{
        ratio-bar-chart
          totals: SELECT 'Assigned To'
          restrict-ratio-with: Status = Closed
      }}
    }

    assert_raise_message(Macro::ProcessingError, /A two-dimensional \(two columns\) query must be supplied for the totals\. The totals contains 1 column/) do
      chart = Chart.extract(template, 'ratio-bar-chart', 1)
    end
  end

  def test_negative_labels_are_available_as_strings
    with_new_project do |project|
      setup_numeric_property_definition('size', [-2, -1, 1])
      project.cards.create!(:name => 'chocolate', :cp_size => '1', :card_type_name => 'Card')
      project.cards.create!(:name => 'cheese', :cp_size => '-2', :card_type_name => 'Card')
      project.cards.create!(:name => 'angelfood', :cp_size => '-1', :card_type_name => 'Card')

      template = %{ {{
        ratio-bar-chart
          totals: SELECT 'size', COUNT(*) WHERE Type = 'Card'
          restrict-ratio-with: Type = 'Card'
      }} }

      chart = Chart.extract(template, 'ratio-bar-chart', 1)
      assert_equal %w(-2 -1 1), chart.labels
    end
  end

  # bug 5009
  def test_card_numbers_with_multiple_digits_should_show_display_all_digits_in_labels
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      release1 = project.cards.find_by_name('release1')

      another_story = project.cards.create!(:name => 'another story', :card_type_name => 'Story')
      card_with_two_digit_number = project.cards.create!(:name => 'carrots', :number => '938', :card_type_name => 'Iteration')
      config.add_child(card_with_two_digit_number, :to => release1)
      config.add_child(another_story, :to => card_with_two_digit_number)

      template = %{ {{
        ratio-bar-chart
          totals: SELECT 'Planning iteration', COUNT(*) WHERE Type = 'Story'
          restrict-ratio-with: Type = 'Story'
      }} }

      chart = Chart.extract(template, 'ratio-bar-chart', 1)
      assert_equal ['#2 iteration1', '#938 carrots'], chart.labels
    end
  end

  def test_ratio_bar_chart_works_with_this_card_keywords
    this_card = @project.cards.first

    @project.cards.create!(:name => 'Blah #0', :cp_numeric_free_text => '1.00', :cp_status => 'complete', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #1', :cp_numeric_free_text => '1.00', :cp_status => 'complete', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #2', :cp_numeric_free_text => '2.00', :cp_status => 'complete', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #3', :cp_numeric_free_text => '2.00', :cp_status => 'new', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #4', :cp_numeric_free_text => '3.00', :cp_status => 'complete', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #5', :cp_numeric_free_text => '3.00', :cp_status => 'open', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #6', :cp_numeric_free_text => '3.00', :cp_status => 'complete', :cp_related_card => this_card, :card_type_name => 'Card')
    @project.cards.create!(:name => 'Blah #7', :cp_numeric_free_text => '3.00', :cp_status => 'complete', :card_type_name => 'Card')

    template = %{
      {{
        ratio-bar-chart
          totals: SELECT 'numeric_free_text', COUNT(*) WHERE 'related card' = this card
          restrict-ratio-with: status = 'complete'
      }}
    }

    chart = Chart.extract(template, 'ratio-bar-chart', 1, {:content_provider => this_card})

    assert_equal %w(1.00 2.00 3.00), chart.labels
    assert_equal [100, 50, 66], chart.data
  end

  def test_should_support_from_tree
    with_three_level_tree_project do |project|
      template = %{ {{
        ratio-bar-chart
          totals: SELECT 'size', COUNT(*) FROM TREE "three level tree"
          restrict-ratio-with: Status != 'closed'
      }} }

      chart = Chart.extract(template, 'data-series', 1)
      assert_equal [100, 100], chart.data

      story = project.card_types.find_by_name('story')
      not_in_tree = create_card!(:size => 1, :name => 'card not in tree', :number => 10, :card_type => story, :status => 'closed')
      chart = Chart.extract(template, 'data-series', 1)
      assert_equal [100,100], chart.data
    end
  end

  def test_can_use_plvs_for_restrict_ratio_with
    create_card!(:name => 'Blah #1', :size => '1', :iteration => '10', :freetext1 => 'two')
    create_card!(:name => 'Blah #2', :size => '2', :iteration => '11', :freetext1 => 'one')
    create_card!(:name => 'Blah #3', :size => '3', :iteration => '11', :freetext1 => 'two')

    create_plv!(@project, :name => 'my_restrict_ratio_with', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'freetext1 = two')
    template = ' {{
        ratio-bar-chart
          totals: SELECT freetext1, SUM(Size) WHERE iteration in (10,11)
          restrict-ratio-with: (my_restrict_ratio_with)
      }}  '

    chart = Chart.extract(template, 'ratio-bar-chart', 1)

    assert_equal %w(one two), chart.labels
    assert_equal [0, 100], chart.data
  end

  # bug 7443
  def test_should_show_error_when_error_exists_in_restrict_ratio_with
    first_project.with_active_project do |active_project|
      template = ' {{
          ratio-bar-chart:
            totals: SELECT name, count(*)
            restrict-ratio-with: type = new
            project: ratio_bar_chart_project
        }}  '

      assert_raise_message(Macro::ProcessingError, "#{'new'.bold} is not a valid value for #{'Type'.bold}, which is restricted to #{'Card'.bold}") do
        chart = Chart.extract(template, 'ratio-bar-chart', 1)
      end
    end
  end

  def test_can_use_formula_properties
    create_card!(:name => 'Blah', :size => 2)
    create_card!(:name => 'Bluhhh', :size => 4)
    create_card!(:name => 'eeeee', :size => 8)
    create_card!(:name => 'ppppppp', :size => 16)
    template = '
      {{
        ratio-bar-chart
         totals: SELECT half, COUNT(*)
         restrict-ratio-with: size > 1
      }}
    '
    chart = extract_chart(template)
    chart_json = JSON.parse(chart.generate)

    expected_json = {'data' =>
                         {'columns' => [['data', 100, 100, 100, 100]],
                          'type' => 'bar',
                          'order' => nil ,
                          'colors' => {'data' => '#0b8aba'}},
                     'size' => {'width' => 600, 'height' => 450},
                     'axis' =>
                         {'x' =>
                              {'type' => 'category',
                               'label' => {'text' => '', 'position' => 'outer-center'},
                               'categories' => %w(1 2 4 8),
                               'tick' => {'rotate' => 45, 'multiline' => false, 'centered' => true}},
                          'y' =>
                              {'tick' => {'format' => ''},
                               'padding' => {'top' => 5, 'bottom' => 0},
                               'min' => 0,
                               'max' => 100,
                               'label' => {'text' => '', 'position' => 'outer-middle'}}},
                     'tooltip' => {'grouped' => false},
                     'legend' => {'hide' => true},
                     'title' => {'text' => ''},
                     'region_mql' =>
                         {'conditions' =>
                              {'1' => 'Size > 1 AND half = 1',
                               '2' => 'Size > 1 AND half = 2',
                               '4' => 'Size > 1 AND half = 4',
                               '8' => 'Size > 1 AND half = 8'},
                          'project_identifier' => 'ratio_bar_chart_project'},
                     'region_data' =>
                         {'8' => {'cards' => [{'name' => 'ppppppp', 'number' => '5'}], 'count' => 1},
                          '4' => {'cards' => [{'name' => 'eeeee', 'number' => '4'}], 'count' => 1},
                          '2' => {'cards' => [{'name' => 'Bluhhh', 'number' => '3'}], 'count' => 1},
                          '1' => {'cards' => [{'name' => 'Blah', 'number' => '2'}], 'count' => 1}},
                     'grid' =>{'y' =>{'show' =>true}, 'x' =>{'show' =>false}}}

    assert_equal(expected_json, chart_json)
  end

  def test_should_use_c3_renderers_and_generate_data_json
    template = ' {{
       ratio-bar-chart
         totals: SELECT Feature, SUM(Size)
         restrict-ratio-with: Status = Closed
    }} '

    chart = extract_chart(template)

    chart_json = JSON.parse(chart.generate)

    assert_equal({
                   'data' => {
                    'columns' => [['data']],
                    'type' => 'bar',
                    'order' => nil,
                    'colors' => {
                        'data' => '#0b8aba'
                    }
                  },
                   'size' => {
                    'width' => 600,
                    'height' => 450
                  },
                   'axis' => {
                    'x' => {
                      'type' => 'category',
                      'label' => {'text' => '', 'position' => 'outer-center'},
                      'categories' => [],
                      'tick' => {
                        'rotate' => 45,
                        'multiline' => false,
                        'centered' => true
                      }
                    },
                    'y' => {
                      'tick' => {
                        'format' => ''
                      },
                      'padding' => { 'top' => 5, 'bottom' => 0},
                      'min' => 0,
                      'max' => 100,
                      'label' => {
                        'text' => '',
                        'position' => 'outer-middle'
                      }
                    }
                  },
                   'tooltip' =>{'grouped' =>false},
                   'legend' =>{'hide' =>true},
                   'region_mql' => {'conditions' =>{}, 'project_identifier' => 'ratio_bar_chart_project'},
                   'title' => {'text' => ''},
                   'region_data' => {},
                   'grid' =>{'y' =>{'show' =>true}, 'x' =>{'show' =>false}}}, chart_json)
  end

  def test_chart_callback_should_return_div_with_chart_renderer
    template = '
      {{
        ratio-bar-chart
         totals: SELECT Feature, SUM(Size)
         restrict-ratio-with: Status = Closed
      }}
    '
    card = @project.cards.first
    chart = RatioBarChart.new({content_provider: card, view_helper: view_helper}, 'ratio-bar-chart', {'totals' => 'SELECT Feature, SUM(Size)',
                                                                                                      'restrict-ratio-with' => 'status = Closed'}, template)

    expected_chart_container_and_script = %Q{<div id='ratiobarchart-Card-#{card.id}-1' class='ratio-bar-chart medium' style='margin: 0 auto; width: #{chart.chart_width}px; height: #{chart.chart_height}px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#ratiobarchart-Card-#{card.id}-1'
      ChartRenderer.renderChart('ratioBarChart', dataUrl, bindTo);
    </script>}

    assert_equal(expected_chart_container_and_script, chart.chart_callback({position: 1, controller: :cards})).strip
  end

  def test_chart_callback_should_add_preview_to_container_id_when_preview_param_is_true
    template = '{{
      ratio-bar-chart
       totals: SELECT Feature, SUM(Size)
       restrict-ratio-with: Status = Closed
    }}'
    card = @project.cards.first
    chart = RatioBarChart.new({content_provider: card, view_helper: view_helper}, 'ratio-bar-chart', {'totals' => 'SELECT Feature, SUM(Size)',
                                                                                                      'restrict-ratio-with' => 'status = Closed'}, template)

    expected_chart_container_and_script = %Q{<div id='ratiobarchart-Card-#{card.id}-1-preview' class='ratio-bar-chart medium' style='margin: 0 auto; width: #{chart.chart_width}px; height: #{chart.chart_height}px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1&preview=true'
      var bindTo = '#ratiobarchart-Card-#{card.id}-1-preview'
      ChartRenderer.renderChart('ratioBarChart', dataUrl, bindTo);
    </script>}

    assert_equal(expected_chart_container_and_script, chart.chart_callback({position: 1, preview: true, controller: :cards})).strip
  end

  def test_default_chart_size_should_be_600_by_450
    template = '
    {{
      ratio-bar-chart
       totals: SELECT Feature, SUM(Size)
       restrict-ratio-with: Status = Closed
    }}'

    chart = extract_chart(template)

    assert_equal(450, chart.chart_height)
    assert_equal(600, chart.chart_width)
  end


   def test_can_generate_region_data_based_on_query
     with_new_project do |project|
       setup_property_definitions 'status' => %w(new done)
       setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
       setup_card_type(project, 'story', :properties => %w(status estimate))
       setup_card_type(project, 'work', :properties => %w(status estimate))
       create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
       create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'done', :estimate => 16)
       create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
       create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'new', :estimate => 8)
       create_card_in_future(6.seconds, :name => 'sixth', :card_type => 'work', :status => 'new', :estimate => 8)
       create_card_in_future(7.seconds, :name => 'seventh', :card_type => 'work', :status => 'in-progress', :estimate => 8)

       template = '
            {{
                ratio-bar-chart
                totals: SELECT Status, count(*)
                restrict-ratio-with: type = story
            }}
          '
       chart = Chart.extract(template, 'ratio-bar-chart', 1)
       new = {:cards => [ { :number => '4', :name => 'fourth'}, {:number => '1', :name => 'first'}], :count => 2 }
       done = {:cards => [ { :number => '3', :name => 'third' }, {:number => '2', :name => 'second'}], :count => 2 }

       assert_equal new, chart.region_data['new']
       assert_equal done, chart.region_data['done']
     end
   end


  def test_can_generate_region_data_for_numeric_property
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'done', :estimate => 16)
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'in-progress', :estimate => 8)

      template = '
            {{
                ratio-bar-chart
                totals: SELECT estimate, count(*)
                restrict-ratio-with: Status = done
            }}
          '
      chart = Chart.extract(template, 'ratio-bar-chart', 1)
      estimate_16 = {:cards => [{:number => '2', :name => 'second'}], :count => 1}
      estimate_4 = {:cards => [{:number => '3', :name => 'third'}], :count => 1}

      assert_nil chart.region_data['2']
      assert_equal estimate_16, chart.region_data['16']
      assert_equal estimate_4, chart.region_data['4']
      assert_nil chart.region_data['8']
    end
  end

  def test_can_generate_region_mql
    Card.destroy_all
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'story')
    first_project.with_active_project do |active_project|
      template = '
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = story
            restrict-ratio-with: Status = Closed
            project: ratio_bar_chart_project
        }}
      '
      chart = Chart.extract(template, 'ratio-bar-chart', 1)

      expected = {
          'conditions' => {
              'Dashboard' => 'old_type = story AND Status = Closed AND Feature = Dashboard',
              'Rate calculator' => "old_type = story AND Status = Closed AND Feature = 'Rate calculator'"
          },
          'project_identifier' => 'ratio_bar_chart_project'
      }

      assert_equal expected, chart.region_mql
    end
  end

  def test_can_generate_correct_region_mql_for_numeric_property
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'done', :estimate => 16)
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'in-progress', :estimate => 8)

      template = '
            {{
                ratio-bar-chart
                totals: SELECT estimate, count(*)
                restrict-ratio-with: Status = done
            }}
          '
      chart = Chart.extract(template, 'ratio-bar-chart', 1)

      expected = {
        'conditions' => {
              '16' => "status = done AND estimate = '16.00'",
              '4' => "status = done AND estimate = '4.00'"
          },
          'project_identifier' => project.identifier
      }
      assert_equal expected, chart.region_mql
    end
  end

  def test_should_be_able_to_specify_chart_width_in_pixels
    template = '{{
      ratio-bar-chart
       totals: SELECT Feature, SUM(Size)
       restrict-ratio-with: Status = Closed
       chart-width: 444 px
    }}'

    chart = extract_chart(template)

    assert_equal(444, chart.chart_width)
  end

  def test_should_be_able_to_specify_chart_height_in_pixels
    template = '{{
      ratio-bar-chart
       totals: SELECT Feature, SUM(Size)
       restrict-ratio-with: Status = Closed
       chart-height:   555px
    }}'

    chart = extract_chart(template)

    assert_equal(555, chart.chart_height)
  end

  private

  def extract_chart(template, options={})
    Chart.extract(template, 'ratio-bar', 1, options)
  end

  def expected_chart_container_id_attr(content_provider = 'RenderableTester', content_provider_id = 'test_id', is_preview = false)
    "id=\"ratiobarchart-#{content_provider}-#{content_provider_id}-1#{'-preview' if is_preview}\""
  end
end
