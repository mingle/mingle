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

class TreeConfigurationTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = create_project
    @project.activate
    login_as_admin
    @configuration = @project.tree_configurations.create!(:name => 'Planning')
    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end

  def test_find_card_by_parent_node_and_name_when_parent_node_is_nil
    init_three_level_tree(@configuration)
    @project.cards.find_by_name('story2').update_attribute(:name, 'release1')
    create_card!(:name => 'release1', :card_type => @type_release)

    card = @configuration.find_card_by_parent_node_and_name(nil, 'release1')
    assert card
    assert_equal 'release', card.card_type_name
    assert_equal 'release1', card.name
  end

  def test_find_card_by_parent_node_and_name_when_parent_node_is_on_the_tree
    init_five_level_tree(@configuration)
    @project.cards.find_by_name('story2').update_attribute(:name, 'iteration2')
    iter2_not_on_tree = create_card!(:name => 'iteration2', :card_type => @type_iteration)
    release1 = @project.cards.find_by_name('release1')

    card = @configuration.find_card_by_parent_node_and_name(release1, 'iteration2')
    assert card
    assert_equal 'iteration', card.card_type_name
    assert_equal 'iteration2', card.name
    assert iter2_not_on_tree.id != card.id
  end

  def test_find_card_by_parent_node_and_name_when_parent_node_low_level_node_is_on_tree
    init_three_level_tree(@configuration)
    create_card!(:name => 'story2', :card_type => @type_story)
    iteration1 = @project.cards.find_by_name('iteration1')

    card = @configuration.find_card_by_parent_node_and_name(iteration1, 'story2')
    assert card
    assert_equal 'story', card.card_type_name
    assert_equal 'story2', card.name
  end

  def test_update_config_name
    @configuration.name = 'new name'
    @configuration.save!
    assert_equal 'new name', @configuration.reload.name
  end

  def test_name_should_not_be_same_with_property_definition
    setup_property_definitions(:status => ['open'])
    @project.reload
    configuration = @project.tree_configurations.create(:name => 'status')
    assert !configuration.errors.empty?
  end

  # bug 3370
  def test_name_cannot_be_none
    configuration = @project.tree_configurations.create(:name => 'none')
    assert_equal ["Name cannot be #{'none'.bold}"], configuration.errors.full_messages

    configuration = @project.tree_configurations.create(:name => 'None ')
    assert_equal ["Name cannot be #{'None'.bold}"], configuration.errors.full_messages

    configuration = @project.tree_configurations.create(:name => 'Hi none')
    assert_equal [], configuration.errors.full_messages
  end

  def test_update_types_should_generate_containment_relationships
    assert @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert_equal(2, @configuration.relationships.size)
    assert_equal @type_release, @configuration.relationships[0].valid_card_type
    assert_equal @type_iteration, @configuration.relationships[1].valid_card_type
  end

  def test_should_blow_away_last_few_relationships_that_are_not_connected_to_any_property_type
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'}
    })
    assert_equal ['release'], @configuration.relationships.collect(&:name)
    assert_equal 2, @configuration.all_card_types.size
  end

  def test_should_give_useful_error_when_attempting_to_create_multiple_relationships_with_the_same_name
    config = @project.tree_configurations.create!(:name => 'New')
    config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'release'},
      @type_story => {:position => 2}
    })
    assert config.relationships.collect(&:name).empty?
    assert_equal "Relationship name #{'release'.bold} is not unique", config.errors.full_messages.join
  end

  def test_should_give_useful_error_when_attempting_to_create_relationships_with_no_name
    config = @project.tree_configurations.create!(:name => 'New')
    config.update_card_types({
      @type_release => {:position => 0, :relationship_name => ''},
      @type_iteration => {:position => 1}
    })
    assert config.relationships.collect(&:name).empty?
    assert config.errors.full_messages.join =~ /Relationship names cannot be blank/
  end

  def test_updating_relationship_names_should_not_corrupt_event_data
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert_equal ['release', 'iteration'], @configuration.relationships.collect(&:name)

    release1 = create_card!(:name => 'release1', :card_type => @type_release)
    iteration1 = create_card!(:name => 'iteration1', :card_type => @type_iteration)

    r1 = @configuration.relationships.first
    r2 = @configuration.relationships.last
    @configuration.add_child release1
    r1.update_card_by_obj(iteration1, release1)
    iteration1.save!

    version = iteration1.versions.last
    version.event.send(:generate_changes)
    version.reload

    assert_equal "release", version.event.changes.find_by_type("PropertyChange").field

    assert_nothing_raised do
      assert version.event.changes.find_by_type("PropertyChange").descriptive?
    end

    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'the one and only release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })

    version.event.reload

    assert_equal ["the one and only release", "iteration"], @configuration.reload.relationships.collect(&:name)
    assert_equal "the one and only release", version.event.changes.find_by_type("PropertyChange").field

    assert_nothing_raised do
      assert version.event.changes.find_by_type("PropertyChange").descriptive?
    end
  end

  def test_should_rename_generated_relationships_when_provided_specific_names
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert_equal ['release', 'iteration'], @configuration.relationships.collect(&:name)
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'the one and only release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert_equal ['the one and only release', 'iteration'], @configuration.reload.relationships.collect(&:name)
  end

  def test_should_be_able_to_tell_current_card_types_in_configuration
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    assert_equal([@type_iteration, @type_story], @configuration.all_card_types)
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert_equal([@type_release, @type_iteration, @type_story].collect(&:name), @configuration.all_card_types.collect(&:name))
  end

  def test_should_raise_runtime_error_if_last_relationships_card_type_is_more_than_one
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    r_iteration = @configuration.relationships[1]
    r_iteration.property_type_mappings.create(:card_type => @type_release)
    assert_raise(RuntimeError) { @configuration.all_card_types }
  end

  def test_each_generated_relationship_is_appliable_to_all_card_types_below_its_valid_type
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    r_release = @configuration.relationships[0]
    assert_include @type_story, r_release.card_types
    assert_include @type_iteration, r_release.card_types
    assert_not_include @type_release, r_release.card_types
    r_iteration = @configuration.relationships[1]
    assert_include @type_story, r_iteration.card_types
    assert_not_include @type_release, r_iteration.card_types
    assert_not_include @type_iteration, r_iteration.card_types
  end

  def test_config_tree_with_only_one_type_is_invalid
    assert !@configuration.update_card_types({
      @type_release => {:position => 0}
    })
    assert !@configuration.errors.empty?
  end

  def test_card_type_should_contains_all_its_below_card_types
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert @configuration.type_contains?(@type_release, @type_iteration)
    assert @configuration.type_contains?(@type_release, @type_story)
    assert @configuration.type_contains?(@type_iteration, @type_story)

    assert !@configuration.type_contains?(@type_story, @type_iteration)
    assert !@configuration.type_contains?(@type_story, @type_release)
    assert !@configuration.type_contains?(@type_iteration, @type_release)
    assert !@configuration.type_contains?(@type_story, @type_story)
  end

  def test_card_type_should_not_contain_any_card_type_not_in_the_tree
    setup_card_type(@project, 'issue')
    card_type_not_in_the_tree = @project.card_types.find_by_name('issue')
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert !@configuration.type_contains?(@type_story, card_type_not_in_the_tree)
    assert !@configuration.type_contains?(card_type_not_in_the_tree, @type_story)
  end

  def test_all_contains_all_type_in_the_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert @configuration.type_contains?(:tree, @type_release)
    assert @configuration.type_contains?(:tree, @type_iteration)
    assert @configuration.type_contains?(:tree, @type_story)

    setup_card_type(@project, 'issue')
    card_type_not_in_the_tree = @project.card_types.find_by_name('issue')
    assert !@configuration.type_contains?(:tree, card_type_not_in_the_tree)
  end

  def test_indirect_contains
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    @configuration.add_child(release_1)
    story_1 = create_card!(:name => 'story 1', :card_type => @type_story)
    story_1.cp_release = release_1
    story_1.save!

    assert @configuration.contains?(release_1, story_1)
  end

  def test_should_be_able_to_make_a_card_contain_another
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    story_1 = create_card!(:name => 'story 1', :card_type => @type_story)
    @configuration.add_child(release_1, :to => :root)
    @configuration.add_child(iteration_1, :to => :root)
    @configuration.add_child(iteration_1, :to => release_1)
    @configuration.reload
    release_1.reload
    iteration_1.reload

    assert @configuration.contains?(release_1, iteration_1)
    @configuration.add_child(story_1, :to => iteration_1)
    @configuration.reload
    assert @configuration.contains?(iteration_1, story_1)
  end

  def test_should_not_allow_adding_to_a_card_not_in_the_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    assert_raise RuntimeError do
      @configuration.add_child(iteration_1, :to => release_1)
    end
  end

  def test_containmentship_should_be_transitive
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    story_1 = create_card!(:name => 'story 1', :card_type => @type_story)
    @configuration.add_child(release_1, :to => :root)
    @configuration.add_child(iteration_1, :to => release_1)
    @configuration.add_child(story_1, :to => iteration_1)

    assert @configuration.contains?(release_1, story_1)
  end

  def test_should_be_able_to_tell_card_types_index
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert @configuration.card_type_index(:tree) < @configuration.card_type_index(@type_release)
    assert @configuration.card_type_index(@type_release) < @configuration.card_type_index(@type_iteration)
    assert @configuration.card_type_index(@type_iteration) < @configuration.card_type_index(@type_story)
  end

  def test_reconfig_tree_should_remove_relationships_that_not_in_the_new_configuration
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    assert_equal ['iteration'], @configuration.relationships.collect(&:name)
  end

  def test_reconfig_tree_should_add_relationship_that_not_in_the_old_configuration
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert_equal ['release', 'iteration'], @configuration.relationships.collect(&:name)
    assert_equal [1, 2], @configuration.relationships.collect(&:position)
  end

  def test_reconfig_should_reorganize_the_type_prop_mappings
    setup_card_type(@project, 'bug')
    type_bug = @project.card_types.find_by_name('bug')

    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })

    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2, :relationship_name => 'story'},
      type_bug => {:position => 3}
    })

    assert_equal [@type_release, @type_iteration, @type_story, type_bug], @configuration.all_card_types
    assert_equal ['iteration', 'story', 'bug'].sort, card_types_for_relationship('release').sort
    assert_equal ['story', 'bug'].sort, card_types_for_relationship('iteration').sort
    assert_equal ['bug'], card_types_for_relationship('story')

    @project.reload
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })

    assert_equal ['story'], card_types_for_relationship('iteration')
  end

  def test_remove_last_type_should_remove_one_relationship
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1}
    })
    assert_equal [@type_release, @type_iteration], @configuration.all_card_types
    assert_equal ['release'], @configuration.relationships.collect(&:name)
  end

  def test_remove_last_type_should_remove_the_card_of_that_type
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    s1 = @configuration.add_child(create_card!(:name => 'story1', :card_type => @type_story))
    r1 = @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release))
    i1 = @configuration.add_child(create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => r1)
    s2 = @configuration.add_child(create_card!(:name => 'story2', :card_type => @type_story), :to => i1)
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1}
    })
    @configuration.reload
    assert_equal ['release1'], @configuration.create_tree.root.children.collect(&:name)
    assert_equal ['iteration1'], @configuration.create_tree.find_node_by_name('release1').children.collect(&:name)
  end

  def test_reconfig_tree_should_remove_cards_that_not_in_the_type_list
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    s1 = @configuration.add_child(create_card!(:name => 'story1', :card_type => @type_story))
    r1 = @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release))
    i1 = @configuration.add_child(create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => r1)
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    assert !@configuration.include_card?(r1)
    assert @configuration.include_card?(i1)
    assert @configuration.include_card?(s1)
  end

  def test_remove_one_level_in_configuration_should_roll_up_descendants
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    s1 = @configuration.add_child(create_card!(:name => 'story1', :card_type => @type_story))
    r1 = @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release))
    i1 = @configuration.add_child(create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => r1)
    s2 = @configuration.add_child(create_card!(:name => 'story2', :card_type => @type_story), :to => i1)
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    @configuration.reload
    assert_equal ['iteration1', 'story1'].sort, @configuration.create_tree.root.children.collect(&:name).sort
    assert_equal ['story2'], @configuration.create_tree.find_node_by_name('iteration1').children.collect(&:name)
  end

  def test_can_not_reconfig_tree_with_simple_reverse_types
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    assert !@configuration.update_card_types({
      @type_iteration => {:position => 1},
      @type_story => {:position => 0, :relationship_name => 'story'}
    })
    assert !@configuration.errors.empty?
  end

  def test_can_not_reconfig_tree_with_complex_reverse_types
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    assert !@configuration.update_card_types({
      @type_release => {:position => 1, :relationship_name => 'release'},
      @type_iteration => {:position => 2},
      @type_story => {:position => 0, :relationship_name => 'story'}
    })
    assert !@configuration.errors.empty?
  end

  def test_move_card_within_tree_should_clear_prior_containment_values
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    r1 = @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release))
    r2 = @configuration.add_child(create_card!(:name => 'release2', :card_type => @type_release))
    i1 = @configuration.add_child(create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => r1)
    s1 = @configuration.add_child(create_card!(:name => 'story1', :card_type => @type_story), :to => i1)
    assert_equal i1, s1.cp_iteration
    @configuration.add_child(s1, :to => r2)
    s1.reload

    assert @configuration.errors.empty?
    assert_nil s1.cp_iteration
  end

  def test_should_be_able_to_tell_containings_count
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    r1 = create_card!(:name => 'release1', :card_type => @type_release)
    i1 = create_card!(:name => 'iteration1', :card_type => @type_iteration)
    s1 = create_card!(:name => 'story1', :card_type => @type_story)
    s2 = create_card!(:name => 'story2', :card_type => @type_story)
    s3 = create_card!(:name => 'story3', :card_type => @type_story)
    @configuration.add_child(r1, :to => :root)
    @configuration.add_child(i1, :to => r1)
    @configuration.add_child(s3, :to => r1)
    @configuration.add_child(s1, :to => i1)
    @configuration.add_child(s2, :to => i1)
    assert_equal(0, @configuration.containings_count_of(s1))
    assert_equal(0, @configuration.containings_count_of(s2))
    assert_equal(0, @configuration.containings_count_of(s3))
    assert_equal(2, @configuration.containings_count_of(i1))
    assert_equal(4, @configuration.containings_count_of(r1))
  end

  def test_next_card_type
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types
      assert_equal @type_iteration.name, @configuration.next_card_type(@type_release).name
      assert_equal @type_story.name, @configuration.next_card_type(@type_iteration).name
      assert_equal nil, @configuration.next_card_type(@type_story)
    end
  end

  def test_card_types_after
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      assert_equal ['iteration', 'story'], @configuration.card_types_after(@type_release).collect(&:name)
      assert_equal ['story'], @configuration.card_types_after(@type_iteration).collect(&:name)
      assert_equal [], @configuration.card_types_after(@type_story)
    end
  end

  def test_find_relationship_by_card_type
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      assert_equal @configuration.relationships.first, @configuration.find_relationship(@type_release)
      assert_equal @configuration.relationships.last, @configuration.find_relationship(@type_iteration)
      assert_equal nil, @configuration.find_relationship(@type_story)
    end
  end

  def test_should_give_warnings_when_delete_any_card_type_from_configuration
    init_three_level_tree(@configuration)
    @project.reload
    iteration1_card = @project.cards.find_by_name('iteration1')
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, @configuration.id, @type_iteration.id, AggregateScope::ALL_DESCENDANTS)
    @configuration.reload

    warnings = @configuration.update_warnings({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })
    assert warnings
    assert_equal [@type_iteration.name], warnings[:card_type]
    assert_equal ["Planning iteration"], warnings[:property]
    assert_equal ['iteration size'], warnings[:aggregate]
  end

  def test_should_give_warning_when_deleting_card_type_with_tree_transitions
    with_three_level_tree_project do |project|
      type_release = project.card_types.find_by_name('release')
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('story')
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      create_transition(project, story_sets = 'story sets tree iteration', :card_type => type_story, :set_properties => {'Planning iteration' => iteration1.id})
      create_transition(project, iteration_sets = 'iteration sets tree release', :card_type => type_iteration, :set_properties => {'Planning release' => release1.id})
      create_transition(project, story_requires = 'story requires tree iteration', :card_type => type_story,
                        :required_properties => {'Planning iteration' => iteration1.id}, :set_properties => {:status => 'open'})
      create_transition(project, iteration_requires = 'iteration requires tree iteration', :card_type => type_iteration,
                        :required_properties => {'Planning release' => release1.id}, :set_properties => {:status => 'open'})

      configuration = project.tree_configurations.find_by_name('three level tree')
      warnings = configuration.update_warnings({
        type_release => {:position => 0, :relationship_name => 'Planning release'},
        type_story => {:position => 1}
      })
      assert warnings
      assert_equal [iteration_requires, iteration_sets, story_requires, story_sets], warnings[:transition].smart_sort
    end
  end

  def test_should_give_warning_when_deleting_card_type_with_tree_card_defaults
    with_three_level_tree_project do |project|
      type_iteration = project.card_types.find_by_name('iteration')
      iteration_defaults = type_iteration.card_defaults
      release1_card = project.cards.find_by_name('release1')
      iteration_defaults.update_properties 'planning release' => release1_card.id
      iteration_defaults.save

      type_story = project.card_types.find_by_name('story')
      story_defaults = type_story.card_defaults
      iteration1_card = project.cards.find_by_name('iteration1')
      story_defaults.update_properties 'planning iteration' => iteration1_card.id
      story_defaults.save

      configuration = project.tree_configurations.find_by_name('three level tree')
      type_release = project.card_types.find_by_name('release')
      warnings = configuration.update_warnings({
        type_release => {:position => 0, :relationship_name => 'Planning release'},
        type_story => {:position => 1}
      })
      assert warnings
      assert_equal ['iteration', 'story'], warnings[:card_defaults].smart_sort
    end
  end

  #bug 4726
  def test_should_give_warning_when_remove_card_type_related_to_mql_filter_favorites
    with_three_level_tree_project do |project|
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('story')

      team_view = CardListView.construct_from_params(project, {:style => 'list', :filters => {:mql => %{ type = release and 'Planning release' = release1} }} )
      team_view.name = 'mql filter release tree view'
      team_view.save!
      personal_view = CardListView.construct_from_params(project, {:style => 'list', :filters => {:mql => %{ type = release and 'Planning release' = release1} }, :user_id => User.current.id} )
      personal_view.name = 'personal view does not matter'
      personal_view.save!

      configuration = project.tree_configurations.find_by_name('three level tree')
      warnings = configuration.update_warnings({
        type_iteration => {:position => 0, :relationship_name => 'Planning iteration'},
        type_story => {:position => 1}
      })
      assert_equal ['mql filter release tree view'], warnings[:card_list_views]
    end
  end

  def test_should_only_warn_users_about_deleting_team_favorites_when_removing_a_card_type_from_the_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })

    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    @configuration.add_child(release_1)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    @configuration.add_child(iteration_1, :to => release_1)
    story_1 = create_card!(:name => 'story 1', :card_type => @type_story)
    @configuration.add_child(story_1, :to => iteration_1)

    assert @configuration.contains?(release_1, iteration_1)
    assert @configuration.contains?(iteration_1, story_1)

    @project.card_list_views.create_or_update(:view => {:name => 'teamfilter'}, :tree_name => 'Planning', :style => 'hierarchy', :expands => "#{release_1.number},#{iteration_1.number}" )
    @project.card_list_views.create_or_update(:view => {:name => 'personal'}, :tree_name => 'Planning', :style => 'hierarchy', :expands => "#{release_1.number},#{iteration_1.number}", :user_id => User.current.id )

    warnings = @configuration.update_warnings({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })

    assert_equal ['teamfilter'], warnings[:card_list_views]
  end

  def test_should_actually_delete_both_team_and_personal_favorites_when_removing_a_card_type_from_the_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })

    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    @configuration.add_child(release_1)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    @configuration.add_child(iteration_1, :to => release_1)
    story_1 = create_card!(:name => 'story 1', :card_type => @type_story)
    @configuration.add_child(story_1, :to => iteration_1)

    assert @configuration.contains?(release_1, iteration_1)
    assert @configuration.contains?(iteration_1, story_1)

    @project.card_list_views.create_or_update(:view => {:name => 'teamfilter'}, :tree_name => 'Planning', :style => 'hierarchy', :expands => "#{release_1.number},#{iteration_1.number}" )
    @project.card_list_views.create_or_update(:view => {:name => 'personal'}, :tree_name => 'Planning', :style => 'hierarchy', :expands => "#{release_1.number},#{iteration_1.number}", :user_id => User.current.id )

    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })

    assert_equal [], @project.card_list_views
  end

  def test_removing_level_of_tree_will_delete_transitions_that_remove_card_with_that_type_from_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })

    transition = create_transition(@project, 'hi there', :card_type => @type_release, :remove_from_trees => [@configuration])
    assert_equal [transition], @project.transitions

    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })

    assert_equal [], @project.reload.transitions
  end

  def test_removing_level_of_tree_will_only_delete_transitions_that_remove_cards_from_this_tree_and_not_from_trees_that_have_the_same_card_type
    first_configuration, second_configuration = ['first tree', 'second tree'].collect { |tree_name| @project.tree_configurations.create!(:name => tree_name) }
    [first_configuration, second_configuration].each do |configuration|
      configuration.update_card_types({
        @type_release   => {:position => 0, :relationship_name => "#{configuration.name} - release"},
        @type_iteration => {:position => 1, :relationship_name => "#{configuration.name} - iteration"},
        @type_story     => {:position => 2}
      })
    end

    first_tree_transition  = create_transition(@project, 'remove from first tree',  :card_type => @type_story, :remove_from_trees => [first_configuration])
    second_tree_transition = create_transition(@project, 'remove from second tree', :card_type => @type_story, :remove_from_trees => [second_configuration])
    assert_equal [first_tree_transition.name, second_tree_transition.name], @project.transitions.collect(&:name).sort

    first_configuration.update_card_types({
      @type_release   => {:position => 0, :relationship_name => "#{first_configuration.name} - release"},
      @type_iteration => {:position => 1}
    })

    assert_equal [second_tree_transition.name], @project.reload.transitions.collect(&:name)
  end

  def test_should_change__remove_card_from_tree_with_children__to_just__remove_from_tree__for_second_to_last_card_type_when_last_card_type_is_removed
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })

    transition = create_transition(@project, 'remove iteration card with children', :card_type => @type_iteration, :remove_from_trees_with_children => [@configuration])
    assert_equal [TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE.to_s], transition.actions.collect(&:value)

    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1}
    })

    assert_equal [TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE.to_s], transition.reload.actions.collect(&:value)
  end

  def test_remove_one_level_in_configuration_should_delete_aggregate_property_definitions_on_that_level
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    @configuration.reload

    assert_equal ['release size'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name)
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    assert_equal [], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name)
  end

  def test_remove_lowest_level_in_configuration_should_delete_all_aggregate_property_definitions_on_parent_level
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    iteration_size = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, @configuration.id, @type_iteration.id, AggregateScope::ALL_DESCENDANTS)
    iteration_avg = setup_aggregate_property_definition('iteration avg', AggregateType::AVG, size, @configuration.id, @type_iteration.id, @type_story)
    @configuration.reload

    assert_equal ['iteration avg', 'iteration size', 'release size'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name).sort
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1}
    })
    assert_equal ['release size'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name)
  end

  def test_removing_lowest_level_in_config_should_delete_all_aggregates_with_scope_set_to_the_removed_card_type
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @configuration.id, @type_release.id, @type_story)
    release_all_size = setup_aggregate_property_definition('release all size', AggregateType::SUM, size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    iteration_size = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, @configuration.id, @type_iteration.id, @type_story)
    @configuration.reload

    assert_equal ['iteration size', 'release all size', 'release size'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name).sort
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1}
    })
    assert_equal ['release all size'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name)
  end

  def test_removing_one_level_in_configuration_should_delete_no_longer_applicable_children_only_aggregate_property_definitions_on_parent_levels
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size_all_desc = setup_aggregate_property_definition('release size all desc', AggregateType::SUM, size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    release_size_iteration_only = setup_aggregate_property_definition('release size iteration only', AggregateType::SUM, size, @configuration.id, @type_release.id, @type_iteration)
    release_size_story_only = setup_aggregate_property_definition('release size story only', AggregateType::SUM, size, @configuration.id, @type_release.id, @type_story)
    @configuration.reload

    assert_equal ['release size all desc', 'release size iteration only', 'release size story only'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name).sort
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })
    assert_equal ['release size all desc', 'release size story only'], @project.reload.aggregate_property_definitions_with_hidden.collect(&:name).sort
  end

  def test_removing_relationship_should_remove_associations_from_project_variables
    init_three_level_tree(@configuration)

    planning_iteration = @project.find_property_definition('planning iteration')
    iteration1 = @project.cards.find_by_name('iteration1')

    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :property_definition_ids => [planning_iteration.id], :value =>iteration1.id )

    assert_equal ['Planning iteration'], current_iteration.reload.property_definitions.collect(&:name)
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })

    assert_equal [], current_iteration.reload.property_definitions.collect(&:name)
  end

  def test_node_should_be_added_to_the_tree_when_adding_at_any_level
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    release1 = @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release), :to => :root)
    assert_equal 1, @configuration.cards_count
    iteration1 = @configuration.add_child(create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => release1)
    assert_equal 2, @configuration.cards_count
    @configuration.add_child(create_card!(:name => 'story 1', :card_type => @type_story), :to => iteration1)
    @configuration.add_child(create_card!(:name => 'story 2', :card_type => @type_story), :to => iteration1)
    assert_equal 4, @configuration.cards_count
  end

  def test_should_be_configured_after_add_first_relationship
    assert !@configuration.configured?
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    assert @configuration.configured?
  end

  def test_name_should_not_be_blank_and_be_unique_ignore_case_in_scope_of_project
    assert !TreeConfiguration.new(:name => '', :project => @project).valid?
    assert !TreeConfiguration.new(:name => '  ', :project => @project).valid?
    TreeConfiguration.create!(:name => 'some tree', :project => @project)
    assert !TreeConfiguration.new(:name => 'some tree', :project => @project).valid?
    assert !TreeConfiguration.new(:name => 'Some Tree', :project => @project).valid?
    assert !TreeConfiguration.new(:name => 'some tree  ', :project => @project).valid?
    create_project.with_active_project do |project|
      assert TreeConfiguration.new(:name => 'some tree', :project => project).valid?
    end
  end

  def test_after_configuration_should_be_able_to_add_correct_type_of_card_to_root_for_three_level_tree
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      iteration1 = project.cards.find_by_name('iteration1')
      card = create_card!(:name => 'release3', :card_type => @type_release)
      assert_raise(PropertyDefinition::InvalidValueException) do
        @configuration.add_child card, :to => iteration1
      end
    end
  end

  def test_child_should_have_card_property_point_to_parent_on_two_level_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1}
    })
    release1 = @configuration.add_child create_card!(:name => 'release1', :card_type => @type_release), :to => :root
    iteration1 = @configuration.add_child create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => release1
    assert_equal release1.name, iteration1.cp_release.name
  end

  def test_child_should_have_card_properties_point_to_all_ancestors
    with_three_level_tree_project do |project|
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      assert_equal nil, iteration1.cp_planning_iteration
      assert_equal release1, iteration1.cp_planning_release
      assert_equal iteration1.name, story1.cp_planning_iteration.name
      assert_equal release1.name, story1.cp_planning_release.name
    end
  end

  def test_not_configurated_tree_should_not_allow_to_add_child_and_should_create_root_only_tree
    assert_not_nil @configuration.create_tree
    assert_raise(RuntimeError) do
      @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release), :to => :root)
    end
    assert_equal [], @configuration.create_tree.root.children
  end

  def test_should_not_be_able_to_add_duplicate_card_to_the_card_tree
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'iteration'},
      @type_story => {:position => 1}
    })
    iteration1 = create_card!(:name => 'iteration1', :card_type => @type_iteration)
    @configuration.add_child(iteration1, :to => :root)
    @configuration.add_child(iteration1, :to => :root)
    assert_equal 1, @configuration.cards_count
  end

  def test_find_all_ancestor_cards
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      assert_equal ['release1'], @configuration.find_all_ancestor_cards(project.cards.find_by_name('iteration1')).collect(&:name)
      assert_equal ['iteration1', 'release1'].sort, @configuration.find_all_ancestor_cards(project.cards.find_by_name('story1')).collect(&:name).sort
      assert_equal [], @configuration.find_all_ancestor_cards(project.cards.find_by_name('release1')).collect(&:name)
    end
  end

  def test_unique_ancestors_of_cards
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      story_id = project.cards.find_by_name('story1').id
      iteration_id = project.cards.find_by_name('iteration1').id
      release_id = project.cards.find_by_name('release1').id
      mock_criteria = OpenStruct.new
      mock_criteria.to_sql = "IN (#{story_id})"
      assert_equal [iteration_id, release_id].sort, @configuration.unique_ancestors_of_cards(mock_criteria).collect(&:id).collect(&:to_i).sort
    end
  end

  def test_unique_ancestors_of_cards_should_not_include_cards_in_the_criteria
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      story_id = project.cards.find_by_name('story1').id
      story_2_id = project.cards.find_by_name('story2').id
      iteration_id = project.cards.find_by_name('iteration1').id
      release_id = project.cards.find_by_name('release1').id
      mock_criteria = OpenStruct.new
      mock_criteria.to_sql = "IN (#{story_id}, #{release_id}, #{story_2_id})"
      assert_equal [iteration_id].sort, @configuration.unique_ancestors_of_cards(mock_criteria).collect(&:id).collect(&:to_i).sort
    end
  end

  def test_tree_name_should_not_contain_special_chars
    assert !TreeConfiguration.new(:project => @project, :name => 'some new [tree]').valid?
    assert !TreeConfiguration.new(:project => @project, :name => 'ddd & eee').valid?
    assert !TreeConfiguration.new(:project => @project, :name => '#dddd').valid?
    assert !TreeConfiguration.new(:project => @project, :name => 'a = b').valid?
  end

  def test_should_not_allow_adding_card_whose_type_not_in_config_types
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 1}
    })
    i1 = create_card!(:name => 'iteration1', :card_type => @type_iteration)
    assert_raise(PropertyDefinition::InvalidValueException) { @configuration.add_child(i1, :to => :root)}
    assert_equal 0, @configuration.cards_count
  end

  def test_can_add_children_to_a_parent_node
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      iteration_2 = project.cards.find_by_name('iteration2')
      story_4 = create_card!(:name => 'I am story 4', :card_type => @type_story)
      story_5 = create_card!(:name => 'I am story 5', :card_type => @type_story)
      children = @configuration.add_children_to([story_4, story_5], iteration_2)
      assert_equal ['I am story 4', 'I am story 5'], children.collect(&:name).sort
      assert_equal ['I am story 4', 'I am story 5'], @configuration.create_tree.find_node_by_card(iteration_2).children.collect(&:name).sort
    end
  end

  def test_can_add_children_to_root
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      story_4 = create_card!(:name => 'I am story 4', :card_type => @type_story)
      story_5 = create_card!(:name => 'I am story 5', :card_type => @type_story)
      @configuration.add_children_to([story_4, story_5], :root)
      first_level = @configuration.create_tree.root.children.collect(&:name)
      assert_equal ['release1', 'I am story 4', 'I am story 5'].sort, first_level.sort
    end
  end


  def test_add_children_should_show_all_type_errors_in_message
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      release_6 = create_card!(:name => 'release 6', :card_type => @type_release)
      iteration_6 = create_card!(:name => 'iteration 6', :card_type => @type_iteration)
      story_6 = create_card!(:name => 'story 6', :card_type => @type_story)
      story_node = project.cards.find_by_name('story2')
      begin
        @configuration.add_children_to([release_6, iteration_6, story_6], story_node)
        fail
      rescue TreeConfiguration::InvalidChildException => e
        assert_equal 4, e.errors.size
        assert_equal "Type #{'story'.bold} cannot contain type #{'release'.bold}.", e.errors[0]
        assert_equal "Type #{'story'.bold} cannot contain type #{'iteration'.bold}.", e.errors[1]
        assert_equal "Type #{'story'.bold} cannot contain type #{'story'.bold}.", e.errors[2]
        assert_equal "No cards have been added to the tree.", e.errors[3]
      end
    end
  end

  def test_add_children_should_show_one_message_per_unique_error
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      release_6 = create_card!(:name => 'release 6', :card_type => @type_release)
      release_7 = create_card!(:name => 'release 7', :card_type => @type_release)
      story_node = project.cards.find_by_name('story2')
      begin
        @configuration.add_children_to([release_6, release_7], story_node)
        fail
      rescue TreeConfiguration::InvalidChildException => e
        assert_equal 1, e.errors.size
        assert_equal "Type #{'story'.bold} cannot contain type #{'release'.bold}. No cards have been added to the tree.", e.errors[0]
      end
    end
  end

  def test_remove_subtree
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')
      assert_equal [iteration1, story1, story2].collect(&:name).sort, @configuration.remove_card_and_its_children(iteration1).collect(&:name).sort
      assert !@configuration.include_card?(iteration1)
      assert !@configuration.include_card?(story1)
      assert !@configuration.include_card?(story2)
    end
  end

  def test_should_generate_new_version_after_removed_card_from_tree
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')

      assert_equal 2, iteration1.version
      assert_equal 3, story1.version

      @configuration.remove_card(iteration1)

      assert_equal 2 + 1, iteration1.reload.version
      assert_equal 3 + 1, story1.reload.version
      assert_equal 3 + 1, story2.reload.version
    end
  end

  def test_should_do_nothing_when_trying_to_remove_card_not_on_the_tree
    iteration1 = create_card!(:name => 'iteration1', :card_type => @type_iteration)
    @configuration.remove_card(iteration1)
    @configuration.remove_card(iteration1)
    assert_equal 0, @configuration.cards_count
  end

  def test_unset_parent_tree_property_will_remove_the_card_from_the_tree
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      story1 = @project.cards.find_by_name('story1')
      @configuration.remove_card(story1)
      assert !@configuration.include_card?(story1)
    end
  end

  def test_should_clear_all_the_tree_property_values_on_card_when_removing_card
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      story1 = project.cards.find_by_name('story1')
      @configuration.remove_card(story1)

      story1.reload

      assert_nil story1.cp_planning_iteration
      assert_nil story1.cp_planning_release
    end
  end

  def test_should_roll_up_all_children_after_remove_a_card
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')

      release1 = project.cards.find_by_name('release1')
      @configuration.remove_card(release1)
      assert_equal ['iteration1', 'iteration2'].sort, @configuration.create_tree.root.children.collect(&:name).sort
    end
  end

  def test_parent_card_ids
    init_planning_tree_with_multi_types_in_levels(@configuration)
    story1 = @project.cards.find_by_name('story1')
    iteration1 = @project.cards.find_by_name("iteration1")
    release1 = @project.cards.find_by_name("release1")
    assert_equal [iteration1.id, release1.id].sort, @configuration.parent_card_ids(story1).sort

    story4 = @project.cards.find_by_name("story4")
    iteration2 = @project.cards.find_by_name('iteration2')
    assert_equal [iteration2.id], @configuration.parent_card_ids(story4)
  end

  def test_should_be_able_to_tell_a_cards_level_in_complete_tree
    init_planning_tree_with_multi_types_in_levels(@configuration)
    story1 = @project.cards.find_by_name('story1')
    iteration1 = @project.cards.find_by_name("iteration1")
    release1 = @project.cards.find_by_name("release1")
    assert_equal 1, @configuration.level_in_complete_tree(release1)
    assert_equal 2, @configuration.level_in_complete_tree(iteration1)
    assert_equal 3, @configuration.level_in_complete_tree(story1)
    assert_equal 0, @configuration.level_in_complete_tree(:root)
  end

  def test_move_card_within_tree
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')

      story1 = project.cards.find_by_name('story1')
      iteration2 = project.cards.find_by_name('iteration2')
      @configuration.add_child(story1, :to => iteration2)
      assert_equal ['three level tree', 'release1', 'iteration2', 'story1', 'iteration1', 'story2'], @configuration.create_tree.nodes.collect(&:name)
    end
  end

  def test_move_card_within_tree2
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')

      iteration2 = project.cards.find_by_name('iteration2')
      @configuration.add_child(iteration2, :to => :root)
      assert_equal ['release1', 'iteration2'].sort, @configuration.create_tree.root.children.collect(&:name).sort

      release1 = project.cards.find_by_name("release1")
      @configuration.add_child(iteration2, :to => release1)
      assert_equal ['release1'], @configuration.create_tree.root.children.collect(&:name)
      assert_equal ['iteration1', 'iteration2'].sort, @configuration.create_tree.find_node_by_card(release1).children.collect(&:name).sort
    end
  end

  #################################################################################################################################
  #                                     Planning tree                                               Planning tree
  #                             -------------|---------                       \                 -----------|---------
  #                            |                      |              ==========\                |                   |
  #                    ----- release1----           release2                    \            release1         ---release2---------
  #                   |                 |             |                         /              |             |                   |
  #            ---iteration1----    iteration2    iteration3         ==========/        iteration2    ---iteration1----    iteration3
  #           |                |                                             /                       |                |
  #       story1            story2                                                                story1            story2
  #
  ###################################################################################################################################
  def test_move_sub_tree_within_tree
    init_two_release_planning_tree(@configuration)
    iteration1 = @project.cards.find_by_name('iteration1')
    release2 = @project.cards.find_by_name('release2')

    @configuration.add_child(iteration1, :to => release2)

    assert @configuration.errors.empty?

    assert_equal ['Planning', 'release1', 'iteration2', 'release2', 'iteration1', 'story1', 'story2', 'iteration3'].sort, @configuration.create_tree.nodes.collect(&:name).sort

    story1 = @project.cards.find_by_name('story1')
    assert_equal iteration1.id, story1.cp_planning_iteration_card_id
    assert_equal release2.id, story1.cp_planning_release_card_id
    assert_equal 0, @project.cards.find_all_by_name('any_name').size
  end

  def test_add_child_should_not_create_unnecessary_card_versions
    init_planning_tree_with_multi_types_in_levels(@configuration)
    release1 = @project.cards.find_by_name("release1")
    iteration100 =  @project.cards.new(:name => "iteration 100", :card_type => @type_iteration, :project => @project )
    @configuration.add_child(iteration100, :to => release1)
    assert_equal 1, iteration100.reload.versions.size
  end

  def test_repair_property_values
    init_two_release_planning_tree(@configuration)
    release2 = @project.cards.find_by_name('release2')
    iteration3 = @project.cards.find_by_name('iteration3')
    story1 = @project.cards.find_by_name('story1')
    assert_equal 'release1', story1.cp_planning_release.name
    assert_equal 'iteration1', story1.cp_planning_iteration.name

    property_values = PropertyValueCollection.from_params(
                        @project,
                        {@configuration.tree_relationship_name(@type_iteration) => iteration3.id}
                      )

    property_values.assign_to(story1)
    story1.save!

    assert_equal 'release2', story1.cp_planning_release.name
    assert_equal 'iteration3', story1.cp_planning_iteration.name
  end

  def test_repair_property_values_with_big_tree
    init_five_level_tree(@configuration)
    release2 = @project.cards.find_by_name('release2')
    story2 = @project.cards.find_by_name('story2')
    minutia1 = @project.cards.find_by_name('minutia1')

    property_values = PropertyValueCollection.from_params(
                        @project,
                        {
                          @configuration.tree_relationship_name(@type_release) => release2.id,
                          @configuration.tree_relationship_name(@type_story) => story2.id
                        }
                      )

    property_values.assign_to(minutia1)
    minutia1.save

    assert_equal 'release2', minutia1.cp_planning_release.name
    assert_equal 'iteration3', minutia1.cp_planning_iteration.name
    assert_equal 'story2', minutia1.cp_planning_story.name
    assert_nil minutia1.cp_planning_task
  end

  def test_repair_property_values_while_moving_card_to_root
    init_two_release_planning_tree(@configuration)
    story1 = @project.cards.find_by_name('story1')

    property_values = PropertyValueCollection.from_params(
                        @project,
                        {
                          @configuration.tree_relationship_name(@type_release) => nil
                        }
                      )

    property_values.assign_to(story1)
    story1.save!

    assert_nil story1.cp_planning_release
    assert_nil story1.cp_planning_iteration
  end

  def test_repair_property_values_while_set_tree_relationship_property_to_nil
    init_two_release_planning_tree(@configuration)
    story1 = @project.cards.find_by_name('story1')
    property_values = PropertyValueCollection.from_params(
                        @project,
                        {
                          @configuration.tree_relationship_name(@type_iteration) => nil
                        }
                      )
    property_values.assign_to(story1)
    story1.save!

    assert_equal 'release1', story1.cp_planning_release.name
    assert_nil story1.cp_planning_iteration
  end

  def test_should_ignore_property_values_dont_belongs_to_tree_configuration_while_repairing_property_values
    size = setup_numeric_text_property_definition('size')

    init_two_release_planning_tree(@configuration)
    release2 = @project.cards.find_by_name('release2')
    iteration3 = @project.cards.find_by_name('iteration3')
    story1 = @project.cards.find_by_name('story1')
    story1.card_type.add_property_definition size

    property_values = PropertyValueCollection.from_params(
                        @project,
                        {
                          @configuration.tree_relationship_name(@type_iteration) => iteration3.id,
                          size.name => 5
                        }
                      )

    property_values.assign_to(story1)
    story1.save!

    assert_equal release2.name, story1.cp_planning_release.name
    assert_equal iteration3.name, story1.cp_planning_iteration.name
    assert_equal '5', story1.cp_size
  end

  def test_should_add_error_when_attempting_to_repair_property_values_with_inconsistent_tree_values
    init_two_release_planning_tree(@configuration)
    release2 = @project.cards.find_by_name('release2')
    iteration2 = @project.cards.find_by_name('iteration2')
    story1 = @project.cards.find_by_name('story1')

    property_values = PropertyValueCollection.from_params(
                        @project,
                        {
                          @configuration.tree_relationship_name(@type_release) => release2.id,
                          @configuration.tree_relationship_name(@type_iteration) => iteration2.id
                        }
                      )

    property_values.assign_to(story1)
    assert !story1.save

    release2_message = "##{release2.number} release2".bold
    iteration2_message = "##{iteration2.number} iteration2".bold
    assert_equal %{Suggested location on tree #{'Planning'.bold} is invalid. Cannot have #{'Planning release'.bold} as #{release2_message} and #{'Planning iteration'.bold} as #{iteration2_message} at the same time.}, story1.errors.full_messages.join(' ')
  end

  def test_should_be_invalid_while_updating_card_card_type_of_which_is_not_valid_in_tree
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      type_bug = project.card_types.create(:name => 'bug')
      bug1 = create_card!(:name => 'bug 1', :card_type => type_bug)
      release1 = project.cards.find_by_name('release1')

      @configuration.find_relationship(@type_release).update_card(bug1, release1.id)
      assert !bug1.errors.empty?
    end
  end

  def test_should_be_valid_while_updating_card_card_type_of_which_is_not_valid_in_tree_to_nil
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      type_bug = project.card_types.create(:name => 'bug')
      bug1 = create_card!(:name => 'bug 1', :card_type => type_bug)
      @configuration.find_relationship(@type_release).update_card(bug1, nil)
      assert bug1.valid?
    end
  end

  def test_should_be_invalid_while_moving_card_to_parent_card_card_type_of_which_is_contained_by_the_card_type_in_the_tree_configuration
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      @configuration.find_relationship(@type_iteration).update_card(release1, iteration1.id)
      assert !release1.errors.empty?
    end
  end

  def test_expanded_card_name_should_contain_hierachy_information_top_to_down
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.find_by_name('three level tree')
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      subtree_names = @configuration.expanded_card_names(@configuration.sub_tree_condition(release1, :include_root => true))
      assert_equal 'release1', subtree_names[release1.id]
      assert_equal 'release1 > iteration1', subtree_names[iteration1.id]
      assert_equal 'release1 > iteration1 > story1', subtree_names[story1.id]
    end
  end

  def test_relationships_available_to
    configuration = @project.tree_configurations.create!(:name => 'three_level_tree')
    init_three_level_tree(configuration)
    story = create_card!(:name => 'I am story', :card_type => @type_story)
    iteration = create_card!(:name => 'I am story', :card_type => @type_iteration)
    release = create_card!(:name => 'I am story', :card_type => @type_release)
    assert_equal ['Planning release', 'Planning iteration'].sort, configuration.relationships_available_to(@project).collect(&:name).sort
    assert_equal ['Planning release', 'Planning iteration'].sort, configuration.relationships_available_to(story).collect(&:name).sort
    assert_equal ['Planning release'].sort, configuration.relationships_available_to(iteration).collect(&:name).sort
    assert_equal [].sort, configuration.relationships_available_to(release)
  end

  def test_aggregate_property_definitions_available_to
    configuration = @project.tree_configurations.create!(:name => 'three_level_tree')
    init_three_level_tree(configuration)
    aggregate_story_count_for_release = setup_aggregate_property_definition('stroy count for release', AggregateType::COUNT, nil, configuration.id, @type_release.id, @type_story)
    story = create_card!(:name => 'I am story', :card_type => @type_story)
    iteration = create_card!(:name => 'I am story', :card_type => @type_iteration)
    release = create_card!(:name => 'I am story', :card_type => @type_release)
    configuration.reload

    assert_equal [aggregate_story_count_for_release.name], configuration.aggregate_property_definitions_available_to(@project).collect(&:name)
    assert_equal [aggregate_story_count_for_release.name], configuration.aggregate_property_definitions_available_to(release).collect(&:name)
    assert [], configuration.aggregate_property_definitions_available_to(iteration)
    assert [], configuration.aggregate_property_definitions_available_to(story)
  end

  def test_aggregate_property_definitions_available_to_should_order_by_name
    configuration = @project.tree_configurations.create!(:name => 'three_level_tree')
    init_three_level_tree(configuration)
    aggregate_story_count_for_release = setup_aggregate_property_definition('release_count', AggregateType::COUNT, nil, configuration.id, @type_release.id, @type_story)
    aggregate_story_count_for_iteration = setup_aggregate_property_definition('iteration_count', AggregateType::COUNT, nil, configuration.id, @type_iteration.id, @type_story)
    configuration.reload
    assert_equal [aggregate_story_count_for_iteration.name, aggregate_story_count_for_release.name], configuration.aggregate_property_definitions_available_to(@project).collect(&:name)
  end

  #bug 3067
  def test_update_types_should_clear_removed_relationship_property_value_from_cards
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    init_three_level_tree(@configuration)
    iteration1 = @project.cards.find_by_name("iteration1")
    assert_equal 2, iteration1.versions.size
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_story => {:position => 2}
    })
    @project.reload
    iteration1.reload
    assert_nil iteration1.cp_release_card_id
    assert_equal 2+1, iteration1.versions.size
  end

  def test_can_tell_you_if_it_includes_card_type
    with_three_level_tree_project do |project|
      @configuration = project.tree_configurations.first
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      [@type_release, @type_iteration, @type_story].each do |card_type|
        assert @configuration.include_card_type?(card_type), "Should include #{card_type.name}, but didn't"
      end

      @type_card = @project.card_types.find_by_name('Card')
      assert !@configuration.include_card_type?(@type_card)
    end
  end

  def test_delete_card_type_in_tree_configuration_should_also_delete_the_card_list_view_use_it_as_expand_status
    init_three_level_tree(@configuration)
    release1 = @project.cards.find_by_name('release1')
    view = @project.card_list_views.create_or_update(:view => {:name => 'I am view'}, :expands => release1.number.to_s)
    @configuration.update_card_types({
      @type_iteration => {:position => 0, :relationship_name => 'Planning iteration'},
      @type_story => {:position => 1}
    })
    @project.reload
    assert !@project.card_list_views.detect{|view| view.name == 'I am view'}
  end

  # Bug 4649
  def test_should_move_a_card_to_the_its_top_level
    init_three_level_tree(@configuration)
    tree = @configuration.create_tree
    story1 = tree.find_node_by_name('story1')
    iteration1 = tree.find_node_by_name('iteration1')
    release1 = tree.find_node_by_name('release1')

    assert_equal iteration1, story1.parent
    @configuration.add_child(story1, :to => release1)
    new_tree = @configuration.reload.create_tree
    story1 = new_tree.find_node_by_name('story1')
    release1 = new_tree.find_node_by_name('release1')
    assert_equal release1.name, story1.parent.name
  end

  #bug 5389 still get the parent node that set in card defult when I try to add one card to root level
  def test_should_clear_all_card_tree_relationship_properties_when_adding_card_to_tree
    init_three_level_tree(@configuration)
    tree = @configuration.create_tree

    release_1 = create_card!(:name => 'release 1 in tree xxx', :card_type => @type_release)
    story_1 = create_card!(:name => 'story 1 in tree xxx', :card_type => @type_story)
    property_values = PropertyValueCollection.from_params(@project,
                        { @configuration.tree_relationship_name(@type_release) => release_1.id })
    property_values.assign_to(story_1)

    @configuration.add_child(story_1)
    @configuration.reload
    assert_include story_1.name, tree.nodes.collect(&:name)
    assert_not_include release_1.name, tree.nodes.collect(&:name)
  end

  def test_should_find_parent_card
    with_three_level_tree_project do |project|
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      configuration = project.tree_configurations.find_by_name('three level tree')
      assert_equal release1, configuration.find_parent_card_of(iteration1)
      assert_equal iteration1, configuration.find_parent_card_of(story1)
      assert_nil configuration.find_parent_card_of(release1)
    end
  end

  def test_update_card_types_will_error_out_when_aggregates_to_delete_are_used_in_formulas
    init_three_level_tree(@configuration)
    @type_release, @type_iteration, @type_story = find_planning_tree_types
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @configuration.id, @type_release.id, @type_iteration)
    @configuration.reload
    setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")

    assert !@configuration.update_card_types({
      @type_iteration => { :position => 0, :relationship_name => 'iteration' },
      @type_story => { :position => 1 }
    }), "Updating card types was successful, but we expected it to fail due to validation issues"

    assert @configuration.errors.full_messages.first.include?("cannot be deleted because it is currently used by formula"), "Error message did not match the one we expected"
  end

  def test_update_card_types_will_error_out_when_aggregates_to_delete_are_used_in_formulas
    init_three_level_tree(@configuration)
    @type_release, @type_iteration, @type_story = find_planning_tree_types
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @configuration.id, @type_release.id, @type_iteration)
    @configuration.reload
    formula_property = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")

    deletion_for_update = @configuration.deletion_for_update({
      @type_iteration => { :position => 0, :relationship_name => 'iteration' },
      @type_story => { :position => 1 }
    })

    sub_deletion = deletion_for_update.deletions.first
    assert_equal "is used as a component property of #{formula_property.name.bold}", sub_deletion.blockings.first.description
  end

  # Bug 6142
  def test_should_update_mql_filter_tree_name_when_tree_is_renamed
    view = CardListView.construct_from_params(@project, { :style => 'list', :filters => { :mql => 'FROM TREE Planning' } } )
    view.name = 'from tree'
    view.save!
    @configuration.name = 'timmy'
    @configuration.save!
    # For some reason, can't just reload the view - only a problem with the tests.
    view = CardListView.find_by_name('from tree')
    assert_equal 'FROM TREE timmy', view.mql_filter_value
  end

  def test_should_block_delete_tree_when_aggregate_is_used_by_other_property
    init_three_level_tree(@configuration)
    @project.reload
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size = setup_aggregate_property_definition('sum size', AggregateType::SUM, size, @configuration.id, @type_iteration.id, AggregateScope::ALL_DESCENDANTS)
    double_size = setup_formula_property_definition('double size', "'sum size' * 2")
    @configuration.reload

    deletion = @configuration.deletion
    assert deletion.blocked?
    sub_deletion = deletion.deletions.first
    assert_equal release_size, sub_deletion.model
    assert_equal "is used as a component property of #{'double size'.bold}", sub_deletion.blockings.first.description
  end

  def test_should_not_block_delete_tree_when_tree_has_aggregate_but_not_used_by_other_property
    init_three_level_tree(@configuration)
    @project.reload
    size = setup_numeric_property_definition('size', [1, 2, 3])
    release_size = setup_aggregate_property_definition('sum size', AggregateType::SUM, size, @configuration.id, @type_iteration.id, AggregateScope::ALL_DESCENDANTS)
    @configuration.reload

    assert !@configuration.deletion.blocked?
  end

  def test_include_card_should_work_for_card_versions
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    s1 = @configuration.add_child(create_card!(:name => 'story1', :card_type => @type_story))

    assert @configuration.include_card?(s1.find_version(1))
  end

  def test_include_card_should_return_false_for_empty_string
    assert_nil @configuration.include_card?('')
  end

  # bug_minglezy_829
  def test_data_corruption_and_error_of_updating_tree_structure_with_renaming_relationship_names
    with_new_project do |proj|
      tree = proj.tree_configurations.create(:name => 'three level tree')
      release, iteration, story = init_planning_tree_types
      init_three_level_tree(tree)

      new_type = proj.card_types.create!(:name => 'NewType')

      proj.card_list_views.create_or_update(:view => {:name => "hierarchy view"}, :style => 'hierarchy', :tree_name => 'three level tree')

      structure = {
        new_type => {:position => 0,
          :relationship_name => 'release'},
        release => {:position => 1,
          :relationship_name => 'iteration'},
        story => {:position => 2}
      }
      assert tree.update_card_types(structure), "tree errors: #{tree.errors.full_messages.join("\n")}"
      assert_equal(2, tree.relationships.size)
      assert_equal new_type, tree.relationships[0].valid_card_type
      assert_equal release, tree.relationships[1].valid_card_type
    end
  end

  def test_data_corruption_and_error_of_updating_tree_structure_without_renaming_relationship_names
    with_new_project do |proj|
      tree = proj.tree_configurations.create(:name => 'three level tree')
      release, iteration, story = init_planning_tree_types
      init_three_level_tree(tree)

      new_type = proj.card_types.create!(:name => 'NewType')

      structure = {
        new_type => {:position => 0,
          :relationship_name => 'Planning release'},
        release => {:position => 1,
          :relationship_name => 'Planning iteration'},
        story => {:position => 2}
      }
      assert tree.update_card_types(structure), "tree errors: #{tree.errors.full_messages.join("\n")}"
      assert_equal(2, tree.relationships.size)
      assert_equal new_type, tree.relationships[0].valid_card_type
      assert_equal release, tree.relationships[1].valid_card_type
    end
  end

  def test_update_warnings_when_update_tree_structure_without_renaming_relationship_names
    with_new_project do |proj|
      tree = proj.tree_configurations.create(:name => 'three level tree')
      release, iteration, story = init_planning_tree_types
      init_three_level_tree(tree)

      new_type = proj.card_types.create!(:name => 'NewType')

      structure = {
        new_type => {:position => 0,
          :relationship_name => 'Planning release'},
        release => {:position => 1,
          :relationship_name => 'Planning iteration'},
        story => {:position => 2}
      }
      warnings = tree.update_warnings(structure)
      assert warnings.size > 0
    end
  end

  private
  def card_types_for_relationship(relationship_name)
    @configuration.relationships.detect{ |r| r.name == relationship_name }.card_types.collect(&:name)
  end
end
