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

class CardNumbersGroupingTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
    
    card_1 = create_card!(:number => 1001, :name => 'card 1', :status => 'new')
    card_1.update_attribute(:cp_status, 'open')
    card_1.update_attribute(:cp_status, 'closed')
    
    card_2 = create_card!(:number => 1002, :name => 'card 2', :status => 'new')
    card_2.update_attribute(:cp_status, 'open')
    card_2.update_attribute(:cp_status, 'new')
    card_2.update_attribute(:cp_status, 'open')
    
    card_3 = create_card!(:number => 1003, :name => 'card 3', :status => 'new')
    card_4 = create_card!(:number => 1004, :name => 'card 4', :status => 'open')
    
  end
  
  def test_should_keep_original_order_if_no_grouping_condition_given
    assert_equal [1001, 1004], CardActivity::CardNumbersGrouping.new([1001, 1004], CardQuery.parse('')).all_numbers
    assert_equal [1001, 1004], CardActivity::CardNumbersGrouping.new([1001, 1004], nil).all_numbers
  end
  
  def test_should_group_numbers_in_current_matching_was_matching_and_never_matching_order
    assert_equal [1002, 1004, 1001, 1003], CardActivity::CardNumbersGrouping.new([1001, 1002, 1003, 1004], CardQuery.parse("Status = open")).all_numbers
    assert_equal [1004, 1002, 1001, 1003], CardActivity::CardNumbersGrouping.new([1004, 1001, 1002, 1003], CardQuery.parse("Status = open")).all_numbers
  end
  
  def test_able_to_sort_activity_details_base_on_numbers_order_grouped
    d1, d2, d3 = *(1001..1003).collect { |i| OpenStruct.new(:number => i) }
    assert_equal [d2, d1, d3], CardActivity::CardNumbersGrouping.new([1001, 1002, 1003, 1004], CardQuery.parse("Status = open")).sort_activity_details([d1, d2, d3])
  end
  
  def test_can_tell_matching_state
    grouping = CardActivity::CardNumbersGrouping.new([1001, 1002, 1003, 1004], CardQuery.parse("Status = open"))
    assert_equal :was_matched, grouping.matching_state_of(1001)
    assert_equal :current_matched, grouping.matching_state_of(1002)
    assert_equal :never_matched, grouping.matching_state_of(1003)
    assert_equal :current_matched, grouping.matching_state_of(1004)
    assert_equal nil, grouping.matching_state_of(1005)
  end
  
  def test_state_is_current_matched_when_grouping_conditions_is_empty
    grouping = CardActivity::CardNumbersGrouping.new([1001, 1002, 1003, 1004], CardQuery.parse(""))
    [1001, 1002, 1003, 1004].each do |number|
      assert_equal :current_matched, grouping.matching_state_of(number)
    end
  end

end
