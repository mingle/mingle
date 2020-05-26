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

class ProjectCacheFacadeTest < ActiveSupport::TestCase

  def teardown
    ProjectCacheFacade.instance.clear
  end

  def test_load_project_should_not_cache_anything
    project = ProjectCacheFacade.instance.load_project('first_project')
    assert_equal nil, ProjectCacheFacade.instance.load_cached_project('first_project')
  end

  def test_load_project_not_exist
    assert_nil ProjectCacheFacade.instance.load_project('project_x')
  end

  def test_load_project_from_cache
    project = put_first_project_in_cache
    assert_object_id_equal project, ProjectCacheFacade.instance.load_project('first_project')
  end

  def test_should_not_load_project_from_cache_when_request_is_not_get
    project = put_first_project_in_cache
    assert_object_id_not_equal project, ProjectCacheFacade.instance.load_project('first_project', :get_request => false)
  end

  def test_clear_project_cache
    project = put_first_project_in_cache
    ProjectCacheFacade.instance.clear_cache('first_project')
    assert_object_id_not_equal project, ProjectCacheFacade.instance.load_project('first_project')
  end

  def test_should_ignore_old_cached_project_after_cleared_cache
    project = put_first_project_in_cache

    cached_project = ProjectCacheFacade.instance.load_project('first_project')
    ProjectCacheFacade.instance.clear_cache('first_project')
    ProjectCacheFacade.instance.cache_project(project)
    assert_equal nil, ProjectCacheFacade.instance.load_cached_project('first_project')
  end

  def test_changing_user_profile_should_expire_project_cache
    project = put_first_project_in_cache
    User.find_by_login('member').update_attribute(:name, 'chaning my name please')
    assert_object_id_not_equal project, ProjectCacheFacade.instance.load_project('first_project')
  end

  def test_clear_garbage_objects_should_only_clear_all_invalidated_projects_in_cache
    ProjectCacheFacade.instance.start_reaping_invalid_objects(0.05)
    project = put_first_project_in_cache
    assert_equal 1, ProjectCacheFacade.instance.total_count
    # sleep 0.1 second, make sure did once clear_garbage_objects,
    # and valid objects do not get garbage collected
    # we also need make sure there is no cache about keys causing problem
    sleep(0.1)
    assert_equal 1, ProjectCacheFacade.instance.total_count
    ProjectCacheFacade.instance.clear_cache('first_project')
    sleep(0.1)
    assert_equal 0, ProjectCacheFacade.instance.total_count
  end

  def test_setup_project_cache_size_by_system_property
    does_not_work_without_jruby do
      assert_equal 100, ProjectCacheFacade.instance.max_size
      System.setProperty('mingle.projectCacheMaxSize', '5')
      begin
        assert_equal 5, ProjectCacheFacade.instance.max_size
      ensure
        System.clearProperty('mingle.projectCacheMaxSize')
      end
    end
  end

  def put_first_project_in_cache
    ProjectCacheFacade.instance.load_project_without_cache('first_project').tap do |project|
      ProjectCacheFacade.instance.cache_project(project)
    end
  end

end
