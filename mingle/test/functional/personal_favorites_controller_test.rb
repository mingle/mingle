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
class PersonalFavoritesControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller PersonalFavoritesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_create_a_page_favorite
    assert @project.favorites.empty?

    page = @project.pages.first
    post :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name}

    favorite = @project.favorites.reload.first
    assert favorite
    assert_equal page, favorite.favorited
    assert !favorite.tab_view?
    assert_equal User.current.id, favorite.user_id
  end

  def test_should_not_be_able_to_create_personal_favorite_with_same_page_twice
    page = @project.pages.first
    post :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name}
    post :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name}
    assert_equal 1, @project.favorites.reload.size
  end

  def test_should_not_be_able_to_create_a_tab_favorite
    page = @project.pages.first
    post :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name, :tab_view => true}
    favorite = @project.favorites.reload.first
    assert !favorite.tab_view?
  end

  def test_should_not_be_able_to_create_a_favorite_not_owned_by_current_user
    bob = User.find_by_login('bob')
    page = @project.pages.first
    post :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name, :user_id => bob.id}
    favorite = @project.favorites.reload.first
    assert_equal User.current.id, favorite.user_id
  end

  def test_create_a_page_favorite_should_not_be_accessable_for_project_readonly_member
    bob = User.find_by_login('bob')
    @project.add_member(bob, :readonly_member)
    login_as_bob
    page = @project.pages.first
    assert_raise ApplicationController::UserAccessAuthorizationError do 
      post :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name}
    end
  end

  def test_should_do_nothing_when_request_is_get
    page = @project.pages.first
    get :create, :project_id => @project.identifier, :favorite => {:favorited_id => page.id, :favorited_type => page.class.name}
    assert_nil @project.favorites.reload.first
  end
  
  def test_should_be_able_to_remove_members_own_personal_favorite
    page = @project.pages.first
    favorite = @project.favorites.create({:favorited_id => page.id, :favorited_type => page.class.name, :user_id => User.current.id})
    post :destroy, :project_id => @project.identifier, :id => favorite.id
    assert @project.favorites.reload.empty?
    assert flash.now[:notice] =~ /Personal favorite (.*) deleted/
  end
  
  def test_should_not_be_able_to_remove_other_members_favoirte
    page = @project.pages.first
    favorite = @project.favorites.create({:favorited_id => page.id, :favorited_type => page.class.name, :user_id => User.current.id})
    login_as_bob
    assert_raise ApplicationController::UserAccessAuthorizationError do
      post :destroy, :project_id => @project.identifier, :id => favorite.id
    end
  end

  def test_should_not_be_able_to_remove_team_favorite
    page = @project.pages.first
    favorite = @project.favorites.create({:favorited_id => page.id, :favorited_type => page.class.name})
    login_as_bob
    assert_raise ApplicationController::UserAccessAuthorizationError do
      post :destroy, :project_id => @project.identifier, :id => favorite.id
    end
  end

  def test_mingle_admin_could_remove_personal_favorite_as_god
    page = @project.pages.first
    favorite = @project.favorites.create({:favorited_id => page.id, :favorited_type => page.class.name, :user_id => User.current.id})
    login_as_admin
    post :destroy, :project_id => @project.identifier, :id => favorite.id
    assert @project.favorites.reload.empty?
  end
end
