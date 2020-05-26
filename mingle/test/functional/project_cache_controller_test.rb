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

class ProjectCacheControllerTest < ActionController::TestCase

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = create_controller CardsController, :skip_project_caching => false
    login_as_admin
  end

  def test_loaing_project_in_controller_should_use_cache_on_get
    cached_project = put_first_project_in_cache
    get :list, :project_id => 'first_project'
    assert_object_id_equal cached_project, @controller.project
  end
  
  def test_should_put_cached_project_back_after_used
    cached_project = put_first_project_in_cache
    get :list, :project_id => 'first_project'
    assert_object_id_equal cached_project, ProjectCacheFacade.instance.load_project('first_project')
  end
  
  def test_loaing_project_in_controller_should_not_use_cache_on_post
    cached_project = put_first_project_in_cache
    post 'create', {:project_id => 'first_project', :card => {:name => 'my new card', :card_type => 'Card'}}
    assert_object_id_not_equal cached_project, @controller.project
  end
  
  def test_should_clear_cache_on_non_get_request
    cached_project = put_first_project_in_cache
    post 'create', {:project_id => 'first_project', :card => {:name => 'my new card', :card_type => 'Card'}}
    assert_equal nil, ProjectCacheFacade.instance.load_cached_project('first_project')
  end

  def test_should_not_clear_cache_if_action_declared_skip
    cached_project = put_first_project_in_cache
    post 'preview', {:project_id => 'first_project', :card => {:description => 'h1. haha'}, :properties => {}}
    assert_equal cached_project, ProjectCacheFacade.instance.load_cached_project('first_project')
  end

  def test_should_not_be_able_to_put_cached_project_back_after_clear_cache
    cached_project = put_first_project_in_cache
    post 'create', {:project_id => 'first_project', :card => {:name => 'my new card', :card_type => 'Card'}}
    ProjectCacheFacade.instance.cache_project(cached_project)
    assert_equal nil, ProjectCacheFacade.instance.load_cached_project('first_project')
  end

  def put_first_project_in_cache
    ProjectCacheFacade.instance.load_project_without_cache('first_project').tap do |project|
      ProjectCacheFacade.instance.cache_project(project)
    end
  end
end
