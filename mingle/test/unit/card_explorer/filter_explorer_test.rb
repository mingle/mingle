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

class FilterExplorerTest < ActiveSupport::TestCase

  def setup
    @project = create_project
    login_as_member
    @type_story = Project.current.card_types.create :name => 'story'
    @type_iteration = Project.current.card_types.create :name => 'iteration'
    @type_release = Project.current.card_types.create :name => 'release'
    @iteration_tree_config = @project.tree_configurations.create(:name => 'iteration tree')
    @iteration_tree_config.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    @iteration_1 = @iteration_tree_config.add_child(create_card!(:name => 'iteration 1', :card_type => @type_iteration), :to => :root)
  end

  def teardown
    Clock.reset_fake
  end

  def test_cards_can_be_found_using_tree_filter
    story_1 = create_card!(:name => 'my story 1', :card_type => @type_story)
    story_2 = create_card!(:name => 'my story 2', :card_type => @type_story)

    view = create_named_view('foo', @project, :filters => ['[Type][is][Story]'])
    card_explorer = CardExplorer::FilterExplorer.new(@project, @iteration_tree_config, {:page => 1}, view)

    assert_equal ['my story 2', 'my story 1'], card_explorer.cards.collect(&:name)
  end

  def test_cards_from_filter_explorer_should_order_by_desc
    story_1 = create_card!(:name => 'my story 1', :card_type => @type_story)
    story_2 = create_card!(:name => 'my story 2', :card_type => @type_story)
    story_3 = create_card!(:name => 'my story 3', :card_type => @type_story)
    story_4 = create_card!(:name => 'my story 4', :card_type => @type_story)
    story_5 = create_card!(:name => 'my story 5', :card_type => @type_story)
    story_6 = create_card!(:name => 'my story 6', :card_type => @type_story)
    view = create_named_view('foo', @project, :filters => ['[Type][is][Story]'])

    card_explorer = CardExplorer::FilterExplorer.new(@project, @iteration_tree_config, {:page => 1}, view)
    def card_explorer.page_size; 4 end
    assert_equal ['my story 6', 'my story 5', 'my story 4', 'my story 3'], card_explorer.cards.collect(&:name)
    @iteration_tree_config.add_child(story_6, :to => @iteration_1)
    @iteration_tree_config.add_child(story_5, :to => @iteration_1)
    card_explorer = CardExplorer::FilterExplorer.new(@project, @iteration_tree_config, {:page => 1}, view)
    def card_explorer.page_size; 4 end
    assert_equal ['my story 4', 'my story 3', 'my story 2', 'my story 1'], card_explorer.cards.collect(&:name)
  end

  def test_filter_explorer_no_results_message_when_no_cards_exist_in_project
    project_without_cards.with_active_project do |project|
      project.cards.create!(:name => 'a card', :card_type => project.card_types.first)
      tree_config = project.tree_configurations.create(:name => 'a tree')
      card_explorer = CardExplorer::FilterExplorer.new(project, tree_config, {:page => 1}, CardListView.find_or_construct(project, {}))
      assert_equal "Your filter did not match any cards for the current tree.",  card_explorer.no_result_message
    end
  end

end
