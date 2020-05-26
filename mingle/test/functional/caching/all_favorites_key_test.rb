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

class AllFavoritesKeyTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
    @favorite = Favorite.create!(:project_id => @project.id, :favorited_type => Page.name, :favorited_id => @project.pages.first.id)
  end
  
  def test_should_change_all_favorites_key_after_favorite_changed
    assert_key_changed_after do
      @favorite.update_attribute :tab_view, true
    end
  end
  
  def test_should_change_all_favorites_key_after_add_new_favorite
    assert_key_changed_after do
      Favorite.create!(:project_id => @project.id, :favorited_type => Page.name, :favorited_id => @project.pages.first.id)    
    end
  end
  
  def test_should_not_change_key_after_personal_favorite_added
    assert_key_not_changed_after do
      @project.card_list_views.create_or_update(:view => {:name => 'personal view'}, :style => 'list', :user_id => User.find_by_login('admin').id)
    end
  end
  
  private
  
  def key
    KeySegments::AllFavorites.new(@project.id).to_s
  end
end
