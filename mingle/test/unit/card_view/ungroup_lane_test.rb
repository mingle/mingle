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

class UngroupLaneTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = first_project
    @project.activate
    @cards = [create_card!(:name => 'card1'), create_card!(:name => 'card2')]
    @view = OpenStruct.new(:project => @project, :cards => @cards, :to_params => {})
    @grid = CardView::GroupLanes.create(@view, {:color_by => 'status', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'}})
  end

  def test_should_only_have_one_lane_that_contains_all_the_card_in_the_view
    assert_equal(1, @grid.lanes.size)
    assert_equal(1, @grid.visibles(:lane).size)
    lane = @grid.lanes.first
    assert_equal(@cards, lane.cards)
    assert_equal('', lane.title)
    assert_equal('ungrouped', lane.html_id)
    assert(lane.visible)
  end

  def test_to_params
    assert_equal({:color_by => 'status', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'}}, @grid.to_params)
    assert_equal({}, CardView::GroupLanes.create(@view, {}).to_params)
  end

  def test_rename_property
    @grid.rename_property('status', 'st')
    assert_equal({:color_by => 'st', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'}}, @grid.to_params)

    @grid.rename_property('status', 'ddd')
    assert_equal({:color_by => 'st', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'}}, @grid.to_params)
  end

  def test_rename_property_should_be_caseinsentive
    @grid.rename_property('STatuS', 'st')
    assert_equal({:color_by => 'st', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'}}, @grid.to_params)
  end

  def test_lane_aggregate_value_defaults_to_count_of_all_cards
    @view = CardListView.find_or_construct(@project, :style => 'grid')
    group_lanes = CardView::GroupLanes.create(@view, {})
    assert_equal first_project.cards.count.to_s, group_lanes.visibles(:lane).first.aggregate_value
  end

  def test_can_aggregate_by_sum_of_numeric_property
    with_new_project do |project|
      @view = CardListView.find_or_construct(project, :style => 'grid')

      size = setup_numeric_property_definition('size', [1, 2, 3])

      card1 = create_card!(:name => 'card 1')
      card2 = create_card!(:name => 'card 2', :size => 1)
      card3 = create_card!(:name => 'card 3', :size => 2)
      card4 = create_card!(:name => 'card 4', :size => 3)
      card5 = create_card!(:name => 'card 5', :size => 4)

      group_lanes = CardView::GroupLanes.create(@view, {:aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'size'}})

      assert_equal '10', group_lanes.visibles(:lane).first.aggregate_value
    end
  end

  def test_property_definition_uses
    release = @project.find_property_definition('release')
    status = @project.find_property_definition('status')
    assert CardView::GroupLanes.create(@view, {:color_by => 'status'}).uses?(status)
    assert CardView::GroupLanes.create(@view, {:aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'}}).uses?(release)
  end


end
