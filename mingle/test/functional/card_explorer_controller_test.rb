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

class CardExplorerControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller CardExplorerController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
    @member = User.find_by_login('member')
    @project = create_project :users => [@member]           
    
    @type_story = @project.card_types.create :name => 'story'
    @type_release = @project.card_types.create :name => 'release'
    @tree_config = @project.tree_configurations.create!(:name => 'planning tree')
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'}, 
      @type_story => {:position => 1}
    })
  end
  
  def test_card_explorer_search_returning_no_cards_should_show_no_results_message
    get :filter_tree_cards, :project_id => @project.identifier, :tree => @tree_config
    assert_response :success
    assert_select 'div', :text => /There are no cards in this project\./
  end
  
  def test_filter_tree_cards
    create_card!(:name => 'release 1', :card_type => @type_release)
    create_card!(:name => 'release 2', :card_type => @type_release)
    xhr :get, :filter_tree_cards, :project_id => @project.identifier, :tree => @tree_config.id, :filters => ["[Type][is][release]"]
    assert_response :success
    assert @response.body =~ /release 1/
    assert @response.body =~ /release 2/
  end
  
  # bug #9926 (Add card to tree using search has an html escaping issue)
  def test_should_paginate_card_tree_filters
    51.times {|i| create_card!(:name => "release #{i}", :card_type => @type_release) }
    xhr :get, :filter_tree_cards, :project_id => @project.identifier, :tree => @tree_config.id, :filters => ["[Type][is][release]"]
    assert_response :success
    assert_select "#card-explorer-search-result-for-tree", :text => "Showing first 50 results of 51.(Try refining your filter to find your cards)"
  end
  
  def test_should_disable_cards_in_the_tree_when_filter_tree_cards
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    release_2 = create_card!(:name => 'release 2', :card_type => @type_release)
    @tree_config.add_child(release_1, :to => :root)
    get :filter_tree_cards, :project_id => @project.identifier, :tree => @tree_config.id, :filters => ["[Type][is][release]"]
    assert_response :success
    assert_select "li[class~=card-child card-child-candidate][number=#{release_2.number}]"
    assert_select "li[class~=card-child card-child-disabled][number=#{release_1.number}]"
  end
  
  # bug 9126
  def test_should_escape_title_of_cards_in_the_filter_results
    release_1 = create_card!(:name => '<script>hi</script>', :card_type => @type_release)
    release_2 = create_card!(:name => '<script>bye</script>', :card_type => @type_release)
    @tree_config.add_child(release_1, :to => :root)
    get :filter_tree_cards, :project_id => @project.identifier, :tree => @tree_config.id, :filters => ["[Type][is][release]"]
    assert_response :success
    assert_select "li[class~=card-child card-child-candidate][number=#{release_2.number}][title='&lt;script&gt;bye&lt;/script&gt;']"
    assert_select "li[class~=card-child card-child-disabled][number=#{release_1.number}][title='&lt;script&gt;hi&lt;/script&gt;']"
  end
    
end
