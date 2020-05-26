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

class ProjectMacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    login_as_member
  end

  def test_project_macro_can_render_for_non_host_project
    assert_equal_ignoring_spaces "project_without_cards", render("{{ project project: project_without_cards }}", first_project)
  end

  def test_project_macro
    assert_equal_ignoring_spaces "first_project", render("{{ project }}", first_project)
  end

  def test_project_macro_in_edit_mode
    macro_element = Nokogiri::HTML::DocumentFragment.parse(render("{{ project }}", first_project, {}, :formatted_content_editor)).css(".macro").first
    assert_equal "first_project", macro_element.text
    assert_equal URI.escape("{{ project }}"), macro_element["raw_text"]
  end

  def test_project_macro_can_use_plv_for_project_parameter
    with_first_project do |project|
      create_plv!(project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'project_without_cards')
      assert_equal_ignoring_spaces "project_without_cards", render("{{ project project: (my_project) }}", project)
    end
  end
end
