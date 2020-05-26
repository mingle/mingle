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

class FavoritesViewCacheTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_should_change_cache_path_when_favorite_changed
    favorite = Favorite.create!(:project_id => @project.id, :favorited_type => Page.name, :favorited_id => @project.pages.first.id)    
    original_path = Keys::FavoritesView.new.path_for(@project, true)
    at_time_after :hours => 1 do
      favorite.update_attribute :tab_view, true
      favorite.save!
    end
    changed_path = Keys::FavoritesView.new.path_for(@project.reload, true)
    assert_not_equal original_path, changed_path
  end
  
  # bug 9174
  def test_should_change_cache_path_when_project_id_changes_but_project_identifier_stays_the_same
    first_project = create_project
    first_project_identifier = first_project.identifier
    first_project_cache_path = Keys::FavoritesView.new.path_for(first_project, true)
    first_project.destroy
    
    second_project = create_project(:identifier => first_project_identifier)
    second_project_cache_path = Keys::FavoritesView.new.path_for(second_project, true)
    
    assert_not_equal first_project_cache_path, second_project_cache_path
  end
  
  def test_should_not_change_cache_path_when_project_identifier_changes
    with_new_project do |project|
      original_path = Keys::FavoritesView.new.path_for(project, true)
      project.identifier = 'new_project_identifier'
      project.save!
      new_path = Keys::FavoritesView.new.path_for(project, true)
      assert_equal original_path, new_path
    end
  end
end
