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

class CardListViewGridSortOrColorByTest < ActiveSupport::TestCase

  def setup
    login_as_member
  end

  def test_serialize_grid_sort_by
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :grid_sort_by => 'status')
      view.name = 'grid sort by status'
      view.save!
      view.reload

      assert_equal({:grid_sort_by => 'status', :action => "list", :style => 'grid', :tab => 'All'}, view.to_params)
    end  
  end
  
  def test_serialize_grid_sort_by_when_grouping_by_a_property
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :grid_sort_by => 'status', :group_by => 'iteration')
      view.name = 'grid sort by status'
      view.save!
      view.reload

      assert_equal({:grid_sort_by => 'status', :action => "list", :style => 'grid', :tab => 'All', :group_by => {:lane => 'iteration'}}, view.to_params)
    end  
  end

  def test_should_remove_color_by_when_it_is_invalid_in_filters
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :color_by => 'prop name not exist')
      assert_nil view.color_by
      assert_equal({:action => "list", :style => 'grid', :tab => 'All'}, view.to_params)
    end  
  end

  def test_should_remove_grid_sort_by_when_it_is_invalid_in_filters
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :grid_sort_by => 'prop name not exist')
      assert_nil view.grid_sort_by
      assert_equal({:action => "list", :style => 'grid', :tab => 'All'}, view.to_params)
    end  
  end

  # postgress will make empty row as last one, but mysql didn't
  def test_should_sort_cards_by_rank_when_select_group_by_and_color_by
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'close'], :old_type => ['bug,story', 'card']
      cards = [
        create_card!(:name => 'card 1', :status => 'close'),
        create_card!(:name => 'card 2', :status => 'new'),
        create_card!(:name => 'card 3'),
        create_card!(:name => 'card 4', :status => 'open')
      ]
      @view = CardListView.find_or_construct(project, {:style => 'grid', :group_by => 'old_type', :color_by => 'status'})
      group_lanes = @view.group_lanes
    
      expected = [cards[0], cards[1], cards[2], cards[3]]
      assert_equal expected.collect(&:number), group_lanes.not_set_lane.cards.collect(&:number)
    end
  end

  def test_should_sort_cards_by_rank_when_only_select_color_by_prop
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'close'], :old_type => ['bug,story', 'card']
      cards = [
        create_card!(:name => 'card 1', :status => 'close'),
        create_card!(:name => 'card 2', :status => 'new'),
        create_card!(:name => 'card 3', :status => 'open')
      ]
      @view = CardListView.find_or_construct(project, {:style => 'grid', :color_by => 'status'})
      group_lanes = @view.group_lanes
    
      expected = [cards[0], cards[1], cards[2]]
      assert_equal expected.collect(&:number), group_lanes.lanes[0].cards.collect(&:number)
    end
  end

  def test_should_sort_cards_by_grid_sort_by_prop_and_not_set_value_should_be_last
    with_first_project do |project|
      project.cards.each(&:destroy)
      cards = [
        create_card!(:name => 'card 1', :iteration => 1),
        create_card!(:name => 'card 2', :iteration => nil),
        create_card!(:name => 'card 3', :iteration => 3)
      ]
      @view = CardListView.find_or_construct(project, {:style => 'grid', :grid_sort_by => 'iteration'})

      expected = [cards[0], cards[2], cards[1]]
      assert_equal expected.collect(&:number), @view.group_lanes.lanes[0].cards.collect(&:number)
    end
  end
  
  def test_should_sort_cards_by_grid_sort_by_prop_and_then_card_number
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'close'], :old_type => ['bug,story', 'card']
      cards = [
        create_card!(:name => 'card 1', :status => 'new'),
        create_card!(:name => 'card 2', :status => 'open'),
        create_card!(:name => 'card 3', :status => 'open'),
        create_card!(:name => 'card 4', :status => 'open')
      ]
      @view = CardListView.find_or_construct(project, {:style => 'grid', :group_by => 'old_type', :grid_sort_by => 'status'})
      group_lanes = @view.group_lanes
      expected = [cards[0], cards[3], cards[2], cards[1]]
      assert_equal expected.collect(&:number), group_lanes.not_set_lane.cards.collect(&:number)
    end
  end

  def test_rename_property_should_update_grid_sort_by
    with_first_project do |project|
      view = project.card_list_views.create_or_update(:view => {:name => 'view 2'}, :style => 'grid', :grid_sort_by => 'status')
      view.rename_property('status', 'new_status')
      assert_equal('new_status', view.grid_sort_by)
    end
  end

  def test_rename_property_should_update_grid_sort_by_when_grouping_by_a_property
    with_first_project do |project|
      view = project.card_list_views.create_or_update(:view => {:name => 'view 2'}, :style => 'grid', :group_by => 'iteration', :grid_sort_by => 'status')
      view.rename_property('status', 'new_status')
      assert_equal('new_status', view.grid_sort_by)
    end
  end

  def test_rename_property_should_update_color_by
    with_first_project do |project|
      view = project.card_list_views.create_or_update(:view => {:name => 'view 2'}, :style => 'grid', :color_by => 'status')
      view.rename_property('status', 'new_status')
      assert_equal('new_status', view.color_by)
    end
  end

  def test_rename_property_should_update_color_by_when_grouping_by_a_property
    with_first_project do |project|
      view = project.card_list_views.create_or_update(:view => {:name => 'view 2'}, :style => 'grid', :group_by => 'iteration', :color_by => 'status')
      view.rename_property('status', 'new_status')
      assert_equal('new_status', view.color_by)
    end
  end

  def test_cards_from_each_lane_should_be_sorted_by_rank_by_default
    with_first_project do |project|
      create_card!(:name => 'new card 1')
      create_card!(:name => 'new card 2')
      create_card!(:name => 'new card 3')
      @view = CardListView.find_or_construct(project, {:style => 'grid', :group_by => 'status'})

      group_lanes = @view.group_lanes
      ordered_cards = project.reload.cards.find(:all, :order => "project_card_rank").collect(&:number)
      assert_equal ordered_cards, group_lanes.not_set_lane.cards.collect(&:number)
    end
  end

  def test_group_by_card_type_should_show_all_card_types_that_has_card_related
    with_new_project do |project|
      create_card!(:name => 'card1')
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => 'type')
      view.visible_lanes

      story_type = project.card_types.create!(:name => 'Story')
      create_card!(:name => 'story1', :card_type => story_type)
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => 'type')
      assert_equal ['Card', 'Story'].sort, view.visible_lanes.sort
    end
  end

end
