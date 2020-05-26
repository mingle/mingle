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
class PagesHelperTest < ActiveSupport::TestCase
  include PagesHelper
  
  def setup
    login_as_member
    @project = first_project
    @project.activate
  end
  
  def test_is_a_team_favorite_or_tab_should_only_indicate_that_a_page_is_a_team_favorite_or_tab
    favorite_page = @project.pages.create!(:name => 'test page')
    not_favorite_page = @project.pages.create!(:name => 'test page two')
    personal_favorite_page = @project.pages.create!(:name => 'personal page two')
    @project.favorites.of_pages.create!(:favorited => favorite_page)
    @project.favorites.of_pages.personal(User.current).create!(:favorited => personal_favorite_page)

    assert is_a_team_favorite_or_tab(favorite_page)
    assert !is_a_team_favorite_or_tab(not_favorite_page)
    assert !is_a_team_favorite_or_tab(personal_favorite_page)
  end
  
  def test_is_a_tab_should_indicate_that_a_page_is_a_tab
    tab_page = @project.pages.create!(:name => 'test page')
    non_tab_page = @project.pages.create!(:name => 'test page two')
    missing_view_page = @project.pages.create!(:name => 'test page three')
    
    @project.tabs.of_pages.create!(:favorited => tab_page)
    @project.favorites.of_pages.create!(:favorited => non_tab_page)
    
    assert is_a_tab(tab_page)
    assert !is_a_tab(non_tab_page)
    assert !is_a_tab(missing_view_page)
  end
  
  def test_admin_user_or_not_a_tab_should_be_true_when_no_favorite_exists
    @page = @project.pages.create!(:name => 'mike')
    assert admin_user_or_not_a_tab?
  end

  def test_admin_user_or_not_a_tab_should_be_true_when_only_personal_favorite_exists
    @page = @project.pages.create!(:name => 'mike')
    @project.favorites.of_pages.personal(User.current).create!(:favorited => @page)
    assert admin_user_or_not_a_tab?
  end
  
  def test_admin_user_or_not_a_tab_should_be_true_user_is_either_mingle_admin_or_project_admin
    login_as_proj_admin
    assert admin_user_or_not_a_tab?
    login_as_admin
    assert admin_user_or_not_a_tab?
  end

  def test_personal_page_should_be_false_when_page_is_nil
    assert_false personal_page?(nil)
  end
  def test_personal_page_should_be_false_when_page_is_not_a_favorite
    @page = @project.pages.first
    assert_false personal_page?(@page)
  end
  def test_personal_page_should_be_false_when_page_is_a_team_favorite
    @page = @project.pages.first
    @project.favorites.create!(:favorited => @page)
    assert_false personal_page?(@page)
  end
  def test_personal_page_should_be_false_when_page_is_not_current_user_personal_favorite
    @page = @project.pages.first
    @project.favorites.personal(User.find_by_login('admin')).create!(:favorited => @page)
    assert_false personal_page?(@page)
  end
  def test_personal_page_should_be_true_when_page_is_current_user_personal_favorite
    @page = @project.pages.first
    @project.favorites.personal(User.current).create!(:favorited => @page)
    assert personal_page?(@page)
  end
end
