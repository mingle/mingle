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

require File.expand_path(File.dirname(__FILE__) + '/../functional_test_helper')

class SearchControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller SearchController, :own_rescue_action => true
    login_as_member
    @member = User.find_by_login('member')
    @project = create_project :users => [@member]
    @response   = ActionController::TestResponse.new
  end

  def test_search_return_nothing
    def @controller.index
      @search = Search::Client.new {}
      @result = []
    end

    get :index, :project_id => @project.identifier, :q => "nodata"
    assert_response :success
    assert_template 'index'
    assert_select 'div.result-count', {:count => 1, :text => /No results found/}
  end

  def test_search_return_no_cards
    def @controller.index
      @search = Search::Client.new
      @result = []
    end

    get :index, :project_id => @project.identifier, :q => "nodata", :type => "cards"
    assert_response :success
    assert_template 'index'
    assert_select 'div.result-count', {:count => 1, :text => /No cards found/}
  end

  def test_search_loads_popups
    card = create_card!(:name => 'some card')
    get :request_popup,
        :project_id => @project.identifier, :q => "##{card.number}"
    assert_redirected_to :controller => 'cards',  :action => 'popup_show', :number => card.number, :project_id => @project.identifier

    dependency = card.raise_dependency(:resolving_project_id => @project.id, :desired_end_date => "01/01/2015", :name => "some dependency")
    dependency.save!
    get :request_popup,
        :project_id => @project.identifier, :q => "#D#{dependency.number}"
    assert_redirected_to :controller => 'dependencies',  :action => 'popup_show', :number => dependency.number, :project_id => @project.identifier
  end

  def test_fuzzy_cards_search_for_saas
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      create_card!(:name => 'some card')
      result = {'hits' => {'hits' => [{'_source' => {'number' => 20, 'name' => 'some card', 'card_type_name' => 'story'}}]}}
      ElasticSearch.expects(:search).with({:size => 5000},{
          query: {
              bool: {
                  must: [{match: {name: {query: 'some', fuzziness: 'AUTO'}}}],
                  filter: [{term: {project_id: @project.id}},
                           {term: {type: 'cards'}}]
              }
          },
          _source: %w(number name card_type_name),
          size: 5000
      },@project.search_index_name, 'cards').returns(result)

      get :fuzzy_cards, :project_id => @project.identifier, :term => 'some', :format => 'json'

      assert_response :success
      assert_equal([{value: 20, label: 'some card', type: 'story'}].to_json, @response.body)
    end
  end

  def test_recent_search_for_saas
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      create_card!(:name => 'some card')
      result = {'hits' => {'hits' => [{'_source' => {'number' => 20, 'name' => 'some card', 'card_type_name' => 'story'}}]}}
      ElasticSearch.expects(:search).with({:size => 5000},{
          query: {
              bool: {
                  must: [{match_all: {}}],
                  filter: [{term: {project_id: @project.id}},
                           {term: {type: 'cards'}}]
              }
          },
          _source: %w(number name card_type_name),
          sort: [{timestamp: {order: 'desc'}}, {number: {order: 'desc'}}],
          size: 5000
      },@project.search_index_name, 'cards').returns(result)

      get :recent, :project_id => @project.identifier, :format => 'json'

      assert_response :success
      assert_equal([{value: 20, label: 'some card', type: 'story'}].to_json, @response.body)
    end
  end
end
