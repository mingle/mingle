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

class StackBarChartTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include RenderableTestHelper::Unit
  def setup
    login_as_member
    @project = stack_bar_chart_project
    @project.activate
  end

  test 'can_render_for_a_non_host_project' do
    first_project.with_active_project do |active_project|
      template = ' {{
        stack-bar-chart
          project: stack_bar_chart_project
          cumulative  : true
          conditions  : old_type = Story
          series:
            - label       : Original
              color       : yellow
              combine     : total
              data        : >
                SELECT Iteration, SUM(Size) ORDER BY Iteration
      }} '
      chart = extract_chart(template)

      assert template_can_be_cached?(template, active_project)
      assert_equal %w(1 2 3 4 5), chart.labels_for_plot
    end
  end

  test 'can_use_plvs' do
    create_plv!(@project, :name => 'my_conditions', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'old_type = Story')

    first_project.with_active_project do |active_project|
      create_plv!(active_project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'stack_bar_chart_project')

      template = ' {{
        stack-bar-chart
          project: (my_project)
          cumulative  : true
          conditions  : (my_conditions)
          series:
            - label       : Original
              color       : yellow
              combine     : total
              data        : >
                SELECT Iteration, SUM(Size) ORDER BY Iteration
      }} '
      chart = extract_chart(template)

      assert template_can_be_cached?(template, active_project)
      assert_equal %w(1 2 3 4 5), chart.labels_for_plot
    end
  end

  test 'series_from_different_project' do
    template = %{ {{
      stack-bar-chart
        cumulative: false
        series:
          - project     : card_query_project
            label       : card_query_project_scope
            data        : SELECT 'Release', COUNT(*)
          - project     : stack_bar_chart_project
            label       : stack_bar_chart_project_scope
            data        : SELECT 'Release', COUNT(*)
    }} }

    chart = extract_chart(template)

    assert_equal %w(1 2), chart.labels_for_plot
    assert_equal [1, 0], chart.series_by_label['card_query_project_scope'].values
    assert_equal [7, 1], chart.series_by_label['stack_bar_chart_project_scope'].values
  end

  # bug #9795
  test 'can_render_chart_with_numeric_label' do
    template = %{ {{
      stack-bar-chart
        cumulative: false
        series:
          - project     : card_query_project
            label       : 123
            data        : SELECT 'Release', COUNT(*)
    }} }

    chart = extract_chart(template)
    chart.extract_region_data
    chart.extract_region_mql

    assert_equal %w(1 2), chart.labels_for_plot
    assert_equal [1, 0], chart.series_by_label['123'].values
  end

  test 'can_render_chart_with_name_stacked_bar_chart' do
    template = %{ {{
      stacked-bar-chart
        cumulative: false
        series:
          - project     : card_query_project
            label       : 123
            data        : SELECT 'Release', COUNT(*)
    }} }

    chart = extract_chart(template)
    chart.extract_region_data
    chart.extract_region_mql

    assert_equal %w(1 2), chart.labels_for_plot
    assert_equal [1, 0], chart.series_by_label['123'].values
  end

  # for bug 2722
  test 'should_be_able_to_use_comparison_operators_with_properties' do
    create_project.with_active_project do |project|
      project.add_member(User.current)
      setup_date_property_definition('Due Date')
      setup_date_property_definition('Completed On')
      create_card!(:name => 'card 1', :'Due Date' => '2007-01-01', :'Completed On' => '2007-01-02')
      create_card!(:name => 'card 2', :'Due Date' => '2007-01-02', :'Completed On' => '2007-01-02')
      create_card!(:name => 'card 3', :'Due Date' => '2007-01-02', :'Completed On' => '2007-01-02')
      create_card!(:name => 'card 4', :'Due Date' => '2007-01-11', :'Completed On' => '2007-01-02')
      create_card!(:name => 'card 5')
      create_card!(:name => 'card 6', :'Due Date' => '2007-01-11')
      create_card!(:name => 'card 7', :'Completed On' => '2007-01-02')

      chart = extract_chart(%{
        {{
          stack-bar-chart
          conditions: Type= 'Card'
          labels: SELECT DISTINCT 'Due Date' ORDER BY 'Due Date'
          cumulative: true
          series:
            - label: Late
              color: red
              type: line
              data: SELECT 'Due Date', COUNT(*) WHERE 'Due Date' < Property 'Completed On'
            - label: On Schedule
              color: green
              type: line
              data: SELECT 'Due Date', COUNT(*) WHERE 'Due Date' >= Property 'Completed On'
        }}
      })

      assert_equal ['01 Jan 2007',
                    '02 Jan 2007',
                    '03 Jan 2007',
                    '04 Jan 2007',
                    '05 Jan 2007',
                    '06 Jan 2007',
                    '07 Jan 2007',
                    '08 Jan 2007',
                    '09 Jan 2007',
                    '10 Jan 2007',
                    '11 Jan 2007'], chart.labels_for_plot
      assert_equal({'01 Jan 2007' =>1}, chart.series_by_label['Late'].values_as_coords)
      assert_equal({'11 Jan 2007' =>1, '02 Jan 2007' =>2}, chart.series_by_label['On Schedule'].values_as_coords)
      assert_equal [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], chart.series_by_label['Late'].values
      assert_equal [0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3], chart.series_by_label['On Schedule'].values
    end
  end

  test 'should_group_equivalent_unmanaged_numeric_values_into_same_buckets_across_all_the_series_and_labels' do
    create_project.with_active_project do |project|
      project.add_member(User.current)
      project.update_attributes(:precision => 3)
      setup_numeric_text_property_definition('initial_estimate')
      setup_numeric_property_definition('size', %w(1 2.0 4 8.00))

      create_card!(:name => 'card 1', :initial_estimate => '1.00', :size => '1')
      create_card!(:name => 'card 2', :initial_estimate => '2', :size => '1')
      create_card!(:name => 'card 3', :initial_estimate => '3.0', :size => '2.0')
      create_card!(:name => 'card 4', :initial_estimate => '2.000', :size => '4')
      create_card!(:name => 'card 5', :initial_estimate => '3', :size => '8.00')
      create_card!(:name => 'card 6', :initial_estimate => '1', :size => '8.00')
      create_card!(:name => 'card 7', :initial_estimate => '4.0', :size => '4')

      chart = extract_chart('
        {{
          stack-bar-chart
          labels: SELECT initial_estimate
          series:
            - label: final_size
              type: line
              data: SELECT initial_estimate, SUM(size)
        }}
      ')

      assert_equal %w(1.00 2.000 3.0 4.0), chart.labels_for_plot
      actual = Hash[*chart.series_by_label['final_size'].values_as_coords.collect {|key, value| [key.trim, value] }.flatten]
      assert_equal({'1.000' => 9, '2.000' => 5, '3.000' => 10, '4.000' => 4}, actual)
      assert_equal [9, 5, 10, 4], chart.series_by_label['final_size'].values

      chart = extract_chart('
        {{
          stack-bar-chart
          series:
            - label: final_size
              type: line
              data: SELECT initial_estimate, SUM(size)
        }}
      ')

      assert_equal %w(1.00 2.000 3.0 4.0), chart.labels_for_plot
      actual = Hash[*chart.series_by_label['final_size'].values_as_coords.collect {|key, value| [key.trim, value] }.flatten]
      assert_equal({'1.000' => 9, '2.000' => 5, '3.000' => 10, '4.000' => 4}, actual)
      assert_equal [9, 5, 10, 4], chart.series_by_label['final_size'].values

    end
  end

  test 'can_render_multiple_series_with_different_combination_strategies' do
    chart = extract_chart(%{ {{
      stack-bar-chart
        conditions  : old_type = Story AND Release = 1
        cumulative  : true
        series:
          - label       : Plan
            old_type    : line
            data        : >
              SELECT 'Planned for Iteration', SUM(Size)
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
    }} })

    assert_equal %w(1 2 3), chart.labels_for_plot
    assert_equal({'1' =>16, '2' =>2}, chart.series_by_label['Original'].values_as_coords)
    assert_equal({'3' => 2}, chart.series_by_label['In Progress'].values_as_coords)
    assert_equal({'1' =>5, '2' =>4, '3' =>3}, chart.series_by_label['Completed'].values_as_coords)
    assert_equal ['Plan', 'Completed', 'In Progress', 'Original', 'New'], chart.series.collect(&:label)
    assert_equal [0, 2, 2], chart.series_by_label['New'].values
    assert_equal [11, 7, 2], chart.series_by_label['Original'].values
    assert_equal [0, 0, 2], chart.series_by_label['In Progress'].values
    assert_equal [5, 9, 12], chart.series_by_label['Completed'].values
  end

  test 'can_render_burnup_with_classical_look' do
    # the classical burnup is essentially two area charts
    chart = extract_chart(%{ {{
      stack-bar-chart
        conditions  : old_type = Story AND Release = 1
        labels      : SELECT DISTINCT Iteration
        cumulative  : true
        series:
          - label       : Original
            color       : Yellow
            combine     : total
            old_type    : area
            data        : >
              SELECT 'Came Into Scope on Iteration', SUM(Size)
          - label       : Completed
            color       : Green
            combine     : overlay-bottom
            old_type    : area
            data        : >
              SELECT Iteration, SUM(Size)
              WHERE Status = 'Closed'
    }} })

    assert_equal %w(1 2 3), chart.labels_for_plot
    assert_equal({'1' =>16, '2' =>2}, chart.series_by_label['Original'].values_as_coords)
    assert_equal({'1' =>5, '2' =>4, '3' =>3}, chart.series_by_label['Completed'].values_as_coords)
    assert_equal %w(Completed Original), chart.series.collect(&:label)
    assert_equal [11, 9, 6], chart.series_by_label['Original'].values
    assert_equal [5, 9, 12], chart.series_by_label['Completed'].values
  end

  # Bug 7677
  test 'should_inform_user_about_value_of_total_less_than_sum_of_overlay_error_when_chart_is_extracted' do
    template = %{ {{
      stack-bar-chart
        conditions  : old_type = Story AND Release = 1
        labels      : SELECT DISTINCT Iteration
        cumulative  : true
        series:
          - label       : Original
            color       : Yellow
            combine     : overlay-bottom
            old_type    : area
            data        : >
              SELECT 'Came Into Scope on Iteration', SUM(Size)
          - label       : Completed
            color       : Green
            combine     : total
            old_type    : area
            data        : >
              SELECT Iteration, SUM(Size)
              WHERE Status = 'Closed'
    }} }

    assert_raise_message(Macro::ProcessingError, /less than sum value of the overlay conditions for label/) do
      extract_chart template
    end
  end

  test 'can_render_one_single_series' do
    template = ' {{
      stack-bar-chart
        cumulative  : true
        conditions  : old_type = Story
        series:
          - label       : Original
            color       : yellow
            combine     : total
            data        : >
              SELECT Iteration, SUM(Size) ORDER BY Iteration
    }} '
    chart = extract_chart(template)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.labels_for_plot
  end

  test 'can_specify_web_color_for_chart' do
    chart = extract_chart(' {{
      stack-bar-chart
        cumulative  : true
        series:
          - label       : Original
            color       : #ABCDEF
            combine     : total
            data        : >
              SELECT Iteration, SUM(Size) ORDER BY Iteration
    }} ')
    assert_equal '#ABCDEF', chart.series.first.color
  end

  test 'can_use_long_property_names' do
    chart = extract_chart(%{ {{
      stack-bar-chart
        cumulative  : true
        series:
          - label       : Development Done
            data        : >
              SELECT 'Development Done in Iteration', SUM(Size)
    }} })

    assert_equal 'Development Done', chart.series.first.label
    assert_equal [], chart.series_data_for_plot('Development Done')
  end

  test 'can_render_one_single_series_with_text_property' do
    template = ' {{
      stack-bar-chart
        cumulative  : true
        conditions  : text_old_type = Story
        series:
          - label       : Original
            color       : yellow
            combine     : total
            data        : >
              SELECT text_iteration, SUM(Size) ORDER BY text_iteration
    }} '
    chart = extract_chart(template)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3), chart.labels_for_plot
  end

  test 'can_render_one_single_series_with_date_property' do
    template = ' {{
      stack-bar-chart
        cumulative  : true
        series:
          - label       : Original
            color       : yellow
            combine     : total
            data        : SELECT date_created, SUM(Size) ORDER BY date_created
    }} '
    chart = extract_chart(template)

    assert template_can_be_cached?(template, @project)
    assert_equal ['01 Jan 2007', '02 Jan 2007', '03 Jan 2007', '04 Jan 2007', '05 Jan 2007', '06 Jan 2007'], chart.labels_for_plot
    assert_equal [6, 15, 18, 18, 18, 21], chart.series_by_label['Original'].values
  end

  test 'should_render_date_labels_in_ascending_order_to_preserve_x_axis_labels' do
    @project.update_attributes(:date_format => Date::LONG_MONTH_DAY_YEAR)
    @project.cards.create!(:name => 'c1', :card_type_name => 'card', :cp_date_created => 'Dec 30 2006', :cp_size => '1', :cp_release => '1')
    template = %{ {{
      stack-bar-chart
        conditions: 'Release' = '1' AND date_created IS NOT NULL
        cumulative: true
        label-start: '2006-11-30'
        label-end: '2007-11-30'
        series:
        - label: Scope
          color: gray
          type: area
          data: SELECT date_created, SUM(Size)
    }} }
    chart = extract_chart(template)

    assert template_can_be_cached?(template, @project)
    assert_equal ['Dec 30 2006', 'Dec 31 2006', 'Jan 01 2007', 'Jan 02 2007', 'Jan 03 2007', 'Jan 04 2007', 'Jan 05 2007', 'Jan 06 2007'], chart.labels_for_plot
    assert_equal [1, 1, 7, 16, 19, 19, 19, 19], chart.series_by_label['Scope'].values
  end


  # bug 6211
  test 'x_labels_property_is_a_card_should_order_by_card_name  ' do
    with_new_project do |project|
      login_as_admin
      setup_card_relationship_property_definition('Iteration Added to Scope')

      card = create_card!(:name => 'Iteration 2', :number => 10)
      card2 = create_card!(:name => 'Iteration 1', :number => 14)

      create_card!(:name => 'a', :number => 11, 'Iteration Added to Scope' => card.id)
      create_card!(:name => 'a', :number => 15, 'Iteration Added to Scope' => card.id)
      create_card!(:name => 'f', :number => 12, 'Iteration Added to Scope' => card2.id)

      template = %{ {{
        stack-bar-chart
          labels: SELECT DISTINCT 'Iteration Added to Scope'
          cumulative: false
          series:
            - label: Cake
              data: SELECT 'Iteration Added to Scope', COUNT(*)
      }} }

      chart = extract_chart(template)
      assert_equal ['(not set)', '#14 Iteration 1', '#10 Iteration 2'], chart.labels_for_plot
      assert_equal [2, 1, 2], chart.series_by_label['Cake'].values
    end
  end


  test 'numeric_labels_obey_start_and_end_number' do
    @project.cards.each_with_index do |card, index|
      card.cp_size = index + 1
      card.save!
    end

    template = ' {{
      stack-bar-chart
        cumulative  : true
        x-label-start: 2
        x-label-end: 4
        series:
          - label       : Original
            color       : yellow
            combine     : total
            data        : SELECT Size, COUNT(*) ORDER BY size
    }} '
    chart = extract_chart(template)

    assert_equal '2', chart.labels_for_plot.first.to_s
    assert_equal '4', chart.labels_for_plot.last.to_s
  end

  test 'numeric_labels_obey_start_overrides' do
    @project.cards.each_with_index do |card, index|
      card.cp_size = index + 1
      card.save!
    end

    template = ' {{
      stack-bar-chart
        cumulative  : true
        x-label-start: 2
        series:
          - label       : Original
            color       : yellow
            combine     : total
            data        : SELECT Size, COUNT(*) ORDER BY size
    }} '
    chart = extract_chart(template)

    assert_equal '2', chart.labels_for_plot.first.to_s
    assert_equal @project.cards.size.to_s, chart.labels_for_plot.last.to_s
  end

  test 'numeric_labels_obey_start_and_end_number_with_float_number' do
    @project.cards.each_with_index do |card, index|
      card.cp_size = index + 1 + 0.5
      card.save!
    end

    template = ' {{
      stack-bar-chart
        cumulative  : true
        x-label-start: 2.5
        x-label-end: 3.5
        series:
          - label       : Original
            color       : yellow
            combine     : total
            data        : SELECT Size, COUNT(*) ORDER BY size
    }} '
    chart = extract_chart(template)

    assert_equal '2.5', chart.labels_for_plot.first.to_s
    assert_equal '3.5', chart.labels_for_plot.last.to_s
  end

  test 'should_show_all_if_x_label_start_and_x_label_end_included_all' do
    @project.cards.each_with_index do |card, index|
      card.cp_size = index
      card.save!
    end
    template = ' {{
      stack-bar-chart
        cumulative  : false
        x-label-start: -1
        x-label-end: 9999
        labels: SELECT size
        series:
          - label       : Original
            data        : SELECT Size, COUNT(*) ORDER BY size
    }} '
    chart = extract_chart(template)

    assert_equal @project.cards.size, chart.labels_for_plot.size
  end

  test 'user_property_series' do
    @project.add_member create_user!(:name => 'MEMBER@email.com', :login => 'smart_sorted')
    template = '  {{
      stack-bar-chart
        series:
          - label: Queue Size
            color: Yellow
            data: SELECT owner, SUM(Size) ORDER BY owner
    }} '
    chart = extract_chart(template)
    assert_equal ['bob@email.com (bob)', 'first@email.com (first)', 'longbob@email.com (longbob)', 'member@email.com (member)', 'MEMBER@email.com (smart_sorted)', 'proj_admin@email.com (proj_admin)'], chart.labels_for_plot
    assert_equal [3, 11, 5, 0, 0, 0], chart.series_by_label['Queue Size'].values
  end

  test 'specify_user_property_labels' do
    @project.add_member user = create_user!(:name => 'LONGBOB@email.com', :login => 'smart_sorted')
    create_card!(:size => 7, :name => 'mr. smart sort', :owner => user.id)
    template = '  {{
      stack-bar-chart
        labels: select owner order by owner
        series:
          - label: Queue Size
            color: Yellow
            data: SELECT owner, SUM(Size) ORDER BY owner
    }} '
    chart = extract_chart(template)
    assert_equal ['bob@email.com (bob)', 'first@email.com (first)', 'longbob@email.com (longbob)', 'LONGBOB@email.com (smart_sorted)', '(not set)'], chart.labels_for_plot
    assert_equal [3, 11, 5, 7, 2], chart.series_by_label['Queue Size'].values
  end

  test 'x_label_start_and_end_using_user_property' do
    template = '  {{
      stack-bar-chart
        x-label-start: first
        x-label-end: member
        series:
          - label: Queue Size
            color: Yellow
            data: SELECT owner, SUM(Size) ORDER BY owner
    }} '
    chart = extract_chart(template)

    assert_equal ['first@email.com (first)', 'longbob@email.com (longbob)', 'member@email.com (member)'], chart.labels_for_plot
  end


  test 'should_not_have_error_when_there_is_no_cards' do
    with_new_project do |project|
      project.add_member(User.current)
      setup_date_property_definition('StartDate')
      template = %{ {{
        stack-bar-chart
          series:
            - label: 'StartDate'
              color: Yellow
              data: SELECT 'StartDate', COUNT(*)
      }} }

      chart = extract_chart(template)

      assert_equal 'StartDate', chart.series.first.label
      assert_equal [], chart.series_data_for_plot('StartDate')
    end
  end

  # bug 4941
  test 'labels_display_not_set_for_tree_relationship_properties' do
    create_tree_project(:init_planning_tree_with_multi_types_in_levels) do |project, tree, configure|
      project.add_member(User.current)
      template = %{  {{
        stack-bar-chart
          labels: SELECT DISTINCT 'Planning iteration'
          cumulative: false
          series:
            - label: Series 1
              color: green
              type: bar
              data: SELECT 'Planning iteration', COUNT(*) WHERE Type = 'story'
              combine: overlay-bottom
      }} }

      chart = extract_chart(template)

      assert_equal ['#2 iteration2', '#5 iteration1', '(not set)'].sort, chart.labels_for_plot.sort
    end
  end

  test 'card_relationship_properties_in_stack_bar_chart' do
      with_card_query_project do |project|
        first_card = project.cards.first
        first_card.update_attributes(:cp_related_card => first_card)

        template = %{  {{
          stack-bar-chart
            series:
              - label: 'related card'
                color: Yellow
                data: SELECT 'related card', COUNT(*)
        }} }
        chart = extract_chart(template)
        assert_equal [first_card.number_and_name], chart.labels_for_plot
        assert_equal [1], chart.series_by_label['related card'].values
      end
    end

  test 'data_where_condition_can_use_this_card' do
    with_card_query_project do |project|
      this_card = project.cards.first
      related_card_property_definition = project.find_property_definition('related card')

      [['A', 1], ['B', 1], ['C', 2]].each do |card_name, size|
        card = project.cards.create!(:name => card_name, :cp_size => size, :card_type_name => 'Card')
        related_card_property_definition.update_card(card, this_card)
        card.save!
      end

      template = %{  {{
        stack-bar-chart
          series:
            - label: 'size'
              color: Yellow
              data: SELECT 'size', COUNT(*) WHERE 'related card' = tHiS cArD
      }} }
      chart = extract_chart(template, :content_provider => this_card)
      assert_equal ['1', '2', '(not set)'], chart.labels_for_plot
      assert_equal [2, 1, 0], chart.series_by_label['size'].values
    end
  end

  test 'labels_query_can_have_this_card_syntax' do
    with_card_query_project do |project|
      this_card = project.cards.first
      related_card_property_definition = project.find_property_definition('related card')

      [['A', 1], ['B', 1], ['C', 2]].each do |card_name, size|
        card = project.cards.create!(:name => card_name, :cp_size => size, :card_type_name => 'Card')
        related_card_property_definition.update_card(card, this_card)
        card.save!
      end

      template = %{ {{
        stack-bar-chart
          conditions: Type = 'Card'
          labels: SELECT DISTINCT size WHERE 'related card' = this card ORDER BY size
          cumulative: false
          series:
            - label: Cake
              color: red
              type: line
              data: SELECT size, COUNT(*) WHERE 'related card' = this card
      }} }

      chart = extract_chart(template, :content_provider => this_card)
      assert_equal %w(1 2), chart.labels_for_plot
      assert_equal [2, 1], chart.series_by_label['Cake'].values
    end
  end

  test 'should_support_from_tree' do
    with_three_level_tree_project do |project|
      template = %{ {{
        stack-bar-chart
          series:
            - label       : label
              data        : SELECT 'size', COUNT(*) FROM TREE "three level tree"
      }} }

      chart = extract_chart(template)
      assert_equal [1,3,1], chart.series_by_label['label'].values

      not_in_tree = create_card!(:size => 3, :name => 'card not in tree', :number => 10)
      chart = extract_chart(template)
      assert_equal [1,3,1], chart.series_by_label['label'].values
    end
  end

  test 'should_use_x_label_tree_to_specify_the_labels_and_dont_set_x_label_conditions' do
    with_three_level_tree_project do |project|
      template = %{ {{
        stack-bar-chart
          x-labels-tree: 'three level tree'
          series:
            - label: Series1
              data: SELECT 'Planning iteration', COUNT(*)
      }} }

      create_card!(:name => 'iteration4', :card_type => 'iteration')
      chart = extract_chart(template)

      assert_equal ['release1 > iteration1', 'release1 > iteration2'], chart.labels_for_plot
      assert_equal [2, 0], chart.series_by_label['Series1'].values
    end
  end

  test 'should_use_x_label_tree_to_specify_the_labels_and_do_set_x_label_conditions' do
    with_three_level_tree_project do |project|
      template = %{ {{
        stack-bar-chart
          labels: SELECT DISTINCT 'planning iteration'
          x-labels-tree: 'three level tree'
          series:
            - label: Series1
              data: SELECT 'Planning iteration', COUNT(*)
      }} }

      create_card!(:name => 'iteration4', :card_type => 'iteration')
      chart = extract_chart(template)

      assert_equal ['release1 > iteration1'], chart.labels_for_plot
      assert_equal [2], chart.series_by_label['Series1'].values
    end
  end

  test 'should_show_error_message_when_tree_is_not_exist_in_the_x_labels_tree' do
      with_three_level_tree_project do |project|
        template = %{ {{
          stack-bar-chart
            labels: SELECT DISTINCT 'planning iteration'
            x-labels-tree: 'doesnt exist'
            series:
              - label: Series1
                data: SELECT 'Planning iteration', COUNT(*)
        }} }

      assert_raise_message(Macro::ProcessingError, /doesnt exist/) do
        extract_chart template
      end
    end
  end

  test 'should_use_x_label_tree_to_specify_to_overcome_cross_project_card_number_mismatch_problem' do

    # first project: iteration1 = [added to scope => iteration1, estimate => 1, number != second_project.iteration1.number]
    login_as_admin
    first_project = with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      estimate = setup_numeric_property_definition('estimate', [1,2,5])
      scope = setup_card_relationship_property_definition('Add to scope')
      iteration = project.card_types.find_by_name('iteration')
      iteration.add_property_definition estimate
      iteration.add_property_definition scope

      iteration1 = project.cards.find_by_name('iteration1')
      iteration1.update_properties('estimate' => 1, 'add to scope' => iteration1.id)
      iteration1.save!
    end

    # second project: iteration1 = [added to scope => iteration1, estimate => 1, number != first_project.iteration1.number]
    second_project = with_new_project do |project|
      login_as_admin
      init_planning_tree_types
      create_three_level_tree
      estimate = setup_numeric_property_definition('estimate', [1,2,5])
      scope = setup_card_relationship_property_definition('Add to scope')
      iteration = project.card_types.find_by_name('iteration')
      iteration.add_property_definition estimate
      iteration.add_property_definition scope

      iteration1 = project.cards.find_by_name('iteration1')
      max_number = project.cards.maximum('number')
      iteration1.update_attribute(:number, max_number + 1)
      iteration1.update_properties('estimate' => 1, 'add to scope' => iteration1.id)
      iteration1.save!

      template = %{ {{
        stack-bar-chart
          labels: SELECT DISTINCT 'planning iteration'
          x-labels-tree: 'three_level_tree'
          series:
            - label: Series1
              project: #{project.identifier}
              data: SELECT 'Add to scope', SUM(estimate)
            - label: Series2
              project: #{first_project.identifier}
              data: SELECT 'Add to scope', SUM(estimate)
      }} }

      chart = extract_chart(template)

      assert_equal 1, chart.series_by_label['Series1'].values[0]
      assert_equal 1, chart.series_by_label['Series2'].values[0]
    end

  end

  test 'can_use_plvs_in_chart' do
    @project.update_attributes(:date_format => Date::LONG_MONTH_DAY_YEAR)
    create_plv!(@project, :name => 'my_labels_start', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => 'Nov 30 2006')
    create_plv!(@project, :name => 'my_labels_end',   :data_type => ProjectVariable::DATE_DATA_TYPE, :value => 'Nov 30 2007')
    template = %{ {{
      stack-bar-chart
        conditions: 'Release' = '1' AND date_created IS NOT NULL
        cumulative: true
        label-start: (my_labels_start)
        label-end: (my_labels_end)
        series:
        - label: Scope
          color: gray
          type: area
          data: SELECT date_created, SUM(Size)
    }} }
    chart = extract_chart(template)

    assert template_can_be_cached?(template, @project)
    assert_equal ['Jan 01 2007', 'Jan 02 2007', 'Jan 03 2007', 'Jan 04 2007', 'Jan 05 2007', 'Jan 06 2007'], chart.labels_for_plot
    assert_equal [6, 15, 18, 18, 18, 18], chart.series_by_label['Scope'].values
  end

  test 'multiple_labels_with_the_same_name_have_number_appended' do
    chart = extract_chart(%{ {{
      stack-bar-chart
        conditions  : old_type = Story AND Release = 1
        cumulative  : true
        series:
          - label       : LabelOne
            color       : Yellow
            combine     : total
            data        : >
              SELECT 'Came Into Scope on Iteration', SUM(Size)
          - label       : LabelTwo
            color       : Green
            combine     : overlay-bottom
            data        : >
              SELECT Iteration, SUM(Size)
              WHERE Status = 'Closed'
          - label       : LabelOne
            color       : LightBlue
            combine     : overlay-bottom
            data        : >
              SELECT Iteration, SUM(Size)
              WHERE Status = 'In Progress'
          - label       : LabelTwo
            color       : Red
            combine     : overlay-top
            data        : >
              SELECT 'Came Into Scope on Iteration', SUM(Size)
              WHERE NOT 'Came Into Scope on Iteration' = 1
    }} })

    assert_equal [11, 7, 2], chart.series_by_label['LabelOne (1)'].values
    assert_equal [5, 9, 12], chart.series_by_label['LabelTwo (1)'].values
    assert_equal [0, 0, 2], chart.series_by_label['LabelOne (2)'].values
    assert_equal [0, 2, 2], chart.series_by_label['LabelTwo (2)'].values
  end

  # TODO : need to uncomment once the story-1733] is played.
  # bug 7715
  # test 'should_be_able_to_use_project_in_data_mql' do
  #   template = ' {{
  #     stack-bar-chart
  #       series:
  #       - data: SELECT project, count(*)
  #         label: Projects
  #         color: #FF0000
  #         combine: overlay-bottom
  #   }} '
  #
  #   chart = extract_chart(template)
  #
  #   assert template_can_be_cached?(template, @project)
  #   assert_equal ['stack_bar_chart_project'], chart.labels_for_plot
  #   assert_equal [@project.cards.count], chart.series_by_label['Projects'].values
  # end
  test 'should_generate_region_data_and_mql_json_when_interaction_is_enabled_for_stack_bar_chart' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'done']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : LabelOne
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
            - label       : LabelTwo
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
                WHERE estimate = '4'
      }} })
        chart.extract_region_data
        chart.extract_region_mql

        chart_json = JSON.parse(chart.generate)

        assert_equal({'data' =>
                        {'columns' => [['LabelTwo', 1, 2], ['LabelOne', 1, 0]],
                         'type' => 'bar',
                         'order' => nil,
                         'types' => {},
                         'trends' => [],
                         'colors' => {'LabelTwo' => 'green', 'LabelOne' => 'yellow'},
                         'groups' => [%w(LabelTwo LabelOne)],
                         'regions' => {}},
                      'legend' => {'position' => 'top-right'},
                      'size' => {'width' => 600, 'height' => 450},
                      'axis' =>
                        {'x' =>
                           {'type' => 'category',
                            'label' => {'text' => 'status', 'position' => 'outer-center'},
                            'categories' => ['new', 'done'],
                            'tick' => {'rotate' => 45, 'multiline' => false, 'centered' => true}},
                         'y' => {'label' => {'text' => 'Number of cards', 'position' => 'outer-middle'}, 'padding' => {'top' => 25}}},
                      'bar' => {'width' => {'ratio' => 0.85}},
                      'tooltip' => {'grouped' => false},
                      'region_data' =>
                        {'done' => {
                            'LabelOne' => {'cards' => [], 'count' => 0},
                            'LabelTwo' => {'cards' => [{'name' => 'fourth', 'number' => '4'}, {'name' => 'third', 'number' => '3'}], 'count' => 2}},
                         'new' =>
                           {'LabelTwo' => {'cards' => [{'name' => 'second', 'number' => '2'}], 'count' => 1},
                            'LabelOne' => {'cards' => [{'name' => 'first', 'number' => '1'}], 'count' => 1}}},
                      'region_mql' =>
                        {'conditions' =>
                           {'done' =>
                              {'LabelTwo' => 'estimate = 4 AND Type = Story AND status = done',
                               'LabelOne' => 'estimate = 2 AND Type = Story AND status = done'},
                            'new' =>
                              {'LabelTwo' => 'estimate = 4 AND Type = Story AND status = new',
                               'LabelOne' => 'estimate = 2 AND Type = Story AND status = new'}},
                         'project_identifier' => {'LabelOne' => project.name, 'LabelTwo' => project.name}},
                      'title' => {'text' => ''},
                      'grid' =>{'y' =>{'show' =>true}, 'x' =>{'show' =>false}}}, chart_json)
      end
  end


  test 'should_generate_json_response_with_negative_x_axis_values' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'done']
        setup_numeric_property_definition 'estimate', [-2, -4.20, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => -2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => -4.20)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => -4.20)

        chart = extract_chart(' {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : Series
              color       : Yellow
              combine     : overlay-top
              data        : SELECT estimate, count(*)
      }} ')
        chart.extract_region_data
        chart.extract_region_mql

        chart_json = JSON.parse(chart.generate)

        assert_equal({'data' =>
                          {'columns' =>[['Series', 2, 1, 0]],
                           'type' => 'bar',
                           'order' => nil,
                           'types' =>{},
                           'trends' => [],
                           'colors' =>{'Series' => 'yellow'},
                           'groups' =>[['Series']],
                           'regions' => {}},
                      'legend' =>{'position' => 'top-right'},
                      'size' =>{'width' =>600, 'height' =>450},
                      'axis' =>
                          {'x' =>
                               {'type' => 'category',
                                'label' =>{'text' => 'estimate', 'position' => 'outer-center'},
                                'categories' =>['-4.2', '-2', '(not set)'],
                                'tick' =>{'rotate' =>45, 'multiline' =>false, 'centered' =>true}},
                           'y' =>{'label' =>{'text' => 'Number of cards', 'position' => 'outer-middle'}, 'padding' => {'top' => 25}}},
                      'bar' =>{'width' =>{'ratio' =>0.85}},
                      'tooltip' =>{'grouped' =>false},
                      'region_data' =>
                          {'-4.2' => {'Series' => {'cards' => [{'name' => 'third', 'number' => '3'}, {'name' => 'second', 'number' => '2'}], 'count' =>2}},
                           '-2' => {'Series' =>{'cards' =>[{'name' => 'first', 'number' => '1'}], 'count' =>1}},
                          '(not set)' => {'Series' => {'cards' => [], 'count' => 0}}},
                      'region_mql' =>
                          {'conditions' =>
                               {'-4.2' =>{'Series' =>"Type = Story AND estimate = '-4.2'"},
                                '-2' =>{'Series' =>"Type = Story AND estimate = '-2'"},
                                '(not set)' =>{'Series' => 'Type = Story AND estimate IS NULL'}},
                           'project_identifier' => {'Series' => project.name}},
                      'title' => {'text' => ''},
                      'grid' =>{'y' =>{'show' =>true}, 'x' =>{'show' =>false}}}, chart_json)
      end
  end

  test 'can_generate_region_mql_for_stack_bar_based_on_query_for_cumulated_data' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'done']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : true
          series:
            - label       : Estimate2
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
            - label       : Estimate4
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
                WHERE estimate = '4'
      }} })

        expected = {'conditions' =>
                        {
                            'new' =>
                                {'Estimate4' => 'estimate = 4 AND Type = Story AND status = new',
                                 'Estimate2' => 'estimate = 2 AND Type = Story AND status = new'},
                            'done' =>
                                {'Estimate4' => 'estimate = 4 AND Type = Story AND status >= new AND status <= done',
                                 'Estimate2' => 'estimate = 2 AND Type = Story AND status >= new AND status <= done'}
                        },
                    'project_identifier' => {'Estimate2' => project.identifier, 'Estimate4' => project.identifier}}
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal expected, chart.region_mql
      end
  end

  test 'region_mql_for_stack_bar_based_on_query_for_cumulated_data_should_have_comparison_query_with_or_condition_for_null_values' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'in-progress', 'done']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'in-progress', :estimate => 2)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :estimate => 4)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : true
          labels : Select DISTINCT status
          series:
            - label       : Estimate2
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
            - label       : Estimate4
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
                WHERE estimate = '4'
      }} })

        expected = {'conditions' =>
                        {
                            'new' =>
                                {'Estimate4' => 'estimate = 4 AND Type = Story AND status = new',
                                 'Estimate2' => 'estimate = 2 AND Type = Story AND status = new'},
                            'in-progress' =>
                                {'Estimate4' => "estimate = 4 AND Type = Story AND status >= new AND status <= 'in-progress'",
                                 'Estimate2' => "estimate = 2 AND Type = Story AND status >= new AND status <= 'in-progress'"},
                            'done' =>
                                {'Estimate4' => 'estimate = 4 AND Type = Story AND status >= new AND status <= done',
                                 'Estimate2' => 'estimate = 2 AND Type = Story AND status >= new AND status <= done'},
                            '(not set)' =>
                                {'Estimate4' => 'estimate = 4 AND Type = Story AND ((status >= new) OR (status IS NULL))',
                                 'Estimate2' => 'estimate = 2 AND Type = Story AND ((status >= new) OR (status IS NULL))'}
                        },
                    'project_identifier' => {'Estimate2' => project.identifier, 'Estimate4' => project.identifier}}
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal expected, chart.region_mql
      end
  end

  test 'can_generate_region_mql_for_stack_bar_based_on_query_for_cumulated_data_for_card_properties_has_card_numbers' do
      with_new_project do |project|
        project.add_member(User.current)
        feature_type = setup_card_type(project, 'feature')
        setup_card_relationship_property_definition('feature_card')
        setup_card_type(project, 'story', properties: ['feature_card'])
        feature1 = create_card_in_future(2.seconds, name: 'feature1', card_type: 'feature')
        feature2 = create_card_in_future(3.seconds, name: 'feature2', card_type: 'feature')
        card1 = create_card_in_future(4.seconds, name: 'first_story', card_type: 'story', feature_card: feature1.id)
        card2 = create_card_in_future(5.seconds, name: 'second_story', card_type: 'story', feature_card: feature2.id)
        card3 = create_card_in_future(6.seconds, name: 'third_story', card_type: 'story')

        chart = extract_chart(' {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : true
          labels: Select distinct feature_card
          series:
            - label       : Features
              color       : Yellow
              combine     : overlay-top
              data        : SELECT feature_card, count(*)

      }} ')
        chart.extract_region_data
        chart.extract_region_mql

        expected = {'conditions' =>
                        {'(not set)' =>{'Features' => 'Type = Story AND feature_card IS NULL'},
                         '#1 feature1' =>
                             {'Features' =>
                                  'Type = Story AND ((feature_card NUMBER IN (1)) OR (feature_card IS NULL))'},
                         '#2 feature2' =>
                             {'Features' =>
                                  'Type = Story AND ((feature_card NUMBER IN (1, 2)) OR (feature_card IS NULL))'}},
                    'project_identifier' => {'Features' => project.name}}

        assert_equal expected, chart.region_mql
      end
  end

  test 'can_generate_region_mql_and_region_data_for_stack_bar_based_on_query_for_cumulated_data_with_x_label_start_end_set_and_x_label_step' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new 1', 'qa', 'done', 'in prod', 'post deploy', 'archived']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new 1', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'qa', :estimate => 2)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 2)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'in prod', :estimate => 2)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : true
          x-label-start   : qa
          x-label-end     : in prod
          x-label-step    : 2
          series:
            - label       : Estimate2
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
      }} })

        expected_region_mql = {'conditions' =>
                                   {
                                       'qa' =>
                                           {'Estimate2' => "estimate = 2 AND Type = Story AND status >= 'new 1' AND status <= qa"},
                                       'done' =>
                                           {'Estimate2' => "estimate = 2 AND Type = Story AND status >= 'new 1' AND status <= done"},
                                       'in prod' =>
                                           {'Estimate2' => "estimate = 2 AND Type = Story AND status >= 'new 1' AND status <= 'in prod'"}
                                   },
                               'project_identifier' =>{'Estimate2' => project.identifier}}
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal expected_region_mql, chart.region_mql

        region_data = chart.region_data
        assert_equal(3, region_data.keys.size)
        assert_equal(2, region_data['qa']['Estimate2'][:count])
        assert_equal(3, region_data['done']['Estimate2'][:count])
        assert_equal(4, region_data['in prod']['Estimate2'][:count])
      end
  end

  test 'can_generate_region_mql_and_region_data_for_stack_bar_based_when_formula_numeric_property_present' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_formula_property_definition('estimateplus2', 'estimate + 2')
        setup_card_type(project, 'story', :properties => ['estimate', 'estimateplus2'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :estimate => 3)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story')
        chart = extract_chart(' {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : true
          labels: Select distinct estimateplus2
          series:
            - label       : Estimate2
              color       : Yellow
              combine     : overlay-top
              data        : SELECT estimateplus2, count(*)

      }} ')

        chart.extract_region_data
        chart.extract_region_mql

        expected_region_mql = {'conditions' =>
                                   {'4' => {'Estimate2' => 'Type = Story AND estimateplus2 = 4'},
                                    '5' =>
                                        {'Estimate2' =>
                                             'Type = Story AND estimateplus2 >= 4 AND estimateplus2 <= 5'},
                                    '6' =>
                                        {'Estimate2' =>
                                             'Type = Story AND estimateplus2 >= 4 AND estimateplus2 <= 6'},
                                    '(not set)' =>
                                        {'Estimate2' =>
                                             'Type = Story AND ((estimateplus2 >= 4) OR (estimateplus2 IS NULL))'}},
                               'project_identifier' => {'Estimate2' => project.name}}

        assert_equal expected_region_mql, chart.region_mql

        region_data = chart.region_data
        assert_equal(4, region_data.keys.size)
        assert_equal(4, region_data['(not set)']['Estimate2'][:count])
        assert_equal(3, region_data['6']['Estimate2'][:count])
        assert_equal(2, region_data['5']['Estimate2'][:count])
        assert_equal(1, region_data['4']['Estimate2'][:count])
      end
  end

  test 'chart_callback_should_return_div_with_chart_renderer' do
    template = ' {{
    stack-bar-chart
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom
  }} '

    card = @project.cards.first
    chart = StackBarChart.new({content_provider: card, view_helper: view_helper}, 'stack-bar-chart', {'series' => [{'data' => 'select status, count(*)',
                                                                                                                    'label' => 'Projects',
                                                                                                                    'color' => '#FF0000',
                                                                                                                    'combine' => 'overlay-bottom'}]} , template)
    expected_chart_container_and_script = %Q{<div id='stacked-bar-chart-Card-#{card.id}-1' class='stacked-bar-chart medium' style='margin: 0 auto; width: #{chart.chart_width}px; height: #{chart.chart_height}px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#stacked-bar-chart-Card-#{card.id}-1'
      ChartRenderer.renderChart('stackedBarChart', dataUrl, bindTo);
    </script>}

    assert_equal(expected_chart_container_and_script, chart.chart_callback({position: 1, controller: :cards}))
  end

  test 'chart_callback_should_should_use_stacked_instead_of_stack_and_add_preview_to_container_id_when_preview_param_is_true' do
      template = ' {{
    stack-bar-chart
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

      card = @project.cards.first
      chart = StackBarChart.new({content_provider: card, view_helper: view_helper}, 'stack-bar-chart', {'series' => [{'data' => 'select status, count(*)',
                                                                                                                      'label' => 'Projects',
                                                                                                                      'color' => '#FF0000',
                                                                                                                      'combine' => 'overlay-bottom'}]}, template)
      expected_chart_container_and_script = %Q{<div id='stacked-bar-chart-Card-#{card.id}-1-preview' class='stacked-bar-chart medium' style='margin: 0 auto; width: #{chart.chart_width}px; height: #{chart.chart_height}px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1&preview=true'
      var bindTo = '#stacked-bar-chart-Card-#{card.id}-1-preview'
      ChartRenderer.renderChart('stackedBarChart', dataUrl, bindTo);
    </script>}

      assert_equal(expected_chart_container_and_script, chart.chart_callback({position: 1, preview: true, controller: :cards}))
  end

  test 'default_chart_width_should_be_600_by_450' do
    template = '{{
    stack-bar-chart
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

    chart = extract_chart(template)
    chart.extract_region_data
    chart.extract_region_mql

    assert_equal(450, chart.chart_height)
    assert_equal(600, chart.chart_width)
  end

  test 'can_specify_chart_width_in_pixels' do
    template = '{{
      stack-bar-chart
        chart-width: 525 px
        series:
        - data: select status, count(*)
          label: Projects }}'

    chart = extract_chart(template)
    assert_equal(525, chart.chart_width)
  end

  test 'can_specify_chart_height_in_pixels' do
    template = '{{
      stack-bar-chart
        chart-height: 444px
        series:
        - data: select status, count(*)
          label: Projects }}'

    chart = extract_chart(template)
    assert_equal(444, chart.chart_height)
  end

  test 'can_specify_x_label_step_in_pixels' do
      template = '{{
        stack-bar-chart
          x-label-step: 10 px
          series:
          - data: select status, count(*)
            label: Projects }}'

      chart = extract_chart(template)
      assert_equal(10, chart.x_label_step)
  end

  test 'can_generate_region_data_for_stack_bar_based_on_query' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'in-progress', 'done', 'in-prod']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story', :status => 'in-progress', :estimate => 2)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : LabelOne
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
            - label       : LabelTwo
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
                WHERE estimate = '4'
      }} })

        new = {'LabelTwo' => {:cards => [{'name' => 'second', 'number' => '2'}], :count => 1}, 'LabelOne' => {:cards => [{'name' => 'first', 'number' => '1'}], :count => 1}}
        in_progress = {'LabelOne' => {:cards => [{'name' => 'fifth', 'number' => '5'}], :count => 1} , 'LabelTwo' => {:cards => [], :count => 0}}
        done = {'LabelOne' => {:cards => [], :count => 0}, 'LabelTwo' => {:cards => [{'name' => 'fourth', 'number' => '4'}, {'name' => 'third', 'number' => '3'}], :count => 2}}

        chart.extract_region_data
        actual_extracted_data = chart.region_data

        assert_equal(new, actual_extracted_data['new'])
        assert_equal(in_progress, actual_extracted_data['in-progress'])
        assert_equal(done, actual_extracted_data['done'])
      end
  end

  test 'can_generate_region_data_for_cross_project_stacked_bar_charts' do
      second_project = with_new_project(prefix: 'Project B') do |other_project|
        other_project.add_member(User.current)
        setup_property_definitions 'status' => %w(new in-progress done in-prod)
        setup_card_type(other_project, 'story', :properties => %w(status))
        create_card_in_future(2.seconds, :name => 'B1', :card_type => 'story', :status => 'new')
        create_card_in_future(6.seconds, :name => 'B2', :card_type => 'story', :status => 'in-progress')
      end

      with_new_project(prefix: 'Project A') do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new in-progress done in-prod)
        setup_card_type(project, 'story', :properties => %w(status))
        create_card_in_future(2.seconds, :name => 'A1', :card_type => 'story', :status => 'new')
        create_card_in_future(3.seconds, :name => 'A2', :card_type => 'story', :status => 'done')
        create_card_in_future(4.seconds, :name => 'A3', :card_type => 'story', :status => 'in-progress')
        create_card_in_future(5.seconds, :name => 'A4', :card_type => 'story', :status => 'done')

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : Project B
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
              project     : #{second_project.identifier}
            - label       : Project A
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
      }} })
        chart.extract_region_data
        chart.extract_region_mql

        new = {'Project A' => {:cards => [{'name' => 'A1', 'number' => '1'}], :count => 1},
               'Project B' => {:cards => [{'name' => 'B1', 'number' => '1'}], :count => 1}}
        in_progress = {'Project A' => {:cards => [{'name' => 'A3', 'number' => '3'}], :count => 1},
                       'Project B' => {:cards => [{'name' => 'B2', 'number' => '2'}], :count => 1}}
        done = {'Project A' => {:cards => [{'name' => 'A4', 'number' => '4'}, {'name' => 'A2', 'number' => '2'}], :count => 2},
                'Project B' => {cards: [], count: 0}}

        actual_extracted_data = chart.region_data

        assert_equal(new, actual_extracted_data['new'])
        assert_equal(in_progress, actual_extracted_data['in-progress'])
        assert_equal(done, actual_extracted_data['done'])
      end
  end

  test 'can_generate_region_data_correctly_when_x_label_property_is_a_date_property' do
      with_new_project(prefix: 'Project A') do |project|
        project.add_member(User.current)
        date_format = '%Y-%m-%d'
        project.date_format = date_format
        project.save!
        setup_date_property_definition 'Started On'
        setup_card_type(project, 'story', :properties => ['Started On'])
        two_days_from_now = 2.days.from_now
        three_days_from_now = 3.days.from_now
        four_days_from_now = 4.days.from_now
        create_card_in_future(2.days, :name => 'A1', :card_type => 'story', 'Started On' => two_days_from_now)
        create_card_in_future(3.days, :name => 'A2', :card_type => 'story', 'Started On' => three_days_from_now)
        create_card_in_future(4.days, :name => 'A3', :card_type => 'story', 'Started On' => four_days_from_now)
        create_card_in_future(5.days, :name => 'A4', :card_type => 'story', 'Started On' => three_days_from_now)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : Started
              color       : Yellow
              combine     : overlay-top
              data        : SELECT 'Started On', count(*)
      }} })
        chart.extract_region_data
        chart.extract_region_mql
        assert_equal({three_days_from_now.strftime(date_format) =>
                          {'Started' =>
                               {cards: [{'name' => 'A4', 'number' => '4'}, {'name' => 'A2', 'number' => '2'}], count: 2}},
                      four_days_from_now.strftime(date_format) =>
                          {'Started' => {cards: [{'name' => 'A3', 'number' => '3'}], count: 1}},
                      two_days_from_now.strftime(date_format) =>
                          {'Started' => {cards: [{'name' => 'A1', 'number' => '1'}], count: 1}}}, chart.region_data)
      end
  end

  test 'can_generate_region_mql_for_cross_project_stacked_bar_charts' do
      second_project = with_new_project(prefix: 'Project B') do |other_project|
        other_project.add_member(User.current)
        setup_property_definitions 'CurrentStatus' => %w(new in-progress done in-prod)
        setup_card_type(other_project, 'story', :properties => %w(CurrentStatus))
        create_card_in_future(2.seconds, :name => 'B1', :card_type => 'story', :CurrentStatus => 'new')
        create_card_in_future(6.seconds, :name => 'B2', :card_type => 'story', :CurrentStatus => 'in-progress')
      end

      with_new_project(prefix: 'Project A') do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new in-progress done in-prod)
        setup_card_type(project, 'story', :properties => %w(status))
        create_card_in_future(2.seconds, :name => 'A1', :card_type => 'story', :status => 'new')
        create_card_in_future(3.seconds, :name => 'A2', :card_type => 'story', :status => 'done')
        create_card_in_future(4.seconds, :name => 'A3', :card_type => 'story', :status => 'in-progress')
        create_card_in_future(5.seconds, :name => 'A4', :card_type => 'story', :status => 'done')

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : Project B
              color       : Yellow
              combine     : overlay-top
              data        : SELECT CurrentStatus, count(*)
              project     : #{second_project.identifier}
            - label       : Project A
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*)
        }} })
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal({'conditions' =>
                          {'new' =>
                               {'Project A' => 'Type = Story AND status = new',
                                'Project B' => 'Type = Story AND CurrentStatus = new'},
                           'in-progress' =>
                               {'Project A' =>"Type = Story AND status = 'in-progress'",
                                'Project B' =>"Type = Story AND CurrentStatus = 'in-progress'"},
                           'done' =>
                               {'Project A' => 'Type = Story AND status = done',
                                'Project B' => 'Type = Story AND CurrentStatus = done'},
                           'in-prod' =>
                               {'Project A' =>"Type = Story AND status = 'in-prod'",
                                'Project B' =>"Type = Story AND CurrentStatus = 'in-prod'"}},
                      'project_identifier' =>
                          {'Project A' => project.identifier, 'Project B' => second_project.identifier}}, chart.region_mql)
      end
  end

  test 'can_generate_region_data_for_stack_bar_based_on_query_when_cumulative_is_true' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'in-progress', 'done', 'in-prod']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        first_new_card_with_estimate_2 = create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        second_card = create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story', :status => 'done', :estimate => 2)

        in_progress_cards_with_estimate_2 = create_cards_in_future(10, 7.seconds, :card_type => 'story', :status => 'in-progress', :estimate => 2)
        latest_card_with_estimate_2 = create_card_in_future(3.minutes, :name => 'last', :card_type => 'story', :status => 'new', :estimate => 2)


        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : true
          series:
            - label       : Estimate2
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
            - label       : Estimate4
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
                WHERE estimate = '4'
      }} })

        new = {'Estimate4' => {:cards => [{'name' => 'second', 'number' => '2'}], :count => 1},
               'Estimate2' => {:cards => [{'name' => 'last', 'number' => '16'},
                                          {'name' => 'first', 'number' => '1'}], :count => 2}}

        chart.extract_region_data
        actual_extracted_data = chart.region_data
        assert_equal(12, actual_extracted_data['in-progress']['Estimate2'][:count])
        assert_equal(10, actual_extracted_data['in-progress']['Estimate2'][:cards].count)
        assert_equal(new['Estimate4'][:cards], actual_extracted_data['new']['Estimate4'][:cards].map {|card| card.except('updated_at')})
        assert_equal(new['Estimate4'][:count], actual_extracted_data['new']['Estimate4'][:count])
        assert_equal(new['Estimate2'][:cards], actual_extracted_data['new']['Estimate2'][:cards].map {|card| card.except('updated_at')})
        assert_equal(new['Estimate2'][:count], actual_extracted_data['new']['Estimate2'][:count])

        actual_estimate_2_in_progress_card_numbers = actual_extracted_data['in-progress']['Estimate2'][:cards].map {|x| x['number'].to_i}
        expected_estimate_2_card_numbers = [latest_card_with_estimate_2.number] + in_progress_cards_with_estimate_2.map(&:number).drop(1).reverse
        assert_equal(expected_estimate_2_card_numbers, actual_estimate_2_in_progress_card_numbers)

        assert_equal(13, actual_extracted_data['done']['Estimate2'][:count])
        assert_equal(10, actual_extracted_data['done']['Estimate2'][:cards].count)
        assert_equal(expected_estimate_2_card_numbers, actual_extracted_data['done']['Estimate2'][:cards].map {|x| x['number'].to_i})
      end
  end

  test 'can_generate_region_mql_for_stack_bar_based_on_query' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => ['new', 'done']
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => ['status', 'estimate'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        stack-bar-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : LabelOne
              color       : Yellow
              combine     : overlay-top
              data        : >
                SELECT status, count(*)
                WHERE estimate = '2'
            - label       : LabelTwo
              color       : Green
              combine     : overlay-bottom
              data        : >
                SELECT status, count(*)
                WHERE estimate = '4'
      }} })

        expected = {'conditions' =>
                        {'done' =>
                             {'LabelTwo' => 'estimate = 4 AND Type = Story AND status = done',
                              'LabelOne' => 'estimate = 2 AND Type = Story AND status = done'},
                         'new' =>
                             {'LabelTwo' => 'estimate = 4 AND Type = Story AND status = new',
                              'LabelOne' => 'estimate = 2 AND Type = Story AND status = new'},
                        },
                    'project_identifier' =>{'LabelOne' => project.identifier, 'LabelTwo' => project.identifier}}
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal expected, chart.region_mql
      end
  end

  test 'should_generate_region_mql_with_in_condition_for_stack_bar_based_on_query_when_user_property_on_x_axis' do
      with_new_project do |project|
        project.add_member(User.current)

        setup_property_definitions 'status' => ['new', 'done']
        setup_user_definition('owner')

        user1 = create_user!(login: 'stack-bar-test@charts.com')
        project.add_member(user1)

        setup_card_type(project, 'story', :properties => ['status', 'owner'])
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :owner => User.current.id)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :owner => user1.id)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done')


        chart = extract_chart(' {{
          stack-bar-chart
            conditions  : type = Story
            cumulative  : true
            labels  : SELECT distinct owner
            series:
              - label       : Series
                color       : Yellow
                combine     : overlay-top
                data        : SELECT owner, count(*)
        }} ')
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal 2, chart.region_mql.keys.size
        assert_equal project.name, chart.region_mql['project_identifier']['Series']

        assert_equal 3, chart.region_mql['conditions'].keys.size

        current_user_conditions = {'Series' => "Type = Story AND owner = #{User.current.login}"}
        assert_equal current_user_conditions, chart.region_mql['conditions'][User.current.name_and_login]

        user_1_conditions = {'Series' => "Type = Story AND owner IN (#{User.current.login}, '#{user1.login}')"}
        assert_equal user_1_conditions, chart.region_mql['conditions'][user1.name_and_login]

        user_nil_conditions = {'Series' => "Type = Story AND ((owner IN (#{User.current.login}, '#{user1.login}')) OR (owner IS NULL))"}
        assert_equal user_nil_conditions, chart.region_mql['conditions']['(not set)']
      end
  end

  def test_chart_dimensions_should_be_300_by_225_when_chart_size_chosen_is_small_and_new_workflow_is_enabled
      template = '{{
    stack-bar-chart
      chart-size : small
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

      chart = extract_chart(template)

      assert_equal(225, chart.chart_height)
      assert_equal(300, chart.chart_width)
  end

  def test_chart_dimensions_should_be_1200_by_900_when_new_workflow_is_enabled_for_stacked_bar_chart_and_chart_size_chosen_is_large
      template = '{{
    stack-bar-chart
      chart-size : large
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

      chart = extract_chart(template)

      assert_equal(900, chart.chart_height)
      assert_equal(1200, chart.chart_width)
  end

  def test_do_generate_should_set_show_guide_lines_as_true_when_stated
    template = ' {{
    stack-bar-chart
      cumulative  : true
      show-guide-lines: true
      series:
        - label       : Original
          color       : yellow
          combine     : total
          data        : SELECT date_created, SUM(Size) ORDER BY date_created
  }} '

    chart = extract_chart(template)
    chart_json = JSON.parse(chart.generate)
    grid = {'y' => {'show' => true}, 'x' => {'show' => false}}

    assert_equal grid, chart_json['grid']
  end

  test 'should_generate_region_mql_and_data_when_x_lable_is_card_property' do
      with_three_level_tree_project do |project|
      template = %{ {{
        stack-bar-chart
          labels: SELECT DISTINCT 'planning iteration'
          series:
            - label: Series1
              data: SELECT 'Planning iteration', COUNT(*)
      }} }

      expected_region_mql_conditions = {'(not set)' => {'Series1' => "'Planning iteration' IS NULL"},
      '#2 iteration1' => {'Series1' => "'Planning iteration' = NUMBER 2"}}

      create_card!(:name => 'iteration4', :card_type => 'iteration')
      chart = extract_chart(template)
      chart.extract_region_data
      chart.extract_region_mql

      assert_equal(expected_region_mql_conditions, chart.region_mql['conditions'])
      end
  end

  test 'should_generate_region_mql_and_region_data_when_name_is_selected_in_data_query' do
    with_three_level_tree_project do |project|
      template = %{ {{
      stack-bar-chart
        conditions: type = Story
        series:
          - label: Series1
            data: SELECT 'name', COUNT(*)
    }} }
      expected_region_mql_conditions = {'iteration1'=>{'Series1'=>'Type = Story AND Name = iteration1'},
                                        'iteration2'=>{'Series1'=>'Type = Story AND Name = iteration2'},
                                        'iteration4'=>{'Series1'=>'Type = Story AND Name = iteration4'},
                                        'release1'=>{'Series1'=>'Type = Story AND Name = release1'},
                                        'story1'=>{'Series1'=>'Type = Story AND Name = story1'},
                                        'story2'=>{'Series1'=>'Type = Story AND Name = story2'}}
      expected_region_data = {'iteration1'=>{'Series1'=>{:cards=>[], :count=>0}},
                              'iteration2'=>{'Series1'=>{:cards=>[], :count=>0}},
                              'iteration4'=>{'Series1'=>{:cards=>[], :count=>0}},
                              'release1'=>{'Series1'=>{:cards=>[], :count=>0}},
                              'story1'=> {'Series1'=>{:cards=>[{'name'=>'story1', 'number'=>'4'}], :count=>1}},
                              'story2'=> {'Series1'=>{:cards=>[{'name'=>'story2', 'number'=>'5'}], :count=>1}}}

      create_card!(:name => 'iteration4', :card_type => 'iteration')

      chart = extract_chart(template)
      chart.extract_region_data
      chart.extract_region_mql

      assert_equal(expected_region_data, chart.region_data)
      assert_equal(expected_region_mql_conditions, chart.region_mql['conditions'])
    end
  end

  test 'should_generate_region_mql_and_region_data_for_x_label_tree' do
    ##################################################################################
    #                                     Planning tree
    #                             -------------|---------
    #                            |                      |
    #                    ----- release1----           release2
    #                   |                 |
    #            ---iteration1----    iteration2
    #           |                |
    #       story1            story2
    #
    ##################################################################################
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      type_release = project.card_types.find_by_name('release')
      iteration_1 = project.cards.find_by_name('iteration1')
      tree_configuration.add_child(create_card!(:name => 'release2', :card_type => type_release), :to => :root)
      type_story = project.find_card_type('Story')
      type_story.card_defaults.update_properties('Planning iteration' => iteration_1.id)

      chart = extract_chart(%{ {{
      stack-bar-chart
        conditions  : type = story
        cumulative  : false
        x-labels-tree: "three level tree"
        show-guide-lines : true
        series:
          - label       : 'series1'
            color       : Yellow
            combine     : overlay-top
            data        : SELECT "Planning iteration", count(*)
          - label       : 'series2'
            color       : Yellow
            combine     : overlay-top
            data        : SELECT "Planning iteration", count(*)
      }}})
      chart.extract_region_data
      chart.extract_region_mql

      assert_equal({'release1 > iteration1' =>
                        {'series1' => {:cards => [{'name' => 'story2', 'number' => '5'}, {'name' => 'story1', 'number' => '4'}], :count => 2},
                         'series2' => {:cards => [{'name' => 'story2', 'number' => '5'}, {'name' => 'story1', 'number' => '4'}], :count => 2}},
                    'release1 > iteration2' =>
                        {'series1' => {:cards => [], :count => 0},
                         'series2' => {:cards => [], :count => 0}}}, chart.region_data)
      assert_equal ({'conditions' =>
                          {'release1 > iteration1' =>
                               {'series1' =>"Type = story AND 'Planning iteration' = NUMBER 2",
                                'series2' =>"Type = story AND 'Planning iteration' = NUMBER 2"},
                           'release1 > iteration2' =>
                               {'series1' =>"Type = story AND 'Planning iteration' = NUMBER 3",
                                'series2' =>"Type = story AND 'Planning iteration' = NUMBER 3"}},
                      'project_identifier' =>
                          {'series1' => 'three_level_tree_project',
                           'series2' => 'three_level_tree_project'}}), chart.region_mql

    end
  end

  def test_should_add_region_data_and_region_mql_to_generated_chart_when_interaction_is_enabled_and_x_label_start_end_is_given
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new analysis dev done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'analysis', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'dev', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'dev', :estimate => 4)
        create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        stacked-bar-chart
          conditions  : type = Story
          cumulative  : false
          x-label-start: analysis
          x-label-end: done
          series:
            - label       : 'Series 1'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*)
      }} })
        chart.extract_region_data
        chart.extract_region_mql

        expected_chart_data_with_region_data = {'done' =>{'Series 1' => {:cards => [{'name' => 'fifth', 'number' => '5'}], :count => 1}},
                                                'dev' =>
                                                    {'Series 1' => {:cards => [{'name' => 'fourth', 'number' => '4'},{'name' => 'third', 'number' => '3'}], :count => 2}},
                                                'analysis' =>
                                                    {'Series 1' => {:cards => [{'name' => 'second', 'number' => '2'}], :count => 1}}}
        expected_chart_data_with_region_mql = {'conditions' =>
                                                   {'analysis' =>
                                                        {'Series 1' => 'Type = Story AND status = analysis'},
                                                    'dev' =>
                                                        {'Series 1' => 'Type = Story AND status = dev'},
                                                    'done' =>
                                                        {'Series 1' => 'Type = Story AND status = done'}},
                                               'project_identifier' => {'Series 1' => project.identifier}}

        assert_equal expected_chart_data_with_region_mql, chart.region_mql
        assert_equal expected_chart_data_with_region_data, chart.region_data
      end
  end

  test 'should_set_default_y_title_As_NumberOfCards_when_not_given' do
    template = '{{
    stack-bar-chart
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

    chart = extract_chart(template)
    chart_json = JSON.parse(chart.generate)
    y_label= {"padding"=>{"top"=>25},
                   "label"=>{"text"=>"Number of cards", "position"=>"outer-middle"}}

    assert_equal(y_label, chart_json['axis']['y'])
  end

  test 'should_set_y_title_when_given' do
    template = '{{
    stack-bar-chart
      y-title: some-y-title
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

    chart = extract_chart(template)

    assert_equal('some-y-title', chart.y_title)
  end

  private

  def extract_chart(template, options={})
    Chart.extract(template, 'stack-bar', 1, options)
  end
end
