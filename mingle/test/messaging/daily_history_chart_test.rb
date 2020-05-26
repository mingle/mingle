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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

# Tags: daily_history
class DailyHistoryChartTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    super
    SwapDir::DailyHistoryChart.root.delete
    Clock.reset_fake
    login_as_member
  end

  def teardown
    super
    Clock.reset_fake
  end

  def test_process_one_daily_history_chart_job_should_generate_all_data_points_need
    template = default_template(:start_date => "May 13 2009", :end_date => "May 16 2009")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      create_card!(:name => 'hello2', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 16)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      assert_equal [3, 3], chart.progress
      assert chart.ready?
      assert_equal [1, 2, 2, 2], chart.series_values.flatten
    end
  end

  def test_should_cache_series_values_once_read
    template = default_template(:start_date => "May 13 2009", :end_date => "May 16 2009")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      assert_equal [1, 2, 2], chart.series_values.flatten
      SwapDir::DailyHistoryChart.root.delete
      assert_equal [1, 2, 2], chart.series_values.flatten
    end
  end

  def test_should_send_daily_history_chart_message_that_is_needed_for_the_chart_while_publishing
    template = default_template(:start_date => "May 13 2009", :end_date => "May 16 2009")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      create_card!(:name => 'hello', :card_type => 'Card')

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      assert_equal [1, 2, 3], chart.series_values.flatten
    end
  end

  def test_should_send_daily_history_chart_messages_that_is_needed_for_the_chart_while_publishing_after_first_time_published
    template = default_template(:start_date => "May 13 2009", :end_date => "May 20 2009")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      create_card!(:name => 'hello', :card_type => 'Card')

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 16)
      create_card!(:name => 'hello', :card_type => 'Card')
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      assert_equal [1, 2, 3, 4], chart.series_values.flatten
    end
  end

  def test_x_labels_step
    template = x_labels_step_template(3)
    with_first_project do |project|
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert_equal 3, chart.x_labels_step
    end
  end

  def test_daily_history_chart_render_as_text_generated_step_info
    template = x_labels_step_template(3)
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      create_card!(:name => 'hello', :card_type => 'Card')
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)
    project.with_active_project do |project|
      assert_include "<dd>step</dd><dt id='value_for_step'>3</dt>", chart.generate_as_text
    end
  end

  def test_x_labels_step_default_value
    template = x_labels_step_template(nil)
    with_first_project do |project|
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert_equal 1, chart.x_labels_step
    end
  end

  def test_x_labels_should_range_from_start_date_to_end_date
    template = default_template(:start_date => '20 May 2010', :end_date => '23 May 2010')
    with_first_project do |project|
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert_equal ['Thu, 20 May 2010', 'Fri, 21 May 2010', 'Sat, 22 May 2010', 'Sun, 23 May 2010'].map{|d| Date.parse d}, chart.x_axis_values
    end
  end

  def test_should_show_updated_result_after_deleting_a_card
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '1 Jan 2009', :end_date => '2 Jan 2009')
    chart = nil
    card = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 1, :day => 1)
      card = create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 1, :day => 2)
      create_card!(:name => 'hello again', :card_type => 'Card')

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      card.destroy
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)

    project.with_active_project do |project|
      assert_equal [0, 1], chart.series_values.flatten
    end
  end

  def test_should_clear_cache_upon_updating_a_card_if_the_chart_refereces_the_container_card_in_its_parameters
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => 'this card."end date"')
    chart = nil
    card = nil
    end_date = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      end_date = setup_date_property_definition "end date"
      Clock.fake_now(:year => 2009, :month => 6, :day => 3)
      card = create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      Clock.fake_now(:year => 2009, :month => 6, :day => 4)
      create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      Clock.fake_now(:year => 2009, :month => 6, :day => 5)
      create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)

    project.with_active_project do |project|
      assert_equal [[0,1]], chart.series_values

      Clock.fake_now(:year => 2009, :month => 6, :day => 5)
      end_date.update_card(card, Clock.today)
      card.save!

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)

    project.with_active_project do |project|
      assert_equal [[0,1,2,3]], chart.series_values
    end
  end

  def test_should_not_clear_cache_upon_updating_a_card_if_the_chart_does_not_referece_the_container_card_in_its_parameters
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => '6 Jun 2009')
    chart = nil
    end_date = nil
    card1 = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      end_date = setup_date_property_definition "end date"
      Clock.fake_now(:year => 2009, :month => 6, :day => 3)
      card1 = create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      Clock.fake_now(:year => 2009, :month => 6, :day => 4)
      create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      Clock.fake_now(:year => 2009, :month => 6, :day => 5)
      create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)
    project.with_active_project do |project|
      assert_equal [[0,1,2,3]], chart.series_values

      Clock.fake_now(:year => 2009, :month => 6, :day => 5)
      end_date.update_card(card1, Clock.today)
      card1.save!

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
      assert chart.ready?
    end
  end

  def test_should_be_able_to_use_plvs_in_chart_conditions
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => '6 Jun 2009', :chart_conditions => "status = (open_status)")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:Status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      create_plv(project, :name => 'open_status', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'open', :property_definition_ids => [status.id])
      Clock.fake_now(:year => 2009, :month => 6, :day => 2)
      card1 = create_card!(:name => 'card', :status => 'open')
      Clock.fake_now(:year => 2009, :month => 6, :day => 3)
      create_card!(:name => 'card2', :status => 'new')
      create_card!(:name => 'card2', :status => 'open')
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)
    project.with_active_project do |project|
      assert_equal [[1, 2]], chart.series_values
    end
  end

  def test_should_be_able_to_use_plvs_in_series_conditions
    params = Macro::Builder.parse_parameters(%{
      start-date: 2 Jun 2009
      end-date: 6 Jun 2009
      series:
      - label: First
        conditions: status = (open_status)
    })

    template = default_template(params)
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:Status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      create_plv(project, :name => 'open_status', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'open', :property_definition_ids => [status.id])
      Clock.fake_now(:year => 2009, :month => 6, :day => 2)
      card1 = create_card!(:name => 'card', :status => 'open')
      Clock.fake_now(:year => 2009, :month => 6, :day => 3)
      create_card!(:name => 'card2', :status => 'new')
      create_card!(:name => 'card2', :status => 'open')
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)
    project.with_active_project do |project|
      assert_equal [[1, 2]], chart.series_values
    end
  end

  def test_should_show_updated_result_on_change_of_plv
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => '6 Jun 2009', :chart_conditions => "status = (open_status)")
    chart = nil
    plv = nil
    card1 = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:Status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      plv = create_plv(project, :name => 'open_status', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'open', :property_definition_ids => [status.id])
      Clock.fake_now(:year => 2009, :month => 6, :day => 2)
      card1 = create_card!(:name => 'card', :status => 'open')
      Clock.fake_now(:year => 2009, :month => 6, :day => 3)
      create_card!(:name => 'card2', :status => 'new')
      create_card!(:name => 'card3', :status => 'open')
      Clock.fake_now(:year => 2009, :month => 6, :day => 4)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)
    project.with_active_project do |project|
      assert_equal [[1, 2, 2]], chart.series_values

      plv.value = 'new'
      plv.save!
      project.reload

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)

    project.with_active_project do |project|
      assert_equal [[0, 1, 1]], chart.series_values
    end
  end

  def test_should_be_able_to_use_this_card_in_chart_conditions
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => '6 Jun 2009', :chart_conditions => "'Planning iteration' = THIS CARD")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 6, :day => 2)
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree
      iteration1 = project.cards.find_by_name('iteration1')
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => iteration1)
      Clock.fake_now(:year => 2009, :month => 6, :day => 4)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 100)

    project.with_active_project do |project|
      assert_equal [[2, 2, 2]], chart.series_values
    end
  end

  def test_should_work_with_project_timezone
    template = default_template(:start_date => '13 May 2009', :end_date => '16 May 2009')
    chart = nil
    project = create_project(:time_zone => 'Beijing')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13, :hour => 17) # 2009-05-14 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14, :hour => 17) # 2009-05-15 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 15, :hour => 17) # 2009-05-16 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)
    project.with_active_project do |project|
      assert chart.ready?
      assert_equal [0, 1, 2, 3], chart.series_values.flatten
    end
  end

  def test_should_time_out_generating_data_after_x_amount_of_time
    template = default_template(:start_date => '13 May 2009', :end_date => '16 May 2009')
    with_new_project(:time_zone => 'UTC') do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13)
      card = create_card!(:name => 'hello', :card_type => 'Card')

      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      clear_message_queue(DailyHistoryChartProcessor::QUEUE)

      chart.generate_cache_data(Clock.now - 60)
      assert_equal [0, 1], chart.progress
      assert_false chart.ready?

      chart.generate_cache_data
      assert chart.ready?
      assert_equal [1, 1], chart.progress
    end
  end

  def test_another_case_for_working_with_project_timezone
    template = default_template(:start_date => '13 May 2009', :end_date => '16 May 2009')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      project.update_attributes! :time_zone => 'Beijing'
      Clock.fake_now(:year => 2009, :month => 5, :day => 13, :hour => 17) # 2009-05-14 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')

      Clock.fake_now(:year => 2009, :month => 5, :day => 14, :hour => 18) # 2009-05-15 02:00:00 beijing time
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 3)
    project.with_active_project do |project|
      assert chart.ready?
      assert_equal [0, 1, 1], chart.series_values.flatten
    end
  end

  def test_should_change_to_use_new_project_timezone_after_project_timezone_changed
    template = default_template(:start_date => '13 May 2009', :end_date => '16 May 2009')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      project.update_attributes! :time_zone => 'Beijing'
      Clock.fake_now(:year => 2009, :month => 5, :day => 13, :hour => 17) # 2009-05-14 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14, :hour => 17) # 2009-05-15 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 15, :hour => 17) # 2009-05-16 01:00:00 beijing time
      card = create_card!(:name => 'hello', :card_type => 'Card')

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 3)

    project.with_active_project do |project|
      project.update_attributes! :time_zone => 'UTC'

      assert !chart.ready?
      chart.publish
    end

    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 3)
    project.with_active_project do |project|
      assert_equal [1, 2, 3], chart.series_values.flatten
    end
  end

  def test_should_be_alright_when_project_structure_changed
    template = default_template(:chart_conditions => 'status = null')
    chart = nil
    card = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:Status => ['fixed', 'new', 'open', 'closed','in progress'])

      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      card = create_card!(:name => 'hello', :card_type => 'Card', :status => 'new')

      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)
    project.with_active_project do |project|
      card.update_attribute(:cp_status, nil)
      assert_equal [0, 1], chart.series_values.flatten

      status_new = project.find_property_definition('status').values.detect {|v| v.value == 'new'}
      status_new.destroy

      chart.publish
    end
      DailyHistoryChart.process(:batch_size => 1)

      # since series values are cached, recreate chart instance
    project.with_active_project do |project|
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      assert_equal [1, 1], chart.series_values.flatten
    end
  end

  def test_should_be_able_to_handle_complex_and_long_conditions
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: iteration = 1 and release = 1 and release = 2 and release = 3
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: 1
            conditions: status = new and status = open and status = closed
          - label: 2
            conditions: status = new or status = open and status = closed
          - label: 3
            conditions: status = new and status = open or status = closed
          - label: 4
            conditions: status = new or status = open or status = closed
          - label: 5
            conditions: status is not new and status is not open and status is not closed
          - label: 6
            conditions: status = new and status = open and status is not closed
    }} }
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:Status => ['fixed', 'new', 'open', 'closed','in progress'],:Iteration => ['1', '2'])
      setup_numeric_property_definition('Release', ['1', '2'])
      card = create_card!(:name => 'hello', :card_type => 'Card', :status => 'new')
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process
  end

  def test_should_give_real_time_report_data_for_today
    template = default_template(:chart_conditions => 'Release = 33', :start_date => "May 13 2009", :end_date => "May 16 2009")
    chart = nil
    card = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_numeric_property_definition('Release', ['1', '2'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      card = create_card!(:name => 'hello', :card_type => 'Card', :release => 33)
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)
    project.with_active_project do |project|
      assert_equal [[0, 1]], chart.series_values

      card.update_attribute(:cp_release, 22)

      # since series values are cached, recreate chart instance
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      assert_equal [[0, 0]], chart.series_values
    end
  end

  def test_publish_and_process_should_create_data_for_the_day_before_today
    template = default_template(:start_date => "May 13 2009", :end_date => "May 19 2009")
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 13)
      card = create_card!(:name => 'hello', :card_type => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      card = create_card!(:name => 'hello again', :card_type => 'Card')

      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish

      assert_equal [0, 0, 2], chart.series_values.flatten
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 1)
    project.with_active_project do |project|
      # since series values are cached, recreate chart instance
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert_equal [1, 2, 2], chart.series_values.flatten
    end
  end

  def test_values_should_be_calculated_using_aggregation_of_count_as_of_each_date
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label:
            conditions: Type = 'Card'
    }} }

    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      create_card!(:name => 'hello', :card_type_name => 'Card')
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      create_card!(:name => 'hello', :card_type_name => 'Card')
      Clock.reset_fake

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 2)
    project.with_active_project do |project|
      assert_equal ['14 May 2009', '15 May 2009'].map{|d| Date.parse d}, chart.x_axis_values
      assert_equal [1, 2], chart.series_values.first
    end
  end

  def test_values_should_be_calculated_using_aggregation_sum_as_of_each_date
    template = %{ {{
      daily-history-chart
        aggregate: SUM(release)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label:
            conditions: Type = 'Card'
    }} }

    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_numeric_property_definition('Release', ['1', '2'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      card = create_card!(:name => 'hello', :card_type => 'Card', :release => 2)
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      card.update_attribute(:cp_release, 1)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 2)
    project.with_active_project do |project|
      assert_equal ['14 May 2009', '15 May 2009'].map{|d| Date.parse d}, chart.x_axis_values
      assert_equal [2, 1], chart.series_values.first
    end
  end

  def test_series_should_apply_condition_to_aggregate
    template = %{ {{
      daily-history-chart
        aggregate: SUM(Size)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label:
            conditions: Size > 1
    }} }
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      card_type = project.card_types.create! :name => 'Story'
      prop = setup_numeric_property_definition 'Size', []
      card_type.add_property_definition prop

      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      card = create_card!(:name => 'hello', :card_type => 'Story', :size => 2)
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      card.update_attribute(:cp_size, 1)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 2)
    project.with_active_project do |project|
      assert_equal ['14 May 2009', '15 May 2009'].map{|d| Date.parse d}, chart.x_axis_values
      assert_equal [2, 0], chart.series_values.first
    end
  end

  def test_data_history_chart_should_not_raise_an_error_if_there_is_no_work_to_do
    assert_nothing_raised do
      DailyHistoryChart.process
    end
  end

  def test_series_should_allow_zero_values
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_numeric_property_definition('Release', ['1', '2'])
      create_card!(:name => "card 1", :card_type => "Card")
      template = default_template(:aggregate => 'SUM(release)', :start_date => '14 May 2009', :end_date => '15 May 2009')
      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 2)
    project.with_active_project do |project|
      assert_equal ['14 May 2009', '15 May 2009'].map{|d| Date.parse d}, chart.x_axis_values
      assert_equal [0, 0], chart.series_values.first
    end
  end

  def test_chart_could_contain_many_series
    template = %{ {{
      daily-history-chart
        aggregate: SUM(Size)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label:
            conditions: Size > 1
          - label:
            conditions: Size = 1
    }} }
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      card_type = project.card_types.create! :name => 'Story'
      prop = setup_numeric_property_definition 'Size', []
      card_type.add_property_definition prop
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)
      card = create_card!(:name => 'hello', :card_type => 'Story', :size => 2)
      Clock.fake_now(:year => 2009, :month => 5, :day => 15)
      card.update_attribute(:cp_size, 1)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 2)
    project.with_active_project do |project|
      assert_equal [[2, 0], [0, 1]], chart.series_values
    end
  end

  def test_chart_conditions_should_restrict_results_set_on_all_series
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: iteration = 1
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: First
            conditions: status > new
          - label: Second
            conditions: status = open
    }} }
    with_first_project do |project|
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)

      create_card!(:name => 'included in first',          :card_type => 'Card', :status => 'closed', :iteration => 1)
      create_card!(:name => 'included in first & second', :card_type => 'Card', :status => 'open', :iteration => 1)
      create_card!(:name => 'excluded',                   :card_type => 'Card', :status => 'open', :iteration => 2)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert_equal [[2], [1]], chart.series_values
    end
  end

  def test_ready_should_be_true_if_all_data_until_yesterday_is_cached
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      content_provider = create_card!(:name => "card", :card_type => "Card")
      Clock.fake_now(:year => 2009, :month => 5, :day => 18)
      template = default_template(:start_date => "May 17 2009", :end_date => "May 19 2009")

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => content_provider)
      chart.publish
      assert !chart.ready?, "Expected chart to not be ready, but it was."
    end
    Project.clear_active_project!
    DailyHistoryChart.process
    project.with_active_project do |project|
      assert chart.ready?, "Expected chart to be ready, but it was not, sadly."
    end
  end

  def test_should_be_ready_if_start_date_is_today
    with_first_project do |project|
      content_provider = project.cards.first
      Clock.fake_now(:year => 2009, :month => 5, :day => 17)
      template = default_template(:start_date => "May 17 2009", :end_date => "May 19 2009")

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => content_provider)
      chart.publish
      assert chart.ready?, "Expected chart to not be ready, but it was."
    end
  end

  def test_should_be_none_for_data_symbol_when_start_date_is_not_today
    with_first_project do |project|
      content_provider = project.cards.first
      Clock.fake_now(:year => 2009, :month => 5, :day => 18)
      template = default_template(:start_date => "May 17 2009", :end_date => "May 19 2009")

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => content_provider)
      assert_equal chart.data_symbol, "none"
    end
  end

  def test_should_be_diamond_for_data_symbol_when_start_date_is_today
    with_first_project do |project|
      content_provider = project.cards.first
      Clock.fake_now(:year => 2009, :month => 5, :day => 17)
      template = default_template(:start_date => "May 17 2009", :end_date => "May 19 2009")

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => content_provider)
      assert_equal chart.data_symbol, "diamond"
    end
  end

  def test_new_chart_should_not_be_ready
    with_first_project do |project|
      chart = Chart.extract(default_template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert !chart.ready?, "Expected chart to not be ready, but it was."
    end
  end

  def test_should_not_be_ready_when_chart_start_date_is_today_or_after_today
    with_first_project do |project|
      Clock.fake_now(:year => 2000, :month => 5, :day => 5)
      chart = Chart.extract(default_template(:start_date => "May 06 2010", :end_date => 'May 07 2010'), 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert !chart.ready?, "Expected chart to not be ready, but it was."

      chart = Chart.extract(default_template(:start_date => "May 05 2010", :end_date => 'May 06 2010'), 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert !chart.ready?, "Expected chart to not be ready, but it was."

      chart = Chart.extract(default_template(:start_date => "May 04 2010", :end_date => 'May 06 2010'), 'daily-history-chart', 1, :content_provider => project.cards.first)
      assert !chart.ready?, "Expected chart to not be ready, but it was."
    end
  end

  def test_should_get_todays_values_for_a_series
    with_first_project do |project|
      project.card_types.create!(:name => 'Story')
      project.cards.create!(:name => 'a nice story card', :card_type_name => 'Story')

      template = %{ {{
        daily-history-chart
          aggregate: "COUNT(*)"
          start-date: #{Date.parse("14 May 2009").to_date.strftime("%d %b %Y")}
          end-date: #{Date.parse("17 May 2009").to_date.strftime("%d %b %Y")}
          series:
            - label: First
              conditions: Type = Card
            - label: Second
              conditions: Type is not Card
      }} }

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      count_of_cards = project.cards.count(:all, :conditions => ["card_type_name = 'Card'"])
      count_of_non_cards = project.cards.count(:all, :conditions => ["card_type_name != 'Card'"])

      assert_equal [['First', count_of_cards], ['Second', count_of_non_cards]], chart.todays_values
    end
  end

  def test_should_generate_chart_for_forecasts
    template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open', 'closed'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)
      card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
      card2 = create_card!(:name => 'in scope 2', 'status' => 'open')
      card3 = create_card!(:name => 'in scope 3', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 10)
      card2.cp_status = 'closed'
      card2.save!
      card4 = create_card!(:name => 'in scope 4', 'status' => 'open')
      card5 = create_card!(:name => 'in scope 5', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 12)
      card3.cp_status = 'closed'
      card3.save!

      Clock.fake_now(:year => 2009, :month => 5, :day => 14)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 20)
    project.with_active_project do |project|
      assert chart.generate_as_text
    end
  end

  def test_scope_and_completion_series_values_should_be_case_insensitive
    template = forecast_template('scope-series' => 'SCOPE', 'completion-series' => 'COMPLETED')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open', 'closed'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)
      card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
      card2 = create_card!(:name => 'in scope 1', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 10)
      card2.cp_status = 'closed'
      card2.save!
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 20)
    project.with_active_project do |project|
      rendered_result = chart.generate_as_text

      assert_match /<[^>]+50% Increase in Remaining Scope'>2.5</, rendered_result
    end
  end

  def test_should_extend_x_axis_labels_when_forecast_value_is_out_of_end_date_of_the_chart
    template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open', 'closed'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)
      card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
      card2 = create_card!(:name => 'in scope 2', 'status' => 'open')
      card3 = create_card!(:name => 'in scope 3', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 10)
      card2.cp_status = 'closed'
      card2.save!
      card4 = create_card!(:name => 'in scope 4', 'status' => 'open')
      card5 = create_card!(:name => 'in scope 5', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 12)
      card3.cp_status = 'closed'
      card3.save!

      Clock.fake_now(:year => 2009, :month => 5, :day => 14)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 20)
    project.with_active_project do |project|
      assert_equal Date.parse('02 Jun 2009'), chart.x_axis_values.last
    end
  end

  def test_should_not_allow_target_release_date_when_there_is_no_scope_and_completion_series
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 16 May 2009
        target-release-date: 15 May 2009
        series:
          - label: First
    }} }
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_generate_chart_for_forecasts_with_target_release_date
    template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009', 'target-release-date' => '15 May 2009')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open', 'closed'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)
      card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
      card2 = create_card!(:name => 'in scope 2', 'status' => 'open')
      card3 = create_card!(:name => 'in scope 3', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 10)
      card2.cp_status = 'closed'
      card2.save!
      card4 = create_card!(:name => 'in scope 4', 'status' => 'open')
      card5 = create_card!(:name => 'in scope 5', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 12)
      card3.cp_status = 'closed'
      card3.save!

      Clock.fake_now(:year => 2009, :month => 5, :day => 14)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)

      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 20)
    project.with_active_project do |project|
      assert chart.generate
    end
  end

  def test_should_only_clear_cache_if_updated_property_is_used_as_this_card_property
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => 'this card."end date"')
    chart = nil
    card1 = nil
    unrelated_date = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      unrelated_date = setup_date_property_definition "unrelated date"
      end_date = setup_date_property_definition "end date"
      Clock.fake_now(:year => 2009, :month => 6, :day => 3)
      card1 = create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      Clock.fake_now(:year => 2009, :month => 6, :day => 4)
      create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      Clock.fake_now(:year => 2009, :month => 6, :day => 5)
      create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      chart.publish
    end
    Project.clear_active_project!
    DailyHistoryChart.process(:batch_size => 4)
    project.with_active_project do |project|
      assert_equal [[0,1]], chart.series_values

      Clock.fake_now(:year => 2009, :month => 6, :day => 5)
      unrelated_date.update_card(card1, Clock.today)
      card1.save!

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)

      assert_equal [[0,1]], chart.series_values
    end
  end

  def test_execute_macro_should_return_easy_charts_callback_when_c3_enabled
      template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2016', :end_date => 'this card."end date"')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_date_property_definition "unrelated date"
        setup_date_property_definition "end date"
        Clock.fake_now(:year => 2009, :month => 6, :day => 3)
        card = create_card!(:name => 'hello', :card_type => 'Card', :"end date" => Clock.today)
        scanner = StringScanner.new(template)
        scanner.scan_until(Chart::MACRO_SYNTAX)
        parameters = Macro.parse_parameters(scanner[2])
        chart = Macro.create('daily-history-chart', {:project => project,
                                                     :macro_position => 1,
                                                   :view_helper => view_helper,
                                                   :content_provider_project => project,
                                                   :content_provider => card}, parameters, template)

        expected_chart_container_and_script = %Q{<div id='dailyhistorychart-Card-#{card.id}-1' class='daily-history-chart medium' style='margin: 0 auto'></div>
    <script type="text/javascript">
      var dataUrl = '/projects/#{project.identifier}/cards/chart_data/#{card.id}?position=1&type=daily-history-chart'
      var bindTo = '#dailyhistorychart-Card-#{card.id}-1'
      ChartRenderer.renderChart('dailyHistoryChart', dataUrl, bindTo);
    </script>}
        assert_equal expected_chart_container_and_script, chart.execute_macro
      end
  end

  def test_should_invoke_render_c3_forecast
      template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_property_definitions(:status => ['new', 'open', 'closed'])
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
        card2 = create_card!(:name => 'in scope 2', 'status' => 'open')
        card3 = create_card!(:name => 'in scope 3', 'status' => 'open')
        Clock.fake_now(:year => 2009, :month => 5, :day => 10)
        card2.cp_status = 'closed'
        card2.save!
        create_card!(:name => 'in scope 4', 'status' => 'open')
        create_card!(:name => 'in scope 5', 'status' => 'open')
        Clock.fake_now(:year => 2009, :month => 5, :day => 12)
        card3.cp_status = 'closed'
        card3.save!

        Clock.fake_now(:year => 2009, :month => 5, :day => 16)
        dhc_renderer = Charts::C3Renderers::DailyHistoryChartRenderer.new(nil, nil)

        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
        chart.stubs(:ready?).returns(true)
        C3Renderers.expects(:daily_history_chart_renderer).returns(dhc_renderer)

        chart.expects(:render_forecast).with(dhc_renderer).once
        chart.generate
      end
    end

  def test_should_enable_data_labels_for_total_scope_and_current_scope_end_point
      template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_property_definitions(:status => ['new', 'open', 'closed'])
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
        card2 = create_card!(:name => 'in scope 2', 'status' => 'open')
        card3 = create_card!(:name => 'in scope 3', 'status' => 'open')
        Clock.fake_now(:year => 2009, :month => 5, :day => 10)
        card2.cp_status = 'closed'
        card2.save!
        create_card!(:name => 'in scope 4', 'status' => 'open')
        create_card!(:name => 'in scope 5', 'status' => 'open')
        Clock.fake_now(:year => 2009, :month => 5, :day => 12)
        card3.cp_status = 'closed'
        card3.save!

        Clock.fake_now(:year => 2009, :month => 5, :day => 16)
        dhc_renderer = Charts::C3Renderers::DailyHistoryChartRenderer.new(nil, nil)
        C3Renderers.expects(:daily_history_chart_renderer).returns(dhc_renderer)

        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
        chart.stubs(:ready?).returns(true)
        dhc_renderer.expects(:enable_data_labels_on_selected_positions).with('Scope',8).once
        dhc_renderer.expects(:enable_data_labels_on_selected_positions).with('Completed',8).once
        chart.generate
    end
  end

  def test_should_not_forecast_when_start_date_is_today
    template = forecast_template('start-date' => '14 May 2009', 'end-date' => '31 May 2009')
    chart = nil
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open', 'closed'])
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)
      card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
      Clock.fake_now(:year => 2009, :month => 5, :day => 14)

      dhc_renderer = Charts::C3Renderers::DailyHistoryChartRenderer.new(nil, nil)
      C3Renderers.expects(:daily_history_chart_renderer).returns(dhc_renderer)

      chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
      Velocity.any_instance.stubs(:invalid?).returns(true)
      chart.expects(:add_hidden_series_to_show_all_x_values).with(dhc_renderer,(Date.parse('14 May 2009')..Date.parse('31 May 2009')).to_a)

      dhc_renderer.expects(:add_legend_key).with('Completion Unknown',Date.parse('31 May 2009').to_epoch_milliseconds, '_$xFor Completion Unknown').once
      chart.generate
    end
  end

  def test_should_not_add_unknown_completion_legend_for_invalid_velocity_and_data_is_not_ready
      template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_property_definitions(:status => ['new', 'open', 'closed'])
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', 'status' => 'open')

        dhc_renderer = Charts::C3Renderers::DailyHistoryChartRenderer.new(nil, nil)
        C3Renderers.expects(:daily_history_chart_renderer).returns(dhc_renderer)

        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
        Velocity.any_instance.stubs(:invalid?).returns(true)
        chart.stubs(:ready?).returns(false)

        dhc_renderer.expects(:add_legend_key).with('Completion Unknown',Date.parse('16 May 2009').to_epoch_milliseconds, '_$xFor Completion Unknown').never
        chart.generate
      end
  end

  def test_should_increase_forecast_chart_width_by_400_px
      template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009', 'chart-width' => nil, 'chart-size' => 'midum')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_property_definitions(:status => ['new', 'open', 'closed'])
        card1 = create_card!(:name => 'in scope 1', 'status' => 'open')

        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)

        chart_data = JSON.parse(chart.generate)
        assert_equal 1000, chart_data['size']['width']
      end
  end

  def test_should_not_increase_forecast_chart_width_when_chart_width_is_specified_in_macro
      template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009', 'chart-width' => 700, 'chart-size' => 'midum')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_property_definitions(:status => ['new', 'open', 'closed'])
        card1 = create_card!(:name => 'in scope 1', 'status' => 'open')

        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card1)
        chart_data = JSON.parse(chart.generate)

        assert_equal 700, chart_data['size']['width']
      end
  end

  def test_should_generate_chart_using_c3_renderer_when_c3_is_enabled
      template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2016', :end_date => 'this card."end date"')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_date_property_definition "unrelated date"
        setup_date_property_definition "end date"
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', :'end date' => Clock.today)

        scanner = StringScanner.new(template)
        scanner.scan_until(Chart::MACRO_SYNTAX)
        parameters = Macro.parse_parameters(scanner[2])
        chart = Macro.create('daily-history-chart', {:project => project,
                                                     :macro_position => 1,
                                                     :view_helper => view_helper,
                                                     :content_provider_project => project,
                                                     :content_provider => card1}, parameters, template)
        DailyHistoryChart.any_instance.stubs(:generate_chart).with(C3Renderers).once
        chart.generate
      end
  end

  def test_should_publish_message_to_dhc_processor_and_set_progress_and_zoom_when_c3_is_enabled
      template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2016', :end_date => 'this card."end date"')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_date_property_definition "unrelated date"
        setup_date_property_definition "end date"
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', :'end date' => Clock.today)

        scanner = StringScanner.new(template)
        scanner.scan_until(Chart::MACRO_SYNTAX)
        parameters = Macro.parse_parameters(scanner[2])
        chart = Macro.create('daily-history-chart', {:project => project,
                                                     :macro_position => 1,
                                                     :view_helper => view_helper,
                                                     :content_provider_project => project,
                                                     :content_provider => card1}, parameters, template)
        DailyHistoryChart.any_instance.stubs(:publish).once

        chart_data = JSON.parse(chart.generate)

        assert_equal 'While Mingle is preparing all the data for this chart.' +
                       ' Revisit this page later to see the complete chart. We calculate data for each day in your date range.' +
                       ' There are 0 days in your date range. We have completed the computation for 0 days so far.', chart_data['message']
      end
  end

  def test_should_not_publish_message_to_dhc_processor_in_preview_mode
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2016', :end_date => 'this card."end date"')
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_date_property_definition "unrelated date"
      setup_date_property_definition "end date"
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)
      card1 = create_card!(:name => 'in scope 1', :'end date' => Clock.today)

      scanner = StringScanner.new(template)
      scanner.scan_until(Chart::MACRO_SYNTAX)
      parameters = Macro.parse_parameters(scanner[2])
      chart = Macro.create('daily-history-chart', {:project => project,
                                                   :preview => true,
                                                   :macro_position => 1,
                                                   :view_helper => view_helper,
                                                   :content_provider_project => project,
                                                   :content_provider => card1}, parameters, template)
      DailyHistoryChart.any_instance.stubs(:publish).never

      chart.generate
    end
  end

  def test_should_not_publish_message_to_dhc_processor_when_c3_is_enabled_and_dhc_data_is_ready
      template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2016', :end_date => 'this card."end date"')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_date_property_definition "unrelated date"
        setup_date_property_definition "end date"
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', :'end date' => Clock.today)

        scanner = StringScanner.new(template)
        scanner.scan_until(Chart::MACRO_SYNTAX)
        parameters = Macro.parse_parameters(scanner[2])
        chart = Macro.create('daily-history-chart', {:project => project,
                                                     :view_helper => view_helper,
                                                     :content_provider_project => project,
                                                     :content_provider => card1}, parameters, template)
        DailyHistoryChart.any_instance.stubs(:ready?).returns(true)
        DailyHistoryChart.any_instance.stubs(:publish).never

        chart_data = JSON.parse(chart.generate)

        assert_nil chart_data['progress']
      end
  end

  def test_should_generate_chart_when_c3_is_enabled_and_content_provider_is_nil_in_preview_mode
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2016', :end_date => '10 Jun 2016')
    project = create_project(:time_zone => 'UTC')
    project.with_active_project do |project|
      setup_date_property_definition 'unrelated date'
      setup_date_property_definition 'end date'
      Clock.fake_now(:year => 2009, :month => 5, :day => 5)

      scanner = StringScanner.new(template)
      scanner.scan_until(Chart::MACRO_SYNTAX)
      parameters = Macro.parse_parameters(scanner[2])
      chart = Macro.create('daily-history-chart', {:project => project,
                                                   :content_provider_project => project,
                                                   :preview => true}, parameters, template)
      DailyHistoryChart.any_instance.stubs(:ready?).returns(true)
      DailyHistoryChart.any_instance.stubs(:publish).never

      chart_data = JSON.parse(chart.generate)

      expected_x_axis_values = ['_$xForAll'] + (Date.parse('2 Jun 2016')..Date.parse('10 Jun 2016')).map(&:to_epoch_milliseconds)

      assert_equal 1, chart_data['data']['columns'].size
      assert_equal expected_x_axis_values, chart_data['data']['columns'].first
    end
  end

  def test_x_values_for_c3_should_include_forecast_dates_individually_when_enabled
      template = forecast_template('start-date' => '8 May 2009', 'end-date' => '16 May 2009')
      project = create_project(:time_zone => 'UTC')
      project.with_active_project do |project|
        setup_property_definitions(:status => ['new', 'open', 'closed'])
        Clock.fake_now(:year => 2009, :month => 5, :day => 5)
        card1 = create_card!(:name => 'in scope 1', 'status' => 'open')
        card2 = create_card!(:name => 'in scope 2', 'status' => 'open')
        card3 = create_card!(:name => 'in scope 3', 'status' => 'open')
        Clock.fake_now(:year => 2009, :month => 5, :day => 10)
        card2.cp_status = 'closed'
        card2.save!
        create_card!(:name => 'in scope 4', 'status' => 'open')
        create_card!(:name => 'in scope 5', 'status' => 'open')
        Clock.fake_now(:year => 2009, :month => 5, :day => 12)
        card3.cp_status = 'closed'
        card3.save!

        Clock.fake_now(:year => 2009, :month => 5, :day => 14)

        scanner = StringScanner.new(template)
        scanner.scan_until(Chart::MACRO_SYNTAX)
        parameters = Macro.parse_parameters(scanner[2])
        chart = Macro.create('daily-history-chart', {:project => project,
                                                     :macro_position => 1,
                                                     :view_helper => view_helper,
                                                     :content_provider_project => project,
                                                     :content_provider => card1}, parameters, template)
        expected_dates = (Date.parse('8 May 2009')..Date.parse('16 May 2009')).to_a + [Date.parse('28 May 2009'),Date.parse('04 Jun 2009'),Date.parse('18 Jun 2009')]
        assert_equal expected_dates, chart.x_axis_values
    end
  end
  private

  def default_template(attrs = {})
    builder = Macro::Builder.parse <<-TEMPLATE
{{
  daily-history-chart
    aggregate: COUNT(*)
    start-date: 14 May 2009
    end-date: 17 May 2009
    series:
    - label: First
}}
TEMPLATE
    if attrs.is_a?(Hash)
      attrs[:start_date] = to_date_string attrs[:start_date] if attrs[:start_date]
      attrs[:end_date] = to_date_string attrs[:end_date] if attrs[:end_date]
    end
    builder.build(attrs)
  end

  def to_date_string(date)
    return if date.blank?
    date.is_a?(String) ? date : date.to_date.strftime("%d %b %Y")
  end

  def forecast_template(attrs={})
    default_template(
      {
        'start-date' => '8 May 2009',
        'end-date' => '16 May 2009',
        'scope-series' => 'Scope',
        'completion-series' => 'Completed',
        'chart-width' => '800',
        'plot-width' => '600',
        'legend-max-width' => '200',
        'series' => [
          {'label' => 'Scope', 'conditions' => 'status > new', 'color' => 'red'},
          {'label' => 'Completed', 'conditions' => 'status = closed', 'color' => 'blue'}
        ]
      }.merge(attrs)
    )
  end

  def x_labels_step_template(x_labels_step)
    builder = Macro::Builder.parse <<-TEMPLATE
{{
  daily-history-chart
    aggregate: COUNT(*)
    start-date: 1 May 2009
    end-date: 15 May 2009
    series:
    - label: First
}}
TEMPLATE
    builder.build('x-labels-step' => x_labels_step)
  end

end
