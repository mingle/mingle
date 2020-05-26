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


class UserAssignmentTest < ActiveSupport::TestCase
  
  def setup
    @bill = create_user!(:login => 'bill')
  end
  
  def teardown
    reset_license
    super
  end
  
  def test_unassigned_projects_administered_should_not_include_template
    admin = login_as_admin
    template = Project.create!(:name => 'template', :identifier => 'a5', :template => true, :hidden => true)
    assert_false @bill.reload.unassigned_projects_administered_by(admin).include?(template)
  end
  
  def test_unassigned_projects_administered_by
    joe = create_user!(:login => 'joe')

    project1 = create_project
    project1.add_member(joe, :project_admin)

    project2 = create_project
    project2.add_member(joe)

    project3 = create_project
    project3.add_member(joe, :project_admin)
    project3.add_member(@bill)

    project4 = create_project
    project4.add_member(@bill)

    assert_equal [project1], @bill.reload.unassigned_projects_administered_by(joe)
  end
  
  def test_unassigned_projects_administered_by_should_be_smart_sorted
    admin = login_as_admin
    project_names = %w{B a D c}
    project_names.each do |project_name|
      project = Project.create!(:name => project_name, :identifier => project_name.downcase)
    end
    assert_equal %w{a B c D}, @bill.unassigned_projects_administered_by(admin).select{|project| project_names.include?(project.name)}.collect(&:name)
  end
end
