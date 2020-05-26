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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class PropertyEditorHelperTest < ActiveSupport::TestCase
  include PropertyEditorHelper, ApplicationHelper, ActionView::Helpers::JavaScriptHelper, ActionView::Helpers::TagHelper, 
        ActionView::Helpers::FormTagHelper, ActionView::Helpers::TextHelper, ActionView::Helpers::CaptureHelper,TreeFixtures::PlanningTree
  
  def setup
    login_as_member
    @project = first_project
    @project.activate
  end
  
  def test_property_value_for_inline_editor
    assert_equal '', property_value_for_inline_editor(nil)
    assert_equal '', property_value_for_inline_editor('  ')
    assert_equal 'hello', property_value_for_inline_editor('hello')
    assert_equal '(mixed value)', property_value_for_inline_editor('(mixed value)')
    assert_equal '', property_value_for_inline_editor('(mixed value)', true)
  end

  def test_prefilter_fields_for_tree_prop_def
    with_three_level_tree_project do |project|
      release = project.find_property_definition('Planning release')
      iteration = project.find_property_definition('Planning iteration')
      assert_equal [], prefilter_fields(release, 'edit')
      assert_equal [{'parent' => 'Planning release', 'field_id' => "edit_#{release.html_id}_field"}], prefilter_fields(iteration, 'edit')
    end
  end

  def test_should_return_empty_array_for_non_tree_relationship_property
    assert_equal [], prefilter_fields(@project.find_property_definition('status'), 'edit')
  end
end
