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

##################################################################
#                       Filtering tree
#                            |
#                    ----- release1----
#                   |                 |
#            ---iteration1----    iteration2
#           |                |
#       story1            story2
#
##################################################################
class CardListViewTreeExpandingTest < ActiveSupport::TestCase

  def setup
    @project = filtering_tree_project
    @project.activate
    login_as_member
  end

  def test_should_remember_expand_single_node
    release1 = @project.cards.find_by_name('release1')
    view = CardListView.find_or_construct(@project, :style => 'hierarchy', :tree_name => 'filtering tree', :expands => "#{release1.number}")
    assert_equal [release1.number], view.expands
    assert_equal "#{release1.number}", view.to_params[:expands]
  end

  def test_should_remember_expand_nodes
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    view = CardListView.find_or_construct(@project, :style => 'hierarchy', :tree_name => 'filtering tree', :expands => "#{release1.number},#{iteration1.number}")
    assert_equal [release1.number, iteration1.number], view.expands
    assert_equal "#{release1.number},#{iteration1.number}", view.to_params[:expands]
  end

  def test_clear_expands
    release1 = @project.cards.find_by_name('release1')
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :style => 'hierarchy', :tree_name => 'filtering tree', :expands => release1.number.to_s)
    view.clear_expands!
    assert view.expands.empty?
    assert @project.card_list_views.find_by_name('saved view').expands.empty?
  end

  def test_create_or_update_should_reset_expands
     view_with_expands = @project.card_list_views.create_or_update({:view => {:name => "view with expands"}, :style => 'hierarchy', :tree_name => 'filtering tree', :expands => '9'})
     view_with_expands.save!
     new_view = @project.card_list_views.create_or_update({:view => {:name => "view with expands"}, :style => 'hierarchy', :tree_name => 'filtering tree'})
     assert_equal [], new_view.expands
  end

  def test_remove_card_from_tree_then_add_it_back_should_keep_expanded_cards
    release1 = @project.cards.find_by_name('release1')
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :expands => release1.number.to_s)
    tree_config = @project.tree_configurations.find_by_name('filtering tree')
    tree_config.remove_card(release1)
    tree_config.add_card(release1)
    assert_equal [release1.number], view.reload.expands
  end

  private
  def create_view(options={})
    @project.card_list_views.create_or_update({:view => {:name => 'saved view'},:style => 'list', :tree_name => 'filtering tree'}.merge(options))
  end
end
