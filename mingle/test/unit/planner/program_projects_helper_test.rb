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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class ProgramProjectsHelperTest < ActionController::TestCase
  include ProgramProjectsHelper, RenderableTestHelper::Unit

  def setup
    login_as_admin
    @program = create_program
  end

  def test_mapping_status_message
    empty_project = Project.create!(:name => 'Project Without Properties', :identifier => 'project_without_properties')
    plan = @program.plan
    @program.assign(sp_first_project)
    @program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')
    @program.assign(sp_second_project)
    @program.assign(empty_project)

    assert_include "define done status", define_done_message(plan, sp_second_project)
    assert_include "status &gt;= closed", define_done_message(plan, sp_first_project)
    assert_include "define a managed text property in this project", define_done_message(plan, empty_project)
  end

  def test_should_fetch_all_dependencies_for_program
    p1 = Project.create!(:name => "project 1", :identifier => "project_1")
    c1 = p1.cards.create!(:name => 'card 1', :card_type_name => 'card')

    p2 = Project.create!(:name => "project 2", :identifier => "project_2")
    c2 = p2.cards.create!(:name => 'card 2', :card_type_name => 'card')

    p3 = Project.create!(:name => "project 3", :identifier => "project_3")
    c3 = p3.cards.create!(:name => 'card 3', :card_type_name => 'card')

    dep1 = c1.raise_dependency(:name => 'dep1', :desired_end_date => "2012-12-29", :resolving_project_id => p2.id)
    dep1.save!
    dep2 = c2.raise_dependency(:name => 'dep2', :desired_end_date => "2012-12-29", :resolving_project_id => p2.id)
    dep2.save!
    dep3 = c3.raise_dependency(:name => 'dep3', :desired_end_date => '2012-12-29', :resolving_project_id => p2.id)
    dep3.save!
    assert_equal 0, @program.dependencies.length

    @program.assign(p1)
    @program.reload
    assert_equal 1, @program.dependencies.length

    @program.assign(p2)
    @program.reload
    assert_equal 3, @program.dependencies.length
  end

  protected

  def url_for(options)
    FakeViewHelper.new.url_for(options)
  end
end
