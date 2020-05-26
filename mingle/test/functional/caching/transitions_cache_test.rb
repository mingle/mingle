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

class TransitionsCacheTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_should_change_transition_cache_path_after_tranition_create
    assert_cache_path_changed_after(@project) do
      create_transition(@project, 'close', :set_properties => {:status => 'closed'})
    end
  end
  
  def test_should_change_transition_cache_path_after_tranition_update
    tr = create_transition(@project, 'close', :set_properties => {:status => 'closed'})
    assert_cache_path_changed_after(@project) do
      tr.update_attribute(:name, 'closing')
    end
  end
  
  def test_should_change_transition_cache_path_after_tranition_destroy
    tr = create_transition(@project, 'close', :set_properties => {:status => 'closed'})
    assert_cache_path_changed_after(@project) do
      tr.destroy
    end    
  end
  
  private
  def cache_path(project)
    Keys::Transitions.new.path_for(project)
  end
end
