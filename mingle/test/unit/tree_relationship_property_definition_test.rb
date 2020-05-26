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

class TreeRelationshipPropertyDefinitionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = create_project
    @project.activate
    login_as_admin
    @tree_config = @project.tree_configurations.create!(:name => 'Planning')
    @type_story = @project.card_types.create :name => 'story'
    @type_iteration = @project.card_types.create :name => 'iteration'
    @type_release = @project.card_types.create :name => 'release'
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    @release1 = create_card!(:name => 'release1', :card_type => @type_release)
    @iteration1 = create_card!(:name => 'iteration1', :card_type => @type_iteration)
    @iteration2 = create_card!(:name => 'iteration2', :card_type => @type_iteration)
    @story1 = create_card!(:name => 'story1', :card_type => @type_story)
  end

  def test_should_update_value_map_to_column_after_update_card
    r1 = @tree_config.relationships.last
    assert_nil @story1.cp_iteration
    @tree_config.add_child(@iteration1)
    r1.update_card_by_obj(@story1, @iteration1)
    assert_equal @iteration1, @story1.cp_iteration
  end

  def test_should_transfer_the_update_effect_to_predecessor_property_definitions
    r1 = @tree_config.relationships.first
    r2 = @tree_config.relationships.last
    @tree_config.add_child @release1
    r1.update_card_by_obj(@iteration1, @release1)
    @iteration1.save!
    assert_equal @release1, @iteration1.cp_release

    r1.update_card_by_obj(@story1, @release1)
    r2.update_card_by_obj(@story1, @iteration1)
    @story1.save!
    @story1.reload
    assert_equal @iteration1, @story1.cp_iteration
    assert_equal @release1, @story1.cp_release
  end

  def test_should_add_the_updating_card_to_the_tree_if_value_is_a_card_on_the_tree
    r1 = @tree_config.relationships.first
    r2 = @tree_config.relationships.last
    @tree_config.add_child @release1
    r1.update_card_by_obj(@iteration1, @release1)
    r2.update_card_by_obj(@story1, @iteration1)
    @iteration1.save!
    @story1.save!
    assert @tree_config.include_card?(@iteration1)
    assert @tree_config.include_card?(@story1)
  end

  def test_should_invalid_card_if_parent_type_is_invalid_when_update_card
    r_release = @tree_config.relationships.first
    r_release.update_card(@iteration1, @story1.id)
    assert !@iteration1.valid?
    assert !@iteration1.errors.empty?
  end

  def test_should_clean_card_defaults_when_deleting_card_type_from_configuration
    @type_iteration.card_defaults.update_properties([[@tree_config.find_relationship(@type_iteration).name, @iteration1.id]])
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })
    assert_equal [], @type_iteration.card_defaults.actions
  end

  def test_property_values_description
    r_release = @tree_config.relationships.first
    assert_equal "Any card used in tree", r_release.property_values_description
  end

  def test_lane_values_returns_card_name_and_number_pairs
    release = @tree_config.relationships.detect { |tree_prop| tree_prop.name == 'release' }
    assert_equal [[@release1.name, @release1.number.to_s]], release.lane_values

    iteration = @tree_config.relationships.detect { |tree_prop| tree_prop.name == 'iteration' }

    @tree_config.add_child(@release1)
    @tree_config.add_child(@iteration1, :to => @release1)
    @tree_config.add_child(@iteration2, :to => @release1)

    assert_equal [["#{@release1.name} > #{@iteration1.name}", @iteration1.number.to_s],
                     ["#{@release1.name} > #{@iteration2.name}", @iteration2.number.to_s]], iteration.lane_values


  end
end
