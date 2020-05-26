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

require File.expand_path("../../unit_test_helper", File.dirname(__FILE__))


class ColumnInformationCacheKeyTest < ActionController::TestCase
  include CachingTestHelper

  def test_different_projects_should_have_different_column_information_cache_keys
    assert_equal key(first_project), key(first_project)
    assert_not_equal key(first_project), key(project_without_cards)
  end

  def test_column_information_cache_key_should_change_after_structure_change
    with_new_project do |project|
      assert_key_changed_after(project) do
        project.create_any_text_definition!(:name => "completely new", :is_numeric  =>  false)
      end

      assert_key_changed_after(project) do
        project.property_definitions.first.update_attribute :name, "new property def name"
      end

      assert_key_changed_after(project) do
        project.property_definitions.first.destroy
      end
    end
  end

  private

  def key(project)
    KeySegments::ColumnInformation.new(project).to_s(project.cards_table)
  end
end
