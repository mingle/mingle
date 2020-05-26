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

#Tags: favorites
class FavoritesControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller FavoritesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @project = first_project
    @project.activate
    login_as_admin
  end

  def test_creating_tabs_sets_session_state_of_any_other_view_empty
    view = CardListView.construct_from_params(@project, :tagged_with => 'type-story,status-open')
    view.name = 'open stories'
    view.save!

    get :list, :project_id => @project.identifier

    card_context.store_tab_state(view, DisplayTabs::AllTab::NAME, CardContext::NO_TREE)
    post :move_to_tab, :project_id => @project.identifier, :id => view.favorite.id

    assert view.reload.tab_view?
    assert card_context.empty?

    post :move_to_team_favorite, :project_id => @project.identifier, :id => view.favorite.id
    assert !view.reload.tab_view?
    assert card_context.empty?
  end
0
  def test_move_to_team_favorite_removes_view_from_tabbed_views_and_moves_to_favorites_section
    view = CardListView.construct_from_params(@project, :tagged_with => 'mike')
    view.name = 'Mike'
    view.save!

    view.tab_view = true
    view.save!

    post :move_to_team_favorite, :project_id => @project.identifier, :id => view.favorite.id
    assert view.reload.favorite
    assert !view.tab_view?
  end

  def test_move_to_tab_removes_view_from_favorites_section_and_moves_to_tabbed_views
    view = CardListView.construct_from_params(@project, :tagged_with => 'mike')
    view.name = 'Mike'
    view.save!

    post :move_to_tab, :project_id => @project.identifier, :id => view.favorite.id
    assert !view.reload.favorite.favorite?
    assert view.tab_view?
  end

  def test_remove_tab_removes_wiki_view_from_tabbed_views
    page = @project.pages.create!(:name => 'some page')
    favorite = @project.tabs.create!(:favorited => page)

    post :remove_tab, :project_id => @project.identifier, :id => favorite.id

    assert_record_deleted favorite
  end

  def test_remove_team_favorite_removes_wiki_view_from_favorites
    page = @project.pages.create!(:name => 'some page')
    favorite = @project.favorites.create!(:favorited => page)

    post :remove_team_favorite, :project_id => @project.identifier, :id => favorite.id

    assert_record_deleted favorite
  end

  def test_delete_view_deletes_both_view_and_favorite
    view = @project.card_list_views.create_or_update(:view => {:name => 'mike stuff'}, :tagged_with => 'mike')
    view.name = 'Mike'
    view.save!

    post :delete, :project_id => @project.identifier, :id => view.favorite.id

    @project.reload

    assert_record_deleted view.favorite
    assert_record_deleted view
  end

  def test_manage_favorites_and_tabs_should_render_list_tempalte
    get :manage_favorites_and_tabs, :project_id => @project.identifier
    assert_template 'list'
  end

  def test_manage_favorites_and_tabs_should_not_show_personal_favorites
    view = @project.card_list_views.create_or_update(:view => {:name => 'Personal'}, :style => 'list', :user_id => User.current.id)
    get :manage_favorites_and_tabs, :project_id => @project.identifier
    assert_select "#card_list_view_#{view.id}", :count => 0
  end

  def test_show_should_redirect_to_page_show_when_favorited_is_a_page
    fav = @project.favorites.create(:favorited => @project.pages.first)
    get :show, :project_id => @project.identifier, :id => fav.id
    assert_redirected_to :project_id => @project.identifier, :controller => :pages, :page_identifier => @project.pages.first.identifier
  end

  def test_show_should_redirect_to_card_list_when_favorited_is_a_card_list_view
    view = @project.card_list_views.create_or_update(:view => {:name => 'a view'}, :style => 'grid', :group_by => 'status')
    get :show, :project_id => @project.identifier, :id => view.favorite.id
    assert_redirected_to :project_id => @project.identifier, :controller => :cards, :action => 'index', :view => 'a view'
  end

  def test_show_should_redirect_to_card_list_with_details_when_favorited_is_a_card_list_view_and_personal
    view = @project.card_list_views.create_or_update(:view => {:name => 'a view'}, :style => 'grid', :group_by => 'status')
    view.favorite.user_id = User.current.id
    view.favorite.save
    get :show, :project_id => @project.identifier, :id => view.favorite.id
    assert_redirected_to :project_id => @project.identifier, :controller => :cards, :action => 'list', :style => 'grid', :group_by => {'lane' => 'status'}
  end

  def test_show_should_redirect_to_favorite_page_show_even_when_favorite_is_a_tab
    fav = @project.favorites.create(:favorited => @project.pages.first, :tab_view => true)
    get :show, :project_id => @project.identifier, :id => fav.id
    assert_redirected_to :project_id => @project.identifier, :controller => :pages, :page_identifier => @project.pages.first.identifier
  end

  def test_should_rename_the_selected_favorite
    view = @project.card_list_views.create_or_update(:view => {:name => 'a view'}, :style => 'grid', :group_by => 'status')
    favorite = @project.favorites.create(:favorited => view)
    put :rename, :project_id => @project.identifier, :id => favorite.id, :new_name => 'my view'
    assert_response :success

    @project.reload
    assert_equal 'my view', @project.favorites_and_tabs.find(favorite.id).favorited.name
  end

  def test_non_admins_should_be_able_to_rename_favorite
    view = @project.card_list_views.create_or_update(:view => {:name => 'a view'}, :style => 'grid', :group_by => 'status')
    favorite = @project.favorites.create(:favorited => view)
    login_as_bob
    put :rename, :project_id => @project.identifier, :id => favorite.id, :new_name => 'my view'
    assert_response :success

    @project.reload
    assert_equal 'my view', @project.favorites_and_tabs.find(favorite.id).favorited.name
  end

  def test_rename_should_return_error_messages_when_validations_fail
    view = @project.card_list_views.create_or_update(:view => {:name => 'a view'}, :style => 'grid', :group_by => 'status')
    favorite = @project.favorites.create(:favorited => view)
    login_as_bob
    put :rename, :project_id => @project.identifier, :id => favorite.id, :new_name => '    '
    assert_response :unprocessable_entity, 'Expected unprocessable entity'
    assert_equal 'Name can\'t be blank', @response.body
  end

  private

  def create_card_view(name, tags)
    view = CardListView.construct_from_params(@project, :tagged_with => tags)
    view.name = name
    view.save!
    view
  end
end
