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

class PieChartTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit  
  def setup
    login_as_member
    @project = pie_chart_test_project
    @project.activate
  end
  
  def test_can_generate_data_from_non_host_project
    first_project.with_active_project do |active_project|
      template = %{ {{
        pie-chart
          project: #{@project.identifier}
          data: SELECT Feature, SUM(Size)
      }} }
      chart = Chart.extract(template, 'pie', 1)

      assert template_can_be_cached?(template, active_project)

      assert_equal [['Dashboard', 9], ['Applications', 2], ['Rate calculator', 3], ['Profile builder', 3]], chart.data
    end
  end
  
  def test_can_generate_data_based_on_query
    template = ' {{
      pie-chart
        data: SELECT Feature, SUM(Size)
    }} '
    chart = Chart.extract(template, 'pie', 1)

    assert template_can_be_cached?(template, @project)

    assert_equal [['Dashboard', 9], ['Applications', 2], ['Rate calculator', 3], ['Profile builder', 3]], chart.data
  end
  
  def test_can_generate_data_using_user_property
    template = ' {{
      pie-chart
        data: SELECT owner, SUM(Size)
    }} '
    chart = Chart.extract(template, 'pie', 1)
    assert_equal [['bob@email.com (bob)', 9], ['member@email.com (member)', 5], ['(not set)', 3]], chart.data
  end

  def test_can_generate_data_using_user_property_even_with_duplicated_user_display_name
    another_member = create_user!(:name => 'member@email.com', :login => 'member2')
    @project.add_member(another_member)
    @project.cards.last.update_attributes :cp_owner => another_member
    template = ' {{
      pie-chart
        data: SELECT owner, SUM(Size)
    }} '
    chart = Chart.extract(template, 'pie', 1)
    assert_equal [['bob@email.com (bob)', 9], ['member@email.com (member)', 5], ['member@email.com (member2)', 3], ], chart.data
  end  
  

  def test_can_generate_data_using_unmanaged_numeric_property
    template = ' {{
      pie-chart
        data: SELECT inaccurate_estimate, SUM(Size)
    }} '
    chart = Chart.extract(template, 'pie', 1)
    
    assert template_can_be_cached?(template, @project)
    
    assert_equal [['0.500', 7], ['1.000', 5], ['2', 2], ['2.03', 3]], chart.data
  end  

  def test_can_generate_data_using_text_property
    template = ' {{
      pie-chart
        data: SELECT text_feature, SUM(Size)
    }} '
    chart = Chart.extract(template, 'pie', 1)
    
    assert template_can_be_cached?(template, @project)
    
    assert_equal [['Applications', 2], ['Dashboard', 9], ['Profile builder', 3], ['Rate calculator', 3]], chart.data
  end

  def test_can_generate_data_using_date_property
    template = ' {{
      pie-chart
        data: SELECT date_created, SUM(Size)
    }} '
    
    chart = Chart.extract(template, 'pie', 1)
    assert template_can_be_cached?(template, @project)
    assert_equal [['2007-01-01', 3], ['2007-01-02', 5], ['2007-01-03', 6], ['2007-01-04', 3]], chart.data
  end
  
  def test_should_display_date_value_with_project_date_format
    template = ' {{
      pie-chart
        data: SELECT date_created, SUM(Size)
    }} '

    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    chart = Chart.extract(template, 'pie', 1)
    assert_equal [['01 Jan 2007', 3], ['02 Jan 2007', 5], ['03 Jan 2007', 6], ['04 Jan 2007', 3]], chart.data
  end

  def test_should_display_numeric_properties_with_project_precision
    template = ' {{
      pie-chart
        data: SELECT accurate_estimate, SUM(accurate_estimate)
    }} '

    chart = Chart.extract(template, 'pie', 1)
    assert_equal [['1.00', 1], ['1.123', 2.246], ['2.235', 4.47], ['3.667', 3.667], ['4.678', 4.678]].inspect, chart.data.inspect
  end
  
  def test_that_nil_label_will_not_cause_exception_when_using_pie_chart_with_numeric_property_definition
    formula_prop = @project.find_property_definition('size_times_two')
    create_card!(:name => 'new', :size => nil, :accurate_estimate => '1.00', :inaccurate_estimate => '0.5', :date_created => '2007-01-04', :feature => 'Dashboard', :text_feature => 'Dashboard')
    formula_prop.update_all_cards
    
    template = ' {{
      pie-chart
        data: SELECT size_times_two, COUNT(*)
    }} '
    
    chart = Chart.extract(template, 'pie', 1)
  end
  
  def test_should_display_not_set_for_null_values
    @project.cards.find_by_name('1').tap do |card1|
      card1.cp_feature = nil
      card1.save!
    end

    template = ' {{
      pie-chart
        data: SELECT Feature, SUM(Size)
    }} '
    chart = Chart.extract(template, 'pie', 1)
    
    assert template_can_be_cached?(template, @project)
    
    assert_equal [['Dashboard', 6], ['Applications', 2], ['Rate calculator', 3], ['Profile builder', 3], [PropertyValue::NOT_SET, 3]], chart.data
  end
  
  def test_give_a_nicer_message_when_mql_dont_have_aggregate_property
    template = ' {{
      pie-chart
        data: SELECT Feature
    }} '
    assert_raise Macro::ProcessingError do
      chart = Chart.extract(template, 'pie', 1)
    end
  end
  
  def test_can_generate_data_using_this_card
    with_card_query_project do |project|
      this_card = project.cards.create!(:name => 'this card', :card_type_name => 'Card', :cp_size => 1)
      related_card_property_definition = project.find_property_definition('related card')
      
      [['size one A', 1], ['size one B', 1], ['size two A', 2]].each do |card_name, size|
        card = project.cards.create!(:name => card_name, :cp_size => size, :card_type_name => 'Card')
        related_card_property_definition.update_card(card, this_card)
        card.save!
      end
      
      template = %{ {{
        pie-chart
          data: SELECT Size, COUNT(*) WHERE 'related card' = THIS CARD
      }} }
      
      chart = Chart.extract(template, 'pie', 1, {:content_provider => this_card})
      assert_equal [['1', 2], ['2', 1]], chart.data
    end
  end
  
  # bug 8703
  def test_can_use_this_card_in_project_parameter
    this_card = @project.cards.create!(:name => 'this card', :card_type_name => 'Card', :cp_text_feature => 'pie_chart_test_project')
    
    template = ' {{
      pie-chart
        project: this card.text_feature
        data: SELECT size, COUNT(*) WHERE type = card
    }} '
    
    chart = Chart.extract(template, 'pie', 1, { :content_provider => this_card })
    assert_equal [['1', 1], ['2', 2], ['3', 4], ['(not set)', 1]], chart.data
  end
  
  def test_should_support_from_tree
    with_three_level_tree_project do |project|
      template = '{{ pie-chart: data: SELECT Size, COUNT(*) FROM TREE "three level tree"}}'

      chart = Chart.extract(template, 'pie', 1, {:content_provider => project.cards[0]})
      assert_equal 3, chart.data.length
      
      not_in_tree = create_card!(:size => 10, :name => 'card not in tree', :number => 10)
      chart = Chart.extract(template, 'pie', 1, {:content_provider => project.cards[0]})        
      assert_equal 3, chart.data.length
    end
  end
  
  def test_can_generate_data_using_plvs
    create_plv!(@project, :name => 'my_data', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'SELECT Feature, SUM(Size)')
    
    with_first_project do |active_project|
      create_plv!(active_project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => @project.identifier)
      
      template = ' {{
        pie-chart
          project: (my_project)
          data: (my_data)
      }} '
      chart = Chart.extract(template, 'pie', 1)
    
      assert_equal [['Dashboard', 9], ['Applications', 2], ['Rate calculator', 3], ['Profile builder', 3]], chart.data
    end
  end

  def test_can_generate_region_data_based_on_query
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story',:status => 'done', :estimate => 16)
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story',:status => 'in-progress', :estimate => 8)

      template = ' {{
        pie-chart
          data: SELECT status, count(*)
       }} '
      chart = Chart.extract(template, 'pie', 1)

      new_cards = {:cards => [{:number => '1', :name => 'first'}], :count => 1}
      done_cards = {:cards => [{:number => '3', :name => 'third'}, {:number => '2', :name => 'second'}], :count => 2}
      in_progress_cards = {:cards => [{:number => '4', :name => 'fourth'}], :count => 1}
      assert_equal new_cards, chart.region_data['new']
      assert_equal done_cards, chart.region_data['done']
      assert_equal in_progress_cards, chart.region_data['in-progress']
    end
  end

  def test_can_generate_region_mql_based_on_query
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story',:status => 'done', :estimate => 16)
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story',:status => 'in-progress', :estimate => 8)

      template = ' {{
        pie-chart
          data: SELECT status, count(*)
       }} '
      chart = Chart.extract(template, 'pie', 1)

      expected = {
          'conditions' =>
              {
                  'new' => 'status = new',
                  'in-progress' => "status = 'in-progress'",
                  'done' => 'status = done'
              },
          'project_identifier' => "#{project.identifier}"
      }

      assert_equal expected, chart.region_mql
    end
  end


  def test_can_generate_region_mql_based_on_query_has_user_login_name_when_user_property_selected
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_user_definition('owner')
      setup_card_type(project, 'story', :properties => %w(status owner))
      user1 = create_user!
      user2 = create_user!
      project.add_member(user1)
      project.add_member(user2)

      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :owner => user1.id)
      create_card_in_future(2.seconds, :name => 'second', :card_type => 'story', :status => 'done', :owner => user2.id)
      template = ' {{
        pie-chart
          data: SELECT owner, count(*)
       }} '
      chart = Chart.extract(template, 'pie', 1)

      expected = {
          'conditions' =>
              {
                  user1.name_and_login => "owner = #{user1.login}",
                  user2.name_and_login => "owner = #{user2.login}",
              },
          'project_identifier' => "#{project.identifier}"
      }

      assert_equal expected, chart.region_mql
    end
  end

  def test_can_generate_region_data_with_integer_numeric_values
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card!(:name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card_in_future(2, :name => 'second', :card_type => 'story',:status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story',:status => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
       }} '
      chart = Chart.extract(template, 'pie', 1)

      cards_with_2_estimate = { :cards => [{:number => '2', :name => 'second'}, {:number => '1', :name => 'first'}], :count => 2 }
      cards_with_4_estimate = { :cards => [{:number => '3', :name => 'third'}], :count => 1}
      cards_with_not_set_estimate = {:cards => [{:number => '4', :name => 'fourth'}], :count => 1}

      assert_equal cards_with_2_estimate, chart.region_data['2']
      assert_equal cards_with_4_estimate, chart.region_data['4']
      assert_equal cards_with_not_set_estimate, chart.region_data['(not set)']
    end
  end

  def test_can_generate_region_mql
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'property definition with white spaces', [2, 4, 8, 16]

      setup_card_type(project, 'story', :properties => ['status', 'property definition with white spaces'])
      create_card!(:name => 'first', :card_type => 'story',:status => 'new', 'property definition with white spaces' => 2)
      create_card_in_future(2, :name => 'second', :card_type => 'story',:status => 'done', 'property definition with white spaces' => 2)
      create_card!(:name => 'third', :card_type => 'story',:status => 'done', 'property definition with white spaces' => 4)
      create_card!(:name => 'fourth', :card_type => 'story','property definition with white spaces' => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT status, count(*)
       }} '
      chart = Chart.extract(template, 'pie', 1)

      expected = {
          'conditions' => {
            'new' => 'status = new',
            'done' => 'status = done',
            '(not set)' => 'status IS NULL'
          },
          'project_identifier' => "#{project.identifier}"
      }

      assert_equal expected, chart.region_mql

      template = %{ {{
        pie-chart
          data: SELECT 'property definition with white spaces', count(*)
       }} }
      chart = Chart.extract(template, 'pie', 1)

      expected = {
          'conditions' => {
            '2' =>"'property definition with white spaces' = '2.00'",
            '4' =>"'property definition with white spaces' = '4.00'",
            '(not set)' =>"'property definition with white spaces' IS NULL"
          },
          'project_identifier' => "#{project.identifier}"
      }

      assert_equal expected, chart.region_mql
    end
  end

  def test_pie_chart_with_is_scaled_based_on_radius
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story',:status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story',:status => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-height: 200
          chart-width: 400
          radius: 250
       }} '
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_nil chartData['size']['width']
      assert_equal 525, chartData['size']['height']
    end
  end

  def test_should_consider_content_provider_while_generating_ids_for_charts
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-height: 300
          chart-width: 440
          radius: 250
       }} '
      expected_chart_container_and_script = %Q{<div id='piechart-Card-#{card.id}-1' class='pie-chart medium' style='margin: 0 auto; width: 440px; height: 300px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#piechart-Card-#{card.id}-1'
      ChartRenderer.renderChart('pieChart', dataUrl, bindTo);
    </script>}
      chart = PieChart.new({content_provider: card, view_helper: view_helper}, 'pie-chart', {'data' => 'SELECT estimate, count(*)',
                                                                                             'chart-height' => 300,
                                                                                             'chart-width' => 440,
                                                                                             'radius' => 250}, template)
      chart_container_and_script = chart.chart_callback({position: 1, controller: :cards})
      assert_equal expected_chart_container_and_script.strip, chart_container_and_script.strip
    end
  end

    def test_should_append_preview_to_identifier_for_preview_window
      with_new_project do |project|
        setup_property_definitions 'status' => %w(new in-progress done in-prod)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
        create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

        template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-height: 300
          chart-width: 440
          radius: 250
       }} '
        expected_chart_container_and_script = %Q{<div id='piechart-Card-#{card.id}-1-preview' class='pie-chart medium' style='margin: 0 auto; width: 440px; height: 300px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1&preview=true'
      var bindTo = '#piechart-Card-#{card.id}-1-preview'
      ChartRenderer.renderChart('pieChart', dataUrl, bindTo);
    </script>}
        chart = PieChart.new({content_provider: card, view_helper: view_helper}, 'pie-chart', {'data' => 'SELECT estimate, count(*)',
                                                                                               'chart-height' => 300,
                                                                                               'chart-width' => 440,
                                                                                               'radius' => 250}, template)
        chart_container_and_script = chart.chart_callback({position: 1, preview: true, controller: :cards})
        assert_equal expected_chart_container_and_script.strip, chart_container_and_script.strip
      end
    end

  def test_should_set_title_for_pie_chart
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-height: 200
          chart-width: 400
          radius: 250
          title: 'Velocity Chart'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      expected = {'text' => 'Velocity Chart'}
      assert_equal expected, chartData['title']
    end
  end

  def test_should_not_update_the_default_chart_dimensions_when_chart_size_is_set_to_default
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          title: 'Velocity Chart'
          chart-size: 'medium'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_equal 300, chartData['size']['height']
      assert_equal 440, chartData['size']['width']
    end
  end


  def test_should_update_the_default_chart_dimensions_to_half_when_chart_size_is_set_to_small
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          title: 'Velocity Chart'
          chart-size: 'small'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_equal 150, chartData['size']['height']
      assert_equal 220, chartData['size']['width']
    end
  end


  def test_should_update_the_default_chart_dimensions_to_double_when_chart_size_is_set_to_large
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          title: 'Velocity Chart'
          chart-size: 'large'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_equal 600, chartData['size']['height']
      assert_equal 880, chartData['size']['width']
    end
  end

  def test_should_not_update_the_chart_dimensions_when_chart_size_and_dimensions_are_set
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          title: 'Velocity Chart'
          chart-height: 200
          chart-width: 400
          chart-size: 'large'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_equal 200, chartData['size']['height']
      assert_equal 400, chartData['size']['width']
    end
  end

  def test_should_not_update_the_chart_dimensions_when_chart_size_and_radius_is_set
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          title: 'Velocity Chart'
          radius: 200
          chart-size: 'large'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_equal 420, chartData['size']['height']
      assert_nil chartData['size']['width']
    end
  end

  def test_should_set_label_type_and_legend_position
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = %{ {{
        pie-chart
          data: SELECT estimate, count(*)
          title: 'Velocity Chart'
          radius: 200
          label-type: 'Whole-number'
          legend-position: 'bottom'
       }} }
      chart = Chart.extract(template, 'pie', 1, {content_provider: card})
      chartData = JSON.parse!(chart.generate)
      assert_equal 'bottom', chartData['legend']['position']
      assert_equal 'whole-number', chartData['label_type']
    end
  end

  def test_should_append_medium_class_to_chart_when_chart_size_is_medium
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-height: ''
          chart-width: ''
          radius:
          chart-size: Medium
       }} '
      expected_chart_container_and_script = %Q{<div id='piechart-Card-#{card.id}-1' class='pie-chart medium' style='margin: 0 auto; width: 440px; height: 300px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#piechart-Card-#{card.id}-1'
      ChartRenderer.renderChart('pieChart', dataUrl, bindTo);
    </script>}
      chart = PieChart.new({content_provider: card, view_helper: view_helper}, 'pie-chart', {'data' => 'SELECT estimate, count(*)',
                                                                                             'chart-height' => 300,
                                                                                             'chart-width' => 440,
                                                                                             'chart-size' => 'medium',
                                                                                             'radius' => 250}, template)
      chart_container_and_script = chart.chart_callback({position: 1, controller: :cards})
      assert_equal expected_chart_container_and_script.strip, chart_container_and_script.strip
    end
  end

  def test_should_append_large_class_to_chart_when_chart_dimensions_are_greater_than_default
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-height: 500
          chart-width: 600
       }} '
      expected_chart_container_and_script = %Q{<div id='piechart-Card-#{card.id}-1' class='pie-chart large' style='margin: 0 auto; width: 600px; height: 500px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#piechart-Card-#{card.id}-1'
      ChartRenderer.renderChart('pieChart', dataUrl, bindTo);
    </script>}
      chart = PieChart.new({content_provider: card, view_helper: view_helper}, 'pie-chart', {'data' => 'SELECT estimate, count(*)',
                                                                                             'chart-height' => 500, 'chart-width' => 600}, template)
      chart_container_and_script = chart.chart_callback({position: 1, controller: :cards})
      assert_equal expected_chart_container_and_script.strip, chart_container_and_script.strip
    end
  end

  def test_should_append_large_class_to_chart_when_chart_size_is_set_to_large_with_default_dimensions
    with_new_project do |project|
      setup_property_definitions 'status' => %w(new in-progress done in-prod)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      card = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story', :status => 'done', :estimate => 2)
      create_card!(:name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
      create_card!(:name => 'fourth', :card_type => 'story', :status => 'in-progress')

      template = ' {{
        pie-chart
          data: SELECT estimate, count(*)
          chart-size: large
       }} '
      expected_chart_container_and_script = %Q{<div id='piechart-Card-#{card.id}-1' class='pie-chart large' style='margin: 0 auto; width: 880px; height: 600px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#piechart-Card-#{card.id}-1'
      ChartRenderer.renderChart('pieChart', dataUrl, bindTo);
    </script>}
      chart = PieChart.new({content_provider: card, view_helper: view_helper}, 'pie-chart', {'data' => 'SELECT estimate, count(*)',
                                                                                             'chart-size' => 'large'}, template)
      chart_container_and_script = chart.chart_callback({position: 1, controller: :cards})
      assert_equal expected_chart_container_and_script.strip, chart_container_and_script.strip
    end
  end

  def test_should_set_chart_width_numeric_value_when_specified_in_pixels
    template = ' {{
      pie-chart
        data: SELECT date_created, SUM(Size)
        chart-width: 500 px
    }} '

    chart = Chart.extract(template, 'pie', 1)
    assert_equal 500, chart.chart_width
  end

  def test_should_set_chart_height_numeric_value_when_specified_in_pixels
    template = ' {{
      pie-chart
        data: SELECT date_created, SUM(Size)
        chart-height: 450px
    }} '

    chart = Chart.extract(template, 'pie', 1)
    assert_equal 450, chart.chart_height
  end
end



