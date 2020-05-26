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

##################################################################################################
#                                 ---------------Planning tree-----------------
#                                |                                            |
#                    ----- release1----                                -----release2-----
#                   |                 |                               |                 |
#              iteration1      iteration2                       iteration3          iteration4
#                  |                                                 |
#           ---story1----                                         story2        
#          |           |
#       task1   -----task2----
#              |             |  
#          minutia1       minutia2      
#           
##################################################################################################

class TreeFilterTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = filtering_tree_project
    @project.activate
    login_as_member
    @config = @project.tree_configurations.find_by_name('filtering tree')
  end
  
  def test_hash_style_param_gets_interpretted_as_being_implicit_type_filter
    filters = TreeFilters.new(@project, {:tf_reLease => []}, @config)
    assert_mql "((type is release or type is iteration or type is story or type is task or type is minutia) and from tree filtering tree)", filters
    
    filters_with_excluded = TreeFilters.new(@project, {:excluded => ['iteration', 'task']}, @config)
    assert_mql "(((type is release or type is iteration or type is story or type is task or type is minutia) and (type is not iteration and type is not task)) and from tree filtering tree)", filters_with_excluded
  end
  
  def test_should_return_identical_hash_as_params_except_for_casing_of_type_keys
    filters = TreeFilters.new(@project, TreeFilters.default_params(@config), @config)
    assert_equal({}, filters.to_params)
    
    filters = TreeFilters.new(@project, {:tf_reLease => ["[planning release][is][#{PropertyValue::IGNORED_IDENTIFIER}]"]}, @config)
    assert_equal({}, filters.to_params)
    
    filters = TreeFilters.new(@project, {:tf_reLease => ["[workstream][is][rubbish]", "[planning release][is][#{PropertyValue::IGNORED_IDENTIFIER}]"]}, @config)
    assert_equal({:tf_release => ["[workstream][is][rubbish]"]}, filters.to_params)
    
    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[workstream][is][rubbish]", "[planning release][is][1]"],
      :tf_ITERAtion => ["[planning iteration][is][3]"],
      :excluded => ['relEase']
    }, @config)
    assert_equal({
      :tf_release => ["[workstream][is][rubbish]", "[Planning release][is][1]"],
      :tf_iteration => ["[Planning iteration][is][3]"],
      :excluded => ['relEase']
    }, filters.to_params)
  end

  def test_each_should_iterate_over_flattened_properties
    iteration3_card = @project.cards.find_by_name('iteration3')
    story2_card = @project.cards.find_by_name('story2')
    filters = TreeFilters.new(@project, {:tf_reLease => [], :tf_iteration => ["[planning iteration][is][#{iteration3_card.number}]"], :tf_story => ["[planning story][is][#{story2_card.number}]"], :excluded => ['task', 'minutia']}, @config)
    counter = 0
    filters.each { counter += 1 }
    assert_equal 5, counter
  end
  
  def test_relationship_property_values_should_cascade_to_lower_levels_in_tree
    release_card = @project.cards.find_by_name('release1')
    iteration1_card = @project.cards.find_by_name('iteration1')
    iteration2_card = @project.cards.find_by_name('iteration2')
    iteration3_card = @project.cards.find_by_name('iteration3')
    story2_card = @project.cards.find_by_name('story2')
    
    filters = TreeFilters.new(@project, {:tf_reLease => ["[planning release][is][#{release_card.number}]"], :tf_iteration => [], :tf_story => [], :excluded => ['task', 'minutia']}, @config)
    assert_found_card_names ['iteration1', 'iteration2', 'release1', 'story1'], filters
    
    filters = TreeFilters.new(@project, {:tf_reLease => ["[planning release][is][#{release_card.number}]"], :tf_iteration => ["[planning iteration][is][#{iteration1_card.number}]"], :tf_story => [], :excluded => ['task', 'minutia']}, @config)
    assert_found_card_names ['iteration1', 'release1', 'story1'], filters
    
    filters = TreeFilters.new(@project, {:tf_reLease => [], :tf_iteration => ["[planning iteration][is][#{iteration2_card.number}]"], :tf_story => [], :excluded => ['task', 'minutia']}, @config)
    assert_found_card_names ['iteration2', 'release1', 'release2'], filters
    
    filters = TreeFilters.new(@project, {:tf_reLease => [], :tf_iteration => ["[planning iteration][is][#{iteration2_card.number}]"], :tf_story => ["[planning story][is][#{story2_card.number}]"], :excluded => ['task', 'minutia']}, @config)
    assert_found_card_names ['iteration2', 'release1', 'release2'], filters
    
    filters = TreeFilters.new(@project, {:tf_reLease => [], :tf_iteration => ["[planning iteration][is][#{iteration3_card.number}]"], :tf_story => ["[planning story][is][#{story2_card.number}]"], :excluded => ['task', 'minutia']}, @config)
    assert_found_card_names ['iteration3', 'release1', 'release2', 'story2'], filters
  end
  
  def test_card_query_for_relproject_level_variables_should_cascade_down_to_lower_levels
    release_type = @project.card_types.find_by_name('release')
    release_card = @project.cards.find_by_name('release1')
    planning_iteration = @project.find_property_definition('planning iteration')
    planning_release = @project.find_property_definition('planning release')
    create_plv!(@project, :name => 'current release', :value => release_card.id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => release_type, :property_definition_ids => [planning_release.id])
    filters = TreeFilters.new(@project, {:tf_reLease => ["[planning release][is][(current release)]"], :tf_iteration => [], :tf_story => [], :excluded => ['release', 'story', 'task', 'minutia']}, @config)
    assert_found_card_names ['iteration1', 'iteration2'], filters
  end
  
  def test_should_be_able_to_detect_project_variables
    release_type = @project.card_types.find_by_name('release')
    release_card = @project.cards.find_by_name('release1')
    planning_iteration = @project.find_property_definition('planning iteration')
    planning_release = @project.find_property_definition('planning release')
    plv = create_plv!(@project, :name => 'current release', :value => release_card.id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => release_type, :property_definition_ids => [planning_release.id])
    filters = TreeFilters.new(@project, {:tf_reLease => ["[planning release][is][(current release)]"], :tf_iteration => [], :tf_story => [], :excluded => ['release', 'story', 'task', 'minutia']}, @config)
    assert_equal([plv], filters.project_variables_used)
  end
  
  def test_should_carry_forward_all_parent_restricting_properties_to_children
    @project.cards.find_by_name('release1').update_attributes(:cp_workstream => 'x2')
    
    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[workstream][is][x2]"], 
      :tf_iteration => [], 
      :tf_story => [],
      :tf_task => [],
      :tf_minutia => []
    }, @config)
    assert_found_card_names ['iteration1', 'iteration2', 'minutia1', 'minutia2', 'release1', 'story1', 'task1', 'task2'], filters
  end 
  
  def test_should_generate_or_condition_for_repeated_relationship_filter_params
    release_1 = @project.cards.find_by_name('release1')
    release_2 = @project.cards.find_by_name('release2')

    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[planning release][is][#{release_1.number}]", "[planning release][is][#{release_2.number}]"], 
      :tf_iteration => [], 
      :tf_story => [],
      :tf_task => [],
      :tf_minutia => [],
      :excluded => ['iteration', 'story', 'task', 'minutia']
    }, @config)
    assert_found_card_names ['release1', 'release2'], filters
  end 
  
  def test_should_filter_by_is_not_conditions_for_relationship_properties
    release_1 = @project.cards.find_by_name('release1')

    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[planning release][is not][#{release_1.number}]"], 
      :tf_iteration => [], 
      :tf_story => [],
      :tf_task => [],
      :tf_minutia => [],
      :excluded => ['iteration', 'story', 'task', 'minutia']
    }, @config)
    assert_found_card_names ['release2'], filters
  end 
  
  def test_should_understand_which_card_types_are_excluded
    release_1 = @project.cards.find_by_name('release1')

    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[planning release][is not][#{release_1.number}]"], 
      :tf_iteration => [], 
      :tf_story => [],
      :tf_task => [],
      :tf_minutia => []
    }, @config)
    @config.all_card_types.each do |card_type|
      assert !filters.excluded?(card_type), "#{card_type.name} should not be excluded from being shown, but was."
    end
      
    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[planning release][is not][#{release_1.number}]"], 
      :tf_iteration => [], 
      :tf_story => [],
      :tf_task => [],
      :tf_minutia => [],
      :excluded => []
    }, @config)
    @config.all_card_types.each do |card_type|
      assert !filters.excluded?(card_type), "#{card_type.name} should not be excluded from being shown, but was."
    end
      
    filters = TreeFilters.new(@project, {
      :tf_reLease => ["[planning release][is not][#{release_1.number}]"], 
      :tf_iteration => [], 
      :tf_story => [],
      :tf_task => [],
      :tf_minutia => [],
      :excluded => ['iteration']
    }, @config)
    included_card_types, excluded_card_types = @config.all_card_types.partition { |card_type| card_type.name.downcase != 'iteration' }
    included_card_types.each do |card_type|
      assert !filters.excluded?(card_type), "#{card_type.name} should not be excluded from being shown, but was."
    end  
    excluded_card_types.each do |card_type|
      assert filters.excluded?(card_type), "#{card_type.name} should be excluded from being shown, but was not."
    end  
  end 
  
  def test_should_not_be_invalid_when_supplying_relationship_properties_with_the_wrong_type_of_filter
    release_card = @project.cards.find_by_name('release1')
    release_card.update_attributes(:cp_workstream => 'x2')
    
    filters = TreeFilters.new(@project, {:tf_reLease => ["[planning release][is][#{release_card.number}]"], :tf_iteration => [], :tf_story => [], :excluded => ['task', 'minutia']}, @config)
    assert_equal false, filters.invalid?
  end 
  
  # TODO: Core problem is that Type is being passed in at all.
  def test_duplicate_type_filters_does_not_exclude_too_much_when_there_are_multiple_types_in_a_level
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config = project.tree_configurations.create!(:name => 'multi_types_in_levels')
      init_planning_tree_with_multi_types_in_levels(tree_config)
      
      filters = TreeFilters.new(project, {
        :tf_reLease => ["[Type][is][#{type_release.name}]"], 
        :tf_iteration => ["[Type][is][#{type_iteration.name}]"], 
        :tf_story => ["[Type][is][#{type_story.name}]"],
        :excluded => ['iteration']
      }, tree_config)
      
      assert_found_card_names ['release1', 'story1', 'story2', 'story3', 'story4', 'story5'], filters
    end
  end
  
  def test_should_allow_relationship_properties_to_be_not_set
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config = project.tree_configurations.create!(:name => 'multi_types_in_levels')
      init_planning_tree_with_multi_types_in_levels(tree_config)
      setup_property_definitions :status => ['open', 'closed']
      status = project.property_definitions.detect{|pd|pd.name == 'status'}
      [type_iteration, type_release, type_story].each do |card_type|
        card_type.property_definitions += [status]
        card_type.save!
      end
      
      filters = TreeFilters.new(project, {
        :tf_reLease => ['[planning release][is][]'], 
        :tf_iteration => [], 
        :tf_story => [],
        :excluded => []
      }, tree_config)
      assert_found_card_names ['iteration2', 'story4', 'story5'], filters
      
      iteration2 = project.cards.find_by_name('iteration2')
      filters = TreeFilters.new(project, {
        :tf_reLease => ['[status][is][open]', '[planning release][is][]'],
        :tf_iteration => ['[status][is][]', '[planning iteration][is][]', "[planning iteration][is][#{iteration2.number}]"],
        :tf_story => [],
        :excluded => []
      }, tree_config)
      assert_found_card_names ['iteration2', 'story4', 'story5'], filters
    end  
  end  
    
  def test_parameter_order_should_not_effect_sorted_filter_string
    release1_card = @project.cards.find_by_name('release1')
    iteration1_card = @project.cards.find_by_name('iteration1')
    iteration2_card = @project.cards.find_by_name('iteration2')
    
    semantically_same_filters1 = TreeFilters.new(@project, {
      :tf_release => ["[workstream][is][x1]", "[workstream][is][x2]", "[planning release][is][#{release1_card.number}]"],
      :tf_iteration => ["[planning iteration][is][#{iteration1_card.number}]", "[planning iteration][is][#{iteration2_card.number}]", "[quick_win][is not][no]"],
      :tf_story => [],
      :excluded => ['iteration', 'release']
    }, @config)
    
    semantically_same_filters2 = TreeFilters.new(@project, {
      :excluded => ['release', 'iteration'],
      :tf_iteration => ["[planning iteration][is][#{iteration2_card.number}]", "[quick_win][is not][no]", "[planning iteration][is][#{iteration1_card.number}]"],
      :tf_story => [],
      :tf_release => ["[workstream][is][x2]", "[workstream][is][x1]", "[planning release][is][#{release1_card.number}]"]
    }, @config)
    
    assert semantically_same_filters1.sorted_filter_string == semantically_same_filters2.sorted_filter_string
  end
  
  def test_sorted_filter_string_should_include_excluded
    release1_card = @project.cards.find_by_name('release1')
    iteration1_card = @project.cards.find_by_name('iteration1')
    iteration2_card = @project.cards.find_by_name('iteration2')
    
    filters_with_excluded = TreeFilters.new(@project, {
      :tf_release => ["[workstream][is][x1]"],
      :tf_iteration => ["[quick_win][is not][no]"],
      :tf_story => [],
      :excluded => ['iteration', 'release']
    }, @config)
    
    filters_without_excluded = TreeFilters.new(@project, {
      :tf_release => ["[workstream][is][x1]"],
      :tf_iteration => ["[quick_win][is not][no]"],
      :tf_story => []
    }, @config)
    
    assert filters_with_excluded.sorted_filter_string != filters_without_excluded.sorted_filter_string
  end
  
  def test_tree_level_should_matter_with_sorted_filter_string
    open_release_closed_iteration = TreeFilters.new(@project, {
      :tf_release => ["[status][is][open]"],
      :tf_iteration => ["[status][is][closed]"]
    }, @config)
    
    closed_release_open_iteration = TreeFilters.new(@project, {
      :tf_release => ["[status][is][closed]"],
      :tf_iteration => ["[status][is][open]"]
    }, @config)
    
    assert open_release_closed_iteration.sorted_filter_string != closed_release_open_iteration.sorted_filter_string
  end
  
  def test_description_with_exclusions_and_filters
    release1_card = @project.cards.find_by_name('release1')
    iteration1_card = @project.cards.find_by_name('iteration1')
    iteration2_card = @project.cards.find_by_name('iteration2')
    iteration3_card = @project.cards.find_by_name('iteration3')
    
    release_filters = Filters.new(@project, ["[workstream][is][rubbish]", "[planning release][is][#{release1_card.number}]"])
    iteration_filters = Filters.new(@project, ["[planning iteration][is][#{iteration1_card.number}]", 
                                               "[planning iteration][is][#{iteration2_card.number}]", 
                                               "[planning iteration][is][#{iteration3_card.number}]", 
                                               "[quick_win][is not][no]"])
    filters = TreeFilters.new(@project, {
      :tf_release => release_filters.to_params,
      :tf_iteration => iteration_filters.to_params,
      :tf_story => [],
      :excluded => ['iteration', 'release']
    }, @config)
    
    expected_description = <<HEY
#{'Properties'.italic}: Do not show #{'release'.bold} and #{'iteration'.bold} cards. release filter: #{release_filters.description_without_header}. iteration filter: #{iteration_filters.description_without_header}.
HEY
    assert_equal expected_description.trim, filters.description
  end
  
  def test_description_with_exclusions_only
    filters = TreeFilters.new(@project, {
      :tf_release => [],
      :tf_iteration => [],
      :tf_story => [],
      :excluded => ['iteration', 'story', 'release']
    }, @config)

    assert_equal "Do not show #{'release'.bold}, #{'iteration'.bold}, and #{'story'.bold} cards.", filters.to_s
  end
  
  def test_description_with_filters_only
    release_filters = Filters.new(@project, ["[workstream][is][rubbish]"])
    iteration_filters = Filters.new(@project, ["[quick_win][is not][no]"])
    filters = TreeFilters.new(@project, {
      :tf_release => release_filters.to_params,
      :tf_iteration => iteration_filters.to_params,
      :tf_story => [],
      :excluded => []
    }, @config)

    assert_equal "release filter: #{release_filters.description_without_header}. iteration filter: #{iteration_filters.description_without_header}.", filters.to_s
  end
  
  def test_description_with_nothing
    filters = TreeFilters.new(@project, {
      :tf_release => [],
      :tf_iteration => [],
      :tf_story => [],
      :excluded => []
    }, @config)

    assert_equal '', filters.to_s
  end
  
  def test_properties_for_aggregate_by
    filters = TreeFilters.new(@project, {
      :tf_release => [],
      :tf_iteration => [],
      :tf_story => [],
      :excluded => ['task']
    }, @config)
    
    assert_equal ["iteration size", "release size", "story size", "sum of iteration size"].sort, filters.properties_for_aggregate_by.collect(&:name).sort
    
    filters = TreeFilters.new(@project, {
      :tf_release => [],
      :tf_iteration => [],
      :tf_story => [],
      :excluded => ['release']
    }, @config)
    
    assert_equal ["iteration size", "story size"], filters.properties_for_aggregate_by.collect(&:name)
    
    filters = TreeFilters.new(@project, {
      :tf_release => [],
      :tf_iteration => [],
      :tf_story => [],
      :excluded => ['story']
    }, @config)
    
    assert_equal ["iteration size", "release size", "sum of iteration size"], filters.properties_for_aggregate_by.collect(&:name)
  end
  
  # bug 3459
  def test_properties_for_group_by_do_not_include_infinite_valued_properties
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release_type = project.card_types.find_by_name('release')
      formula_pd = setup_formula_property_definition('formula', '1 + 2')
      release_type.add_property_definition(formula_pd)
      release_type.save!
      
      filters = TreeFilters.new(project, {
        :tf_release => [],
        :tf_iteration => [],
        :tf_story => [],
        :excluded => ['story', 'iteration']
      }, configuration)
      
      assert_equal ["Type"].sort, filters.properties_for_group_by.collect(&:name).sort
    end
  end
  
  # bug 3430
  def test_group_by_properties_are_ordered_by_tree
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      
      some_normal_property = setup_numeric_property_definition('z property', [1, 2, 3])
      some_other_property = setup_numeric_property_definition('a property', [1, 2, 3])
      type_story.add_property_definition(some_normal_property)
      type_story.add_property_definition(some_other_property)
      type_story.save!
      
      configuration2 = project.tree_configurations.create!(:name => 'Second Tree')
      configuration2.update_card_types({
        type_release => {:position => 0, :relationship_name => 'Second Tree release'}, 
        type_iteration => {:position => 1, :relationship_name => 'Second Tree iteration'}, 
        type_story => {:position => 2}
      })
      
      filters = TreeFilters.new(project, {
        :tf_release => [],
        :tf_iteration => [],
        :tf_story => [],
        :excluded => ['iteration', 'release']
      }, configuration)
      
      assert_equal ["Type", "a property", "z property", "Planning release", "Planning iteration", "Second Tree release", "Second Tree iteration"], filters.properties_for_group_by.collect(&:name)
    end
  end
  
  def test_should_drive_column_properties_from_current_filter_types
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release, iteration, story = find_planning_tree_types
      
      other = project.card_types.create!(:name => 'other')
      
      story_status = project.create_text_list_definition!(:name => 'story status')
      story_status.update_attributes(:card_types => [story])
      
      owner = project.create_user_definition!(:name => 'owner')
      owner.update_attributes(:card_types => [story, iteration])
      
      bug_status = project.create_text_list_definition!(:name => 'bug status')
      bug_status.update_attributes(:card_types => [iteration])
      
      other_status = project.create_text_list_definition!(:name => 'other status')
      other_status.update_attributes(:card_types => [other])
      
      no_exclusion_filters = tree_filter_excluding([], project, configuration)
      just_story_filters = tree_filter_excluding(['iteration', 'release'], project, configuration)
      just_iteration_filters = tree_filter_excluding(['release', 'story'], project, configuration)
      story_or_iteration_filters = tree_filter_excluding(['release'], project, configuration)
      project.reload
      
      assert_equal ["Type", "bug status", "owner", "Planning iteration", "Planning release", "story status", "Created by", "Modified by"], no_exclusion_filters.column_properties.collect(&:name)
      assert_equal ["Type", "owner", "Planning iteration", "Planning release", "story status", "Created by", "Modified by"], just_story_filters.column_properties.collect(&:name)
      assert_equal ["Type", "bug status", "owner", "Planning release", "Created by", "Modified by"], just_iteration_filters.column_properties.collect(&:name)
      assert_equal ["Type", "bug status", "owner", "Planning iteration", "Planning release", "story status", "Created by", "Modified by"], story_or_iteration_filters.column_properties.collect(&:name)
    end
  end
  
  # bug 3363
  def test_update_date_format_does_not_cause_exception
    @project.date_format = Date::DAY_LONG_MONTH_YEAR
    @project.save!
    
    filters = tree_filter_excluding(['release'], @project, @config)
    begin
      filters.update_date_format(Date::DAY_LONG_MONTH_YEAR, Date::MONTH_DAY_YEAR)
    rescue Exception => e
      fail "An exception was thrown when it should not have been"
    end
  end
  
  # bug 4671
  # the functionality this tests isn't absolutely necessary, but is just a nice bonus that allows the url to be a bit messed up and still work
  def test_tree_filters_combines_values_when_two_keys_come_in_with_different_casing
    filters = TreeFilters.new(@project, {:tf_story => ["[status][is][one]"], :tf_STORY => ["[status][is][two]"], :excluded => ["Release"]}, @config)
    assert_equal ["[status][is][one]","[status][is][two]"].sort, filters.to_params[:tf_story].sort
  end
  
  def test_should_be_invalid_when_deleted_card_is_used
    filters = TreeFilters.new(@project, {:tf_iteration => ["[planning iteration][is][an_invalid_iteration]"]}, @config)
    assert filters.invalid?
    assert_equal ["#{'an_invalid_iteration'.bold} is an unknown card."], filters.validation_errors
  end
  
  def test_should_be_valid_when_valid_card_is_used
    iteration1 = @project.cards.find_by_name('iteration1')
    filters = TreeFilters.new(@project, {:tf_iteration => ["[planning iteration][is][#{iteration1.number}]"]}, @config)
    assert !filters.invalid?
    assert_equal [], filters.validation_errors
  end
  
  # Bug 8045
  def test_invalid_when_excluded_card_type_does_not_exist
    filters = TreeFilters.new(@project, { :excluded => ['an_invalid_card_type'] }, @config)
    assert_equal ["Tree #{'filtering tree'.bold} does not contain excluded card type #{'an_invalid_card_type'.bold}."], filters.validation_errors
    assert filters.invalid?
  end
  
  # Bug 8045
  def test_invalid_when_excluded_card_type_is_not_in_the_tree
    @project.card_types.create(:name => 'card_type_not_in_tree')
    filters = TreeFilters.new(@project, { :excluded => ['card_type_not_in_tree'] }, @config)
    assert_equal ["Tree #{'filtering tree'.bold} does not contain excluded card type #{'card_type_not_in_tree'.bold}."], filters.validation_errors
    assert filters.invalid?
  end
  
  private
  
  def tree_filter_excluding(type_names, project, configuration)
    TreeFilters.new(project, {
      :tf_release => [],
      :tf_iteration => [],
      :tf_story => [],
      :excluded => type_names
    }, configuration)
  end
  
  def assert_mql(expected_mql, filters)
    actual_mql = CardQuery::And.new(*filters.as_card_query_conditions).to_s
    assert_equal expected_mql.downcase, actual_mql.downcase
  end  

  def assert_found_card_names(expected_card_names, filters)
    queries = filters.as_card_query_conditions
    assert_equal expected_card_names, CardQuery.new(:conditions => CardQuery::And.new(*queries)).find_cards.collect(&:name).sort
  end  
end
