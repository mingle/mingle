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

class WorkXmlTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
    view_helper.default_url_options = {:host => 'example.com'}
  end

  def test_to_xml
    project = sp_first_project
    with_sp_first_project do |project|
      objective = create_planned_objective @program, :name => "objective new"
      work = @plan.works.created_from(project).create!(:card_number => 1, :objective => objective, :name => project.cards.first.name)
      work.completed = true
      work_xml = work.to_xml(:compact => true, :view_helper => view_helper, :version => 'v2')

      assert_equal(1.to_s, get_element_text_by_xpath(work_xml, "//card/number"))
      assert_equal(true.to_s, get_element_text_by_xpath(work_xml, "//card/completed"))
      assert_equal(project.identifier, get_element_text_by_xpath(work_xml, "//card/project/identifier"))
      assert_equal("http://example.com/api/v2/projects/#{project.identifier}/cards/1.xml", get_attribute_by_xpath(work_xml, "//card/@url"))
      assert_equal("http://example.com/api/v2/projects/#{project.identifier}.xml", get_attribute_by_xpath(work_xml, "//card/project/@url"))
    end
  end
end
