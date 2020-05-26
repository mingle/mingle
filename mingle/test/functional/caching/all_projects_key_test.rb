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

class AllProjectsKeyTest < ActionController::TestCase
  include CachingTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_should_change_all_projects_key_after_project_changed
    assert_key_changed_after do
      @project.update_attribute :name, "new name"
    end
  end

  def test_should_change_all_projects_key_after_project_added
    assert_key_changed_after do
      Project.create!(:identifier => "new_created_proj", :name => "created project")
    end
  end

  def test_should_change_all_projects_key_after_project_deleted
    assert_key_changed_after do
      Project.delete(@project.id)
    end
  end

  private

  def key
    KeySegments::AllProjects.new().to_s
  end
end
