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

class FeedUrlCacheTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    login_as_member
    @project = first_project
    @project.activate
  end
  
  def test_update_project_secret_key_flushes_cache
    assert_cache_path_changed_after(@project) do
      @project.generate_secret_key
      @project.save!
    end
  end
  
  def test_should_generate_different_path_for_different_user
    assert_cache_path_changed_after(@project) do
      login_as_admin
    end
    
    assert_cache_path_changed_after(@project) do
      logout_as_nil
    end
  end
  
  private
  def cache_path(project, request_params="filter1=f")
    Keys::FeedUrl.new.path_for(project, request_params)
  end
end
