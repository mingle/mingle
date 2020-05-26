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

class WorksHelperTest < ActionController::TestCase
  include WorksHelper, RenderableTestHelper::Unit

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end
  
  def test_done_status_should_be_done_if_matched_the_mapping
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_card_properties(sp_first_project, :number => 1, :status => 'closed')
    assert_equal 'Done', done_status(@plan.works.first, sp_first_project)
  end

  def test_done_status_should_be_not_done_if_not_match
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal 'Not done', done_status(@plan.works.first, sp_first_project)
  end

  def test_done_status_should_be_not_defined_if_mapping_was_not_defined
    @plan.assign_cards(sp_second_project, 1, @program.objectives.first)
    assert_include '&quot;Done&quot; status not defined for project', done_status(@plan.reload.works.first, sp_second_project)
  end

  def test_objective_name_includes_auto_sync_label
    assert_equal content_tag(:span, "(auto sync on)", :class => "auto-sync-message"), auto_sync_message(true)
    assert_equal "", auto_sync_message(false)
  end
  
  def url_for(options)
    FakeViewHelper.new.url_for(options)
  end
end
