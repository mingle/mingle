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

class CardTypeDefinitionTest < ActiveSupport::TestCase

  def setup
    @project = create_project
  end

  def test_create_value_if_not_exist
    @project.card_type_definition.create_value_if_not_exist('story')
    assert story_type = @project.card_types.find_by_name('story')

    @project.card_type_definition.create_value_if_not_exist('story')
    assert_equal story_type, @project.card_types.find_by_name('story')
  end

  #bug 5594
  def test_comparison_value
    card_type_name = 'story with    space'
    @project.card_type_definition.create_value_if_not_exist(card_type_name)
    assert_equal 2, @project.card_type_definition.comparison_value(card_type_name)
  end

  def test_support_filter_always_returns_false
    assert_equal false, @project.card_type_definition.support_filter?
  end

  def test_lane_values_returns_name_and_name
    assert_equal [["Card", "Card"]], @project.card_type_definition.lane_values
  end

  def test_rename_value_updates_existing_value
    @project.card_types.create :name => 'story'
    @project.card_types.create :name => 'bug'

    renamed_value = @project.card_type_definition.rename_value('story', 'tale')
    assert renamed_value.errors.none?
    card_type_names = @project.reload.card_type_definition.values.map(&:name)
    assert_include "tale", card_type_names
    assert_not_include "story", card_type_names
  end

  def test_rename_value_for_non_existent_card_type
    renamed_value = @project.card_type_definition.rename_value('story', 'tale')
    assert renamed_value.errors.any?
    card_type_names = @project.reload.card_type_definition.values.map(&:name)
    assert_not_include "tale", card_type_names
  end
end
