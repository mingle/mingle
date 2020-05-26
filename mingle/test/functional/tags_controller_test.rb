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

class TagsControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller TagsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @project = create_project :users => [User.find_by_login('member')]
    login_as_member
  end

  def test_should_not_be_able_to_create_tag_with_comma
    tag_name_contains_comma = 'tag name, contains comma'
    post :create, :project_id => @project.identifier, :tag => {:name => tag_name_contains_comma}
    assert_rollback
    assert_nil @project.tags.find_by_name(tag_name_contains_comma)
  end

  def test_should_not_be_able_to_update_tag_with_comma
    tag = @project.tags.create!(:name => 'some tag')
    tag_name_contains_comma = 'tag name, contains comma'
    post :update, :project_id => @project.identifier, :id => tag.id, :tag => {:name => tag_name_contains_comma}
    assert_rollback
    assert_nil @project.tags.find_by_name(tag_name_contains_comma)
  end

  def test_update_color_by_name
    tag = @project.tags.create!(:name => 'foo')
    post :update_color, :project_id => @project.identifier, :name => tag.name, :color => '#000'
    assert_response :ok
    assert_equal '#000', tag.reload.color
  end

  def should_create_a_tag_on_update_color_if_it_doesnt_exist
    post :update_color, :project_id => @project.identifier, :name => 'eek', :color => '#GGG'
    assert_response :ok
    tag = @project.tags.find_by_name('eek')
    assert_equal '#GGG', tag.color
  end

  def test_create_tag_with_formerly_used_name_works_successfully
    tag = @project.tags.create!(:name => 'rails4eva')
    tag.safe_delete
    post :create, :project_id => @project.identifier, :tag => {:name => 'rails4eva'}
    assert_redirected_to :action => 'list'
    follow_redirect
    assert_select 'td', :text => 'rails4eva'
  end

  def test_create_with_empty_name_should_give_error
    post :create, :project_id => @project.identifier, :tag => {:name => ''}
    assert flash[:error] =~ /Name can't be blank/
    assert_nil flash[:error] =~ /not a valid tag name/
  end

  def test_create_with_duplicate_name_is_invalid
    @project.tags.create!(:name => 'DUPE')
    post :create, :project_id => @project.identifier, :tag => {:name => 'dupe'}
    assert flash[:error] =~ /Name has already been taken/
  end

  def test_should_escape_tag_name_when_list_tags
    name = 'tag <sub>name'
    tag = @project.tags.create!(:name => name)
    get :list, :project_id => @project.identifier
    assert_match(/tag &lt;sub&gt;name/, @response.body)
  end
end
