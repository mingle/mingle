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

# Tags: card_activity
class CardActivityTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def teardown
    Clock.reset_fake
  end

  def test_should_show_card_list_with_passed_in_numbers_order
    assert_equal ['first card', 'another card'], card_activity_names([1, 4])
    assert_equal ['another card', 'first card'], card_activity_names([4, 1])
  end

  def test_should_be_empty_when_there_are_not_cards
    assert card_activity([]).empty?
    assert !card_activity([4, 1]).empty?
  end

  def test_can_group_when_grouping_mql_is_not_blank
    assert_false card_activity([4, 1]).has_grouping?
    assert_false card_activity([4, 1], :grouping_conditions => ' ').has_grouping?
    assert_false card_activity([4, 1], :grouping_conditions => '').has_grouping?
    assert card_activity([4, 1], :grouping_conditions => 'status > fixed').has_grouping?
  end

  def test_should_paginate_when_with_specified_page_size
    with_project_without_cards do |project|
      (1..6).each do |i|
        create_card!(:number => i, :name => "card #{i}")
      end

      card_list = [1,2,3,4,5,6]
      assert_equal ['card 1', 'card 2'], card_activity_names(card_list, {:page_size => "2", :page => '1'}, project)
      assert_equal ['card 3', 'card 4'], card_activity_names(card_list, {:page_size => '2', :page => '2'}, project)
      assert_equal ['card 5', 'card 6'], card_activity_names(card_list, {:page_size => '2', :page => '3'}, project)
    end
  end

  def test_validate_page_size
    assert_equal ["Invalid page size"], card_activity([1, 4], {:page_size => "-1"}).validation_errors
    assert_equal ["Invalid page size"], card_activity([1, 4], {:page_size => "0"}).validation_errors
    assert_equal ["Invalid page size"], card_activity([1, 4], {:page_size => "abc"}).validation_errors
    assert_equal ["Page size cannot exceed 1000"], card_activity([1, 4], {:page_size => "1001"}).validation_errors
    assert_equal [], card_activity([1, 4], {:page_size => "1000"}).validation_errors
    assert_equal [], card_activity([1, 4], {:page_size => ""}).validation_errors
  end

  def test_validation_for_general_mql_errors_against_grouping_conditions
    assert_equal ["Invalid grouping condition: Card property '#{'st'.bold}' does not exist!"],
                 card_activity([1, 4], {:grouping_conditions => "st = tt"}).validation_errors
    assert_equal ["Invalid grouping condition: unexpected characters $#%# "],
                  card_activity([1, 4], {:grouping_conditions => "$#%#"}).validation_errors
    assert_equal ["Invalid grouping condition: #{'notexist'.bold} is not a valid value for #{'Type'.bold}, which is restricted to #{'Card'.bold}"],
                  card_activity([1, 4], {:grouping_conditions => "type = notexist"}).validation_errors
  end

  def test_validation_for_grouping_condition_mql_contains_not_supported_parts
    assert_equal ["Invalid grouping condition: use of #{'GROUP BY'.bold} and #{'ORDER BY'.bold} are invalid. Enter MQL conditions only."],
                card_activity([1, 4], {:grouping_conditions => "type = card group by type order by type"}).validation_errors
    assert_equal ["Invalid grouping condition: use of #{'SELECT'.bold} is invalid. Enter MQL conditions only."],
                 card_activity([1, 4], {:grouping_conditions => "SELECT NAME WHERE Status = New"}).validation_errors
  end

  def test_validation_for_grouping_condition_mql_contains_using_this_card
    with_card_query_project do |project|
      assert_equal ["Invalid grouping condition: use of #{'THIS CARD'.bold} is not supported."],
                  card_activity([1, 4], {:grouping_conditions => "'related card' = THIS CARD"}, project).validation_errors

      assert_equal ["Invalid grouping condition: use of #{'THIS CARD.\'related card\''.bold} is not supported."],
                  card_activity([1, 4], {:grouping_conditions => "'related card' = THIS CARD.'related card'"}, project).validation_errors
    end
  end

  def test_validation_for_grouping_condition_contains_aggregate_property
    with_three_level_tree_project do |project|
      assert_equal ["Invalid grouping condition: Cannot use Aggregate Property #{'Sum of size'.bold} in query against historical data"],
                  card_activity([1, 4], {:grouping_conditions => "'Sum of size' > 5"}, project).validation_errors
    end
  end

  def test_should_not_allow_grouping_with_from_tree
    with_three_level_tree_project do
      assert_equal ["Invalid grouping condition: Cannot use #{'FROM TREE'.bold} in query against historical data"], card_activity([1, 4], {:grouping_conditions => "FROM TREE 'three level tree'"}).validation_errors
    end
  end

  def test_should_not_allow_grouping_with_tagged_with
    assert_equal ["Invalid grouping condition: Cannot use #{'TAGGED WITH'.bold} in query against historical data"], card_activity([1, 4], {:grouping_conditions => "TAGGED WITH tag1"}).validation_errors
  end

  def test_should_show_first_page_if_page_is_not_specified
    assert_equal ['first card'], card_activity_names([1, 4], :page_size => '1')
    assert_equal ['first card'], card_activity_names([1, 4], :page_size => '1', :page => '')
  end

  def test_should_default_to_25_per_page
    #we reach in to paginator to avoid creating lots of cards to test this
    assert_equal(25, card_activity([1]).paginator.limit_and_offset[:limit])
    assert_equal(25, card_activity([1], {:page_size => ''}).paginator.limit_and_offset[:limit])
  end

  def test_should_last_met_time_for_card_met_grouping_mql_condition_is_nil_if_there_is_no_mql_condition
    assert_equal [nil, nil],  card_activity_met_times([1, 4])
    assert_equal [nil, nil],  card_activity_out_of_met_times([1, 4])
  end

  def test_should_show_last_met_time_for_card_met_grouping_mql_condition
    card_1, card_4 = @project.cards.sort_by(&:number)
    update_time = Time.parse('2007-01-30 12:22:26').utc

    Clock.now_is(update_time) { card_1.update_attribute :cp_status, 'fixed' }
    Clock.now_is(update_time) { card_4.update_attribute :cp_status, 'closed' }

    assert_equal [strip_usec(update_time), nil],  card_activity_met_times([1, 4], :grouping_conditions => "Status = 'Fixed'")
    assert_equal [nil, nil],  card_activity_out_of_met_times([1, 4], :grouping_conditions => "Status = 'Fixed'")
  end

  def test_should_show_last_met_time_sorted_by_matching_grouping_conditions_ahead_of_card_numbers
    card_1, card_4 = @project.cards.sort_by(&:number)
    update_time = card_1.updated_at + 1.day

    Clock.now_is(update_time) { card_1.update_attribute :cp_status, 'fixed' }
    Clock.now_is(update_time) { card_4.update_attribute :cp_status, 'closed' }

    assert_equal ['first card', 'another card'],  card_activity_names([4, 1], :grouping_conditions => "Status = 'Fixed'")
  end

  def test_should_keep_passing_in_order_for_activities_all_matching_grouping_conditions
    card_1, card_4 = @project.cards.sort_by(&:number)

    card_1_update_time = Time.parse('2007-01-30 12:22:26').utc
    card_4_update_time = Time.parse('2007-01-30 12:22:26').utc

    Clock.now_is(card_1_update_time) { card_1.update_attribute :cp_status, 'fixed' }
    Clock.now_is(card_4_update_time) { card_4.update_attribute :cp_status, 'fixed' }

    assert_equal [strip_usec(card_4_update_time), strip_usec(card_1_update_time)],  card_activity_met_times([4, 1], :grouping_conditions => "Status = 'Fixed'")
    assert_equal [nil, nil],  card_activity_out_of_met_times([4, 1], :grouping_conditions => "Status = 'Fixed'")
  end

  def test_matched_details_always_be_paginated_ahead_of_unmatched
    card_1, card_4 = @project.cards.sort_by(&:number)
    card_2 = @project.cards.create! :name => 'MATCHED', :number => 2, :card_type_name => 'card', :cp_status => 'fixed'

    assert_equal ['MATCHED', 'first card'], card_activity_names([1, 4, 2], :grouping_conditions => "Status = 'Fixed'", :page_size => 2, :page => '1')
    assert_equal ['another card'], card_activity_names([1, 4, 2], :grouping_conditions => "Status = 'Fixed'", :page_size => 2, :page => '2')
  end

  def test_pagination_through_big_chunk_of_numbers
    assert_equal 2, card_activity((1..10000).to_a, :grouping_conditions => "Status = Fixed", :page_size => 5000, :page => '1').pages.size
  end

  def test_should_show_last_met_time_even_when_card_no_longer_matching
    card_1 = @project.cards.sort_by(&:number).first

    first_update_time = Time.parse('2007-01-30 12:22:26').utc
    second_update_time = Time.parse('2007-01-31 12:22:26').utc

    Clock.now_is(first_update_time) { card_1.update_attribute :cp_status, 'fixed' }
    Clock.now_is(second_update_time) { card_1.update_attribute :cp_status, 'open' }

    assert_equal [strip_usec(first_update_time)], card_activity_met_times([1], :grouping_conditions => "Status = 'Fixed'")
    assert_equal [strip_usec(second_update_time)], card_activity_out_of_met_times([1], :grouping_conditions => "Status = 'Fixed'")
  end

  def test_last_met_time_should_be_time_that_card_last_entered_the_state_when_continued_to_match
    card_1 = @project.cards.sort_by(&:number).first

    first_update_time = Time.parse('2007-01-30 12:22:26').utc
    second_update_time = Time.parse('2007-01-31 12:22:26').utc

    Clock.now_is(first_update_time) { card_1.update_attribute :cp_status, 'fixed' }
    Clock.now_is(second_update_time) { card_1.update_attribute :cp_status, 'closed' }

    assert_equal [strip_usec(first_update_time)], card_activity_met_times([1], :grouping_conditions => "Status >= 'Fixed'")
    assert_equal [nil], card_activity_out_of_met_times([1], :grouping_conditions => "Status >= 'Fixed'")
  end

  def test_last_met_time_should_be_time_that_card_last_entered_the_state_even_when_no_longer_matches
    card_1 = @project.cards.sort_by(&:number).first

    first_update_time = Time.parse("2015-01-30 12:00:00").utc + 1.day
    second_update_time = Time.parse("2015-01-30 12:00:00").utc + 2.day
    third_update_time = Time.parse("2015-01-30 12:00:00").utc + 3.day
    fourth_update_time = Time.parse("2015-01-30 12:00:00").utc + 4.day

    Clock.now_is(first_update_time) { card_1.update_attribute :cp_status, 'open' }
    Clock.now_is(second_update_time) { card_1.update_attribute :cp_status, 'new' }
    Clock.now_is(third_update_time) { card_1.update_attribute :cp_status, 'open' }
    Clock.now_is(fourth_update_time) { card_1.update_attribute :cp_status, 'closed' }

    assert_equal [strip_usec(third_update_time)], card_activity_met_times([1], :grouping_conditions => "Status = 'Open'")
    assert_equal [strip_usec(fourth_update_time)], card_activity_out_of_met_times([1], :grouping_conditions => "Status = 'Open'")
  end

  def test_out_of_met_time_should_be_nil_when_stauts_current_match
    card_1 = @project.cards.sort_by(&:number).first

    first_update_time = Time.parse("2015-01-30 12:00:00").utc + 1.day
    second_update_time = Time.parse("2015-01-30 12:00:00").utc + 2.day
    third_update_time = Time.parse("2015-01-30 12:00:00").utc + 3.day

    Clock.now_is(first_update_time) { card_1.update_attribute :cp_status, 'open' }
    Clock.now_is(second_update_time) { card_1.update_attribute :cp_status, 'new' }
    Clock.now_is(third_update_time) { card_1.update_attribute :cp_status, 'open' }

    assert_equal [nil], card_activity_out_of_met_times([1], :grouping_conditions => "Status = 'Open'")
  end

  def test_pagination_orders_for_cards_no_longer_matching_grouping_conditions

    card_1, card_4 = @project.cards.sort_by(&:number)
    card_2 = @project.cards.create! :name => 'card 2', :number => 2, :card_type_name => 'card', :cp_status => 'nil'
    card_2.update_attributes(:cp_status => 'new')
    card_2.update_attributes(:cp_status => 'open')
    card_2.update_attributes(:cp_status => 'closed')
    card_2.update_attributes(:cp_status => 'open')

    assert_equal ['card 2', 'first card'], card_activity_names([1, 4, 2], :grouping_conditions => "Status = 'Closed'", :page_size => 2, :page => '1')
    assert_equal ['another card'], card_activity_names([1, 4, 2], :grouping_conditions => "Status = 'Closed'", :page_size => 2, :page => '2')
  end

  def test_details_should_ordered_by_last_entered_and_current_state
    card_1 = create_card!(:name => 'card 1', :status => 'new')
    card_1.update_attribute(:cp_status, 'open')
    card_1.update_attribute(:cp_status, 'closed')

    card_2 = create_card!(:name => 'card 2', :status => 'new')
    card_2.update_attribute(:cp_status, 'open')
    card_2.update_attribute(:cp_status, 'new')
    card_2.update_attribute(:cp_status, 'open')

    card_3 = create_card!(:name => 'card 3', :status => 'new')

    assert_equal ['card 2', 'card 1', 'card 3'], card_activity_names([card_1, card_2, card_3].collect(&:number), :grouping_conditions => "Status = open")
  end

  def test_activity_current_matching_group_condition_should_be_paginated_ahead_of_not_currently_matching
    card_1 = create_card!(:name => 'card 1', :status => 'new')
    card_1.update_attribute(:cp_status, 'open')
    card_1.update_attribute(:cp_status, 'closed')

    card_2 = create_card!(:name => 'card 2', :status => 'new')
    card_2.update_attribute(:cp_status, 'open')
    card_2.update_attribute(:cp_status, 'new')
    card_2.update_attribute(:cp_status, 'open')

    card_3 = create_card!(:name => 'card 3', :status => 'new')
    card_4 = create_card!(:name => 'card 4', :status => 'open')

    card_numbers = [card_1, card_2, card_3, card_4].collect(&:number)
    assert_equal ['card 2', 'card 4'], card_activity_names(card_numbers, :grouping_conditions => "Status = open", :page_size => 2, :page => 1)
    assert_equal ['card 1', 'card 3'], card_activity_names(card_numbers, :grouping_conditions => "Status = open", :page_size => 2, :page => 2)

    card_numbers = [card_4, card_3, card_2, card_1].collect(&:number)
    assert_equal ['card 4', 'card 2'], card_activity_names(card_numbers, :grouping_conditions => "Status = open", :page_size => 2, :page => 1)
    assert_equal ['card 1', 'card 3'], card_activity_names(card_numbers, :grouping_conditions => "Status = open", :page_size => 2, :page => 2)
  end

  def test_can_tell_whether_an_activity_detail_currently_matching_grouping_conditions
    card_1 = create_card!(:name => 'card 1', :status => 'new')
    card_1.update_attribute(:cp_status, 'open')
    card_1.update_attribute(:cp_status, 'closed')

    card_2 = create_card!(:name => 'card 2', :status => 'new')
    card_2.update_attribute(:cp_status, 'open')
    card_2.update_attribute(:cp_status, 'new')
    card_2.update_attribute(:cp_status, 'open')

    card_3 = create_card!(:name => 'card 3', :status => 'new')
    card_4 = create_card!(:name => 'card 4', :status => 'open')

    card_numbers = [card_1, card_2, card_3, card_4].collect(&:number)
    assert_equal ['card 2', 'card 4', 'card 1', 'card 3'], card_activity_names(card_numbers, :grouping_conditions => "Status = open")
    assert_equal [:current_matched, :current_matched, :was_matched, :never_matched], card_activity(card_numbers, :grouping_conditions => "Status = open").details.collect(&:matching_state)
  end

  def test_matching_to_grouping_condition_statue_is_always_current_matched_if_no_grouping_condition
    assert_equal [:current_matched], card_activity(@project.cards.collect(&:number)).details.collect(&:matching_state).uniq
  end

  private
  def card_activity(card_number_string, options={}, project=@project)
    CardActivity.new(project, card_number_string, options)
  end

  def card_activity_names(card_number_string, options={}, project=@project)
    card_activity(card_number_string, options, project).details.collect(&:name)
  end

  def card_activity_met_times(card_number_string, options={}, project=@project)
    card_activity(card_number_string, options, project).details.collect(&:last_met_time)
  end

  def card_activity_out_of_met_times(card_number_string, options={}, project=@project)
    card_activity(card_number_string, options, project).details.collect(&:last_out_of_met_time)
  end


  def strip_usec(time)
    Time.at(time.to_i).utc
  end
end
