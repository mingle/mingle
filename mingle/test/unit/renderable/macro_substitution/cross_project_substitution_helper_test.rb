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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../renderable_test_helper')

class CrossProjectSubstitutionHelperTest < ActiveSupport::TestCase
  include Renderable::CrossProjectSubstitutionHelper

  def setup
    login_as_admin
  end

  def test_project_identifier_regex_should_include_all_projects
    number_of_projects = Project.count
    assert_equal number_of_projects, project_identifier_regexp.split("|").count
  end

  def test_cached_project_regex_should_not_include_delete_project
    new_project = create_project :skip_activation => true, :identifier => 'soon_to_be_dead'
    assert_include "soon_to_be_dead", project_identifier_regexp.split("|")
    new_project.destroy
    assert_not_include "soon_to_be_dead", project_identifier_regexp.split("|")
  end

  def test_cached_project_regex_should_reflect_renamed_project
    new_project = create_project :skip_activation => true, :identifier => 'project_regex'
    assert_include new_project.identifier, project_identifier_regexp.split("|")
    at_time_after :hours => 1 do
      new_project.update_attributes(:identifier => "regexxxxx")
      assert_include "regexxxxx", project_identifier_regexp.split("|")
      assert_not_include "project_regex", project_identifier_regexp.split("|")
    end
  end

  def test_cached_project_identifier_regex_should_reflect_newly_added_project
    number_of_projects = Project.count
    project_identifier_regexp
    new_project = create_project :skip_activation => true
    identifiers = project_identifier_regexp.split("|")
    assert_equal number_of_projects+1, identifiers.count
    assert_include new_project.identifier, identifiers
  end
end
