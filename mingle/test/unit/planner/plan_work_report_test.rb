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

class PlanWorkReportTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = create_program
    @plan = @program.plan
  end
  
  def test_report_data_should_be_smart_sorted_by_project_name
    @program.projects << [create_project(:name => 'foo 10'), create_project(:name => 'foo 1'), create_project(:name => 'foo 2')]
    assert_equal ['foo 1', 'foo 2', 'foo 10'], PlanWorkReport.work_item_counts_by_project(@plan).map{|r| r[:name]}
  end
  
  def test_report_data_should_be_blank_when_no_projects_in_plan
    assert_equal [], PlanWorkReport.work_item_counts_by_project(@plan).map{|r| r[:name]}
  end

  def test_counts_of_work_items_for_each_project
    program = program('simple_program')
    plan = program.plan
    plan.assign_cards(sp_first_project, 1, program.objectives.first)
    plan.assign_cards(sp_first_project, 2, program.objectives.first)
    assert_equal [2, 0], PlanWorkReport.work_item_counts_by_project(plan).map{|r| r[:work_count]}
  end

  def test_project_name_should_be_html_escaped
    @program.projects << create_project(:name => '<h1>hello</h1>')
    assert_equal ['&lt;h1&gt;hello&lt;/h1&gt;'], PlanWorkReport.work_item_counts_by_project(@plan).map{|r| r[:name]}
  end

end
