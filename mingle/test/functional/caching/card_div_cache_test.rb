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

class CardDivCacheTest < ActiveSupport::TestCase
    include CachingTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
    @card = create_card!(:name => 'for card div cache test')
    @card.extend(CardView::GridViewCards::HavingChildren)
    @view = CardListView.find_or_construct(@project, :style => 'grid', :color_by => 'status')
  end

  def test_key_should_change_after_card_name_change
    assert_cache_path_changed_after(@card, @view) do
      @card.update_attributes(:name => 'foo')
    end
  end

  def test_key_should_change_if_add_a_property
    assert_cache_path_changed_after(@card, @view) do
      assert @project.find_enumeration_value('status', 'open').update_attributes('color' => 'red')
    end
  end

  def test_key_should_change_if_user_change_icon
    assert_cache_path_changed_after(@card, @view) do
      assert User.first_admin.update_attributes(:icon => sample_attachment('icon.png'))
    end
  end

  def test_key_should_change_if_view_style_changed
    assert_equal cache_path(@card, @view), cache_path(@card, CardListView.reload(@view))
    assert_not_equal cache_path(@card, @view), cache_path(@card, CardListView.find_or_construct(@project, @view.to_params.merge(:color_by => 'Type')))
  end

  def test_key_should_change_if_dependencies_changed
    assert_cache_path_changed_after(@card, @view) do
      @card.raise_dependency(:number => 1, :desired_end_date => Date.parse('2017-05-09'), :resolving_project_id => @project.id, :name => 'dep1').save!
    end
  end

  def test_key_should_change_if_anscestors_change
    assert_cache_path_changed_after(@card, @view) do
      @card.ancestors ||= []
      @card.ancestors += [1,2,3,4]
    end
  end

  def test_key_should_change_if_sort_position_changes
    assert_cache_path_changed_after(@card, @view) do
      @card.project_card_rank += 500000.0
    end
  end

    def test_key_should_change_if_view_params_change
      with_new_project do |project|
        estimate = setup_numeric_property_definition('estimate', [1,4,8])
        type_story = project.card_types.create(:name => "Story")
        type_card = project.card_types.find_by_name("card")
        estimate.card_types = [type_card, type_story]
        estimate.save!

        card1 = create_card!(:name => 'card1', :estimate => 1, :type => 'story')
        create_card!(:name => 'card2', :estimate => 8, :type => 'card')

        @view = CardListView.find_or_construct(project, :style => 'grid', :group_by => 'type')
      assert_equal cache_path(@card, @view), cache_path(@card, CardListView.reload(@view))
      assert_not_equal cache_path(@card, @view), cache_path(@card, CardListView.find_or_construct(project, @view.to_params.merge(:style => 'grid', :aggregate_type => 'SUM', :aggregate_property => 'estimate')))
      card1.update_properties(:estimate => 8)
      assert_not_equal cache_path(@card, @view), cache_path(@card, CardListView.find_or_construct(project, @view.to_params.merge(:style => 'grid', :aggregate_type => 'SUM', :aggregate_property => 'estimate')))
      end
    end

  def cache_path(card, view)
    Keys::CardDivCache.new.path_for(card, view)
  end

end
