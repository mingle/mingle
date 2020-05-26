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

require File.expand_path(File.dirname(__FILE__) + '/../functional_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class CardTypesControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree
  include ::RenderableTestHelper::Functional

  def setup
    @controller = create_controller(CardTypesController, :own_rescue_action => true)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @proj_admin = User.find_by_login('proj_admin')
    @project = create_project :admins => [@proj_admin]
    login_as_proj_admin
  end
  
  def test_list_card_types
    get :list, :project_id => @project.identifier
    assert_response :success
    assert_card_type_exist @project.card_types.first.name
    assert_selected_project_admin_menu 'Card types'
  end
  
  def test_should_show_card_type_usages_in_list
    defect = @project.card_types.create(:name => 'defect')
    setup_property_definitions :status => ['closed']
    defect.add_property_definition @project.find_property_definition('status')
    create_card! :name => 'This is a first defect', :card_type => defect
    get :list, :project_id => @project.identifier
    
    assert_select "li#card_type_#{defect.id} td[name=usage]",{:text => "1 property, 1 card, 0 card trees"}
  end
  
  def test_create_card_type
    post :create, :project_id => @project.identifier, :card_type => {:name => 'Story'}
    assert_response :redirect
    follow_redirect
    assert_notice 'Card Type <b>Story</b> was successfully created'
    assert_card_type_exist 'Story'
  end
  
  def test_update_card_type
    story = @project.card_types.create(:name => 'Story')
    post :update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'Defect'}
    assert_response :redirect
    follow_redirect
    assert_card_type_exist 'Defect'
    assert_card_type_not_exist 'Story'
  end
  
  def test_card_type_should_not_be_delete_when_it_is_the_last
    first_type = @project.card_types.first
    assert first_type.last?
    post :delete, :project_id => @project.identifier, :id => first_type
    follow_redirect
    assert_card_type_exist first_type.name
    assert_error "Card cannot be deleted because it is being used or is the last card type."
  end
  
  def test_update_color
    color_type = @project.card_types.create :name => 'color', :color => '#00ff00'
    post :update_color, :project_id => @project.identifier, :id => color_type.id, :color_provider_color => '#0000ff'
    assert_equal '#0000ff', color_type.reload.color
  end
  
  def test_appropriate_message_appears_when_no_custom_properties_exist
    get :new, :project_id => @project.identifier
    assert_response :success
    assert_select "input[type=checkbox]", false
    assert_select "p", :html => /^There are no card properties in this project/
  end
  
  def test_create_card_type_should_include_prop_defs
    setup_default_property_definitions
    post :create, :project_id => @project.identifier, :card_type => {:name => 'Story'}, :property_definitions => {@status.id => @status.id.to_s, @size.id => @size.id.to_s}, :property_definitions_order => property_definitions_order
    assert_equal 2, @project.card_types.find_by_name('Story').property_definitions.size
  end
  
  def test_create_card_type_should_not_save_card_type_if_property_definitions_are_faulty
    rescue_action_in_public!
    setup_default_property_definitions
    assert !@project.property_definitions.collect(&:id).include?(9999)
    post :create, :project_id => @project.identifier, :card_type => {:name => 'Story'}, :property_definitions => {9999 => '9999'},
                  :property_definitions_order => property_definitions_order(@project.property_definitions.first)
    assert_nil @project.card_types.find_by_name('Story')
  end
  
  def test_create_card_type_should_not_save_card_type_if_property_definition_orders_contain_invalid_prop_def_ids
    rescue_action_in_public!
    setup_default_property_definitions
    assert !@project.property_definitions.collect(&:id).include?(9999)
    post :create, :project_id => @project.identifier, :card_type => {:name => 'Story'}, :property_definitions => {@project.property_definitions.first.id => @project.property_definitions.first.id.to_s},
                  :property_definitions_order => ["reorder_container[]=9999"]
    assert_nil @project.card_types.find_by_name('Story')
  end
  
  def test_edit_card_type_page_should_check_the_exist_property_definitions
    setup_default_property_definitions
    story = @project.card_types.create(:name => 'Story')
    story.property_definitions = [@status, @size]
    story.save!
    get :edit, :project_id => @project.identifier, :id => story
    assert_checked "input[name='property_definitions[#{@status.id}]']", true
    assert_checked "input[name='property_definitions[#{@size.id}]']", true
    assert_checked "input[name='property_definitions[#{@iteration.id}]']", false
  end
  
  def test_should_order_property_definitions_available_to_card_type_by_position_and_other_project_property_definitions_by_name
    setup_default_property_definitions
    story = @project.card_types.create(:name => 'Story')
    story.property_definitions = [@size, @iteration]
    story.save!
    get :edit, :project_id => @project.identifier, :id => story
    assert_equal ['size', 'iteration', 'priority', 'release', 'status'], assigns(:prop_defs).collect(&:name)
  end
  
  def test_should_reorder_property_definition
    setup_default_property_definitions
    story = @project.card_types.create(:name => 'Story')
    post :update, 
      :project_id => @project.identifier, 
      :id => story, 
      :card_type => {:name => 'Story'}, 
      :property_definitions => {@size => @size.id.to_s, @status.id => @status.id.to_s, @iteration.id => @iteration.id.to_s},
      :property_definitions_order => property_definitions_order
    assert_equal ['status', 'iteration', 'size'], story.reload.property_definitions.collect(&:name)
  end
  
  def test_update_card_type_should_include_prop_defs
    setup_default_property_definitions
    story = @project.card_types.create(:name => 'Story')
    story.property_definitions = [@status, @size]
    story.save!
    post :update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'Story'}, :property_definitions => {@status.id => @status.id.to_s, @iteration.id => @iteration.id.to_s}, :property_definitions_order => property_definitions_order
    
    assert_equal 2, story.reload.property_definitions.size
    assert story.property_definitions.include?(@status)
    assert story.property_definitions.include?(@iteration)
    assert !story.property_definitions.include?(@size)
    
  end
  
  def test_update_card_type_name_and_remove_available_properties
    setup_default_property_definitions
    story = @project.card_types.create(:name => 'Story')
    story.property_definitions = [@status, @size]
    story.save!
    post :update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'another Story'}, :property_definitions => {},:property_definitions_order => property_definitions_order
    
    story.reload
    assert_equal 'another Story', story.name
    assert_equal 0, story.property_definitions.size
  end
  
  def test_confirm_update_card_type_skips_confirmation_if_not_removing_property_defs
    setup_default_property_definitions
    story = setup_card_type(@project, 'story', :properties => ['status', 'iteration'])
    post :confirm_update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'new story'},:property_definitions_order => property_definitions_order,
      :property_definitions => {'1' => @project.find_property_definition('iteration').id.to_s,
                                '2' => @project.find_property_definition('status').id.to_s}
    assert_redirected_to :action => 'list'
    assert_equal 'new story', story.reload.name
  end
  
  def test_confirm_update_does_not_skip_confirmation_when_removing_property_defs
    setup_default_property_definitions
    story = setup_card_type(@project, 'story', :properties => ['status', 'iteration'])
    post :confirm_update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'new story'},
      :property_definitions => {'1' => @project.find_property_definition('iteration').id}, :property_definitions_order => property_definitions_order
    assert_template 'card_types/confirm_update'
    assert_equal 'story', story.reload.name # no update yet 
  end
  
  def test_confirm_update_displays_proper_warnings_when_removing_property_defs
    setup_default_property_definitions
    story = setup_card_type(@project, 'STORY', :properties => ['status', 'iteration'])
    open_story = create_transition(@project, 'open story', :card_type => story, :set_properties => {:status => 'open'})
    post :confirm_update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'new story'},
      :property_definitions => {'1' => @project.find_property_definition('iteration').id.to_s },:property_definitions_order => property_definitions_order
    assert_select 'p', :html => /This update will remove property <b>status<\/b> from card type <b>STORY<\/b>./
    assert_select 'p', :html => /This update will delete transition <b>open story<\/b>/
  end
  
  def test_confirm_update_prompts_for_management_page_when_component_properties_are_unchecked
    component_property = setup_numeric_text_property_definition('component_property')
    some_formula = setup_formula_property_definition('some formula', 'component_property + 1')
    other_formula = setup_formula_property_definition('other formula', 'component_property + 2')
    another_formula = setup_formula_property_definition('another formula', '1 + 2')
    story = setup_card_type(@project, 'story', :properties => ['component_property', 'some formula', 'other formula', 'another formula'])
    
    post :confirm_update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'story'},
      :property_definitions => {'1' => some_formula.id.to_s, '2' => other_formula.id.to_s, '3' => another_formula.id.to_s}, 
      :property_definitions_order => property_definitions_order(some_formula, other_formula, another_formula)

    assert_select ".info-box", /cannot be updated because it is used by this project in the following areas:/
    assert_select ".info-box", /component_property is used as a component property of some formula. To manage some formula, please go to/
    assert_select ".info-box", /component_property is used as a component property of other formula. To manage other formula, please go to/
  end
  
  def test_confirm_update_shows_error_when_available_property_definitions_make_aggregate_invalid
    tree_config = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    tree_config.update_card_types({
      type_release => {:position => 0, :relationship_name => 'release'}, 
      type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      type_story => {:position => 2}
    })
    
    size = setup_numeric_text_property_definition('size')
    size.card_types = [type_story]
    size.save!
    
    some_agg = setup_aggregate_property_definition('some agg',
                                                    AggregateType::SUM,
                                                    size,
                                                    tree_config.id,
                                                    type_iteration.id,
                                                    type_story)
    
    
    post :confirm_update, :project_id => @project.identifier, :id => type_story, :card_type => {:name => 'new name'},
          :property_definitions_order => property_definitions_order(size)

    assert_not_nil blockings = assigns(:blockings)
    assert_equal 1, blockings.size
    assert_select '.info-box', :text => /new name cannot be updated because it is used by this project in the following areas:/
    assert_select "input[value='new name']"
  end
  
  def test_confirm_update_shows_error_when_available_property_definitions_make_aggregate_using_formula_invalid
    tree_config = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    tree_config.update_card_types({
      type_release => {:position => 0, :relationship_name => 'release'}, 
      type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      type_story => {:position => 2}
    })
    
    size = setup_numeric_text_property_definition('size')
    size.card_types = [type_story]
    size.save!
    
    john_formula = setup_formula_property_definition('john', 'size + 100')
    john_formula.card_types = [type_story]
    john_formula.save!
    
    some_agg = setup_aggregate_property_definition('some agg',
                                                    AggregateType::SUM,
                                                    john_formula,
                                                    tree_config.id,
                                                    type_iteration.id,
                                                    type_story)
    
    post :confirm_update, :project_id => @project.identifier, :id => type_story, :card_type => {:name => 'new name'},
         :property_definitions_order => property_definitions_order(size)
    
    assert_select '.info-box', :text => /new name cannot be updated because it is used by this project in the following areas:/
    assert_select "input[value='new name']"
  end
  
  def test_confirm_update_shows_error_in_one_descendant_case_when_available_property_definitions_make_all_descendants_aggregate_invalid
    tree_config = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    tree_config.update_card_types({
      type_release => {:position => 0, :relationship_name => 'release'}, 
      type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      type_story => {:position => 2}
    })
    
    size = setup_numeric_text_property_definition('size')
    size.card_types = [type_story]
    size.save!
    
    some_agg = setup_aggregate_property_definition('some agg',
                                                    AggregateType::SUM,
                                                    size,
                                                    tree_config.id,
                                                    type_iteration.id,
                                                    AggregateScope::ALL_DESCENDANTS)
    
    
    post :confirm_update, :project_id => @project.identifier, :id => type_story, :card_type => {:name => 'new name'},
        :property_definitions_order => property_definitions_order(size)

    assert_select '.info-box', :text => /new name cannot be updated because it is used by this project in the following areas:/
    assert_select "input[value='new name']"
  end
  
  def test_confirm_update_shows_in_many_descendants_case_error_when_available_property_definitions_make_all_descendants_aggregate_invalid
    tree_config = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    tree_config.update_card_types({
      type_release => {:position => 0, :relationship_name => 'release'}, 
      type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      type_story => {:position => 2}
    })
    
    size = setup_numeric_text_property_definition('size')
    size.card_types = [type_story]
    size.save!
    
    some_agg = setup_aggregate_property_definition('some agg',
                                                    AggregateType::SUM,
                                                    size,
                                                    tree_config.id,
                                                    type_release.id,
                                                    AggregateScope::ALL_DESCENDANTS)
    
    
    post :confirm_update, :project_id => @project.identifier, :id => type_story, :card_type => {:name => 'new name'},
         :property_definitions_order => property_definitions_order(size)
    
    assert_select '.info-box', :text => /new name cannot be updated because it is used by this project in the following areas:/
    assert_select "input[value='new name']"
  end
  
  # Bug 7048
  def test_card_types_unrelated_to_all_descendant_aggregates_can_add_property_definitions
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      type_unrelated = project.card_types.create!(:name => 'unrelated')
      
      cp_size = setup_numeric_text_property_definition('size')
      assert !cp_size.card_types.include?(type_unrelated)
      
      iteration_size = setup_aggregate_property_definition('iteration size', AggregateType::COUNT, nil, configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)
      
      post :update, :project_id => project.identifier, :id => type_unrelated, :card_type => {:name => 'unrelated'},
           :property_definitions => { cp_size.id.to_s => cp_size.id.to_s },
           :property_definitions_order => property_definitions_order(cp_size)
      
      assert_response :redirect
      assert cp_size.reload.card_types.include?(type_unrelated)
    end
  end
  
  # Bug 7048
  def test_non_target_property_definitions_can_be_removed_from_a_card_type_that_is_also_associated_to_an_all_descendants_aggregate
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      
      cp_size = setup_numeric_text_property_definition('size')
      cp_size.card_types = [type_iteration, type_story]
      cp_size.save!
      cp_estimate = setup_numeric_text_property_definition('estimate')
      cp_estimate.card_types = [type_iteration, type_story]
      cp_estimate.save!
      assert cp_estimate.card_types.include?(type_story)
      
      iteration_size = setup_aggregate_property_definition('iteration size', AggregateType::SUM, cp_size, configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)
      
      post :update, :project_id => project.identifier, :id => type_story, :card_type => { :name => type_story.name },
           :property_definitions => { cp_size.id.to_s => cp_size.id.to_s },
           :property_definitions_order => property_definitions_order(cp_size)
      
      assert_response :redirect
      assert !cp_estimate.reload.card_types.include?(type_story)
    end
  end
  
  # Bug 7048
  def test_should_allow_aggregate_target_property_definition_to_be_disassociated_from_card_type_if_another_descendant_card_type_also_has_the_property
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      
      cp_size = setup_numeric_text_property_definition('size')
      cp_size.card_types = [type_iteration, type_story]
      cp_size.save!
      assert cp_size.card_types.include?(type_story)
      
      iteration_size = setup_aggregate_property_definition('release size', AggregateType::SUM, cp_size, configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      
      post :update, :project_id => project.identifier, :id => type_story, :card_type => { :name => type_story.name }
      
      assert_response :redirect
      assert !cp_size.reload.card_types.include?(type_story)
    end
  end
  
  def test_update_removes_not_applicable_card_values_and_deletes_dependent_transitions
    setup_default_property_definitions
    story = setup_card_type(@project, 'story', :properties => ['priority', 'release', 'iteration'])
    
    card = @project.cards.create!(:name => 'a card', :card_type_name => 'story', :cp_release => '2')
    
    create_transition(@project, 'make story high', :card_type => story, :set_properties => {:priority => 'high'})
    create_transition(@project, 'make story release 1', :card_type => story, :set_properties => {:release => '1'})
    create_transition(@project, 'make story iteration 4', :card_type => story, :set_properties => {:iteration => '4'})
    
    post :update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'story'},
      :property_definitions => {'1' => @iteration.id.to_s}, :property_definitions_order => property_definitions_order
      
    assert_nil card.reload.cp_release   
    assert_equal ['make story iteration 4'], @project.reload.transitions.collect(&:name)
  end
  
  def test_update_removes_formula_property_definitions_that_rely_on_properties_being_removed
    component_property = setup_numeric_text_property_definition('component_property')
    some_formula = setup_formula_property_definition('some formula', 'component_property + 1')
    other_formula = setup_formula_property_definition('other formula', '1 + 2')
    
    story = setup_card_type(@project, 'story', :properties => ['component_property', 'some formula', 'other formula'])
    
    post :update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'story'},
      :property_definitions => {'1' => some_formula.id.to_s, '2' => other_formula.id.to_s}, 
      :property_definitions_order => property_definitions_order(some_formula, other_formula)
    
    assert_equal ['other formula'], story.reload.property_definitions.collect(&:name)
  end

  def test_edit_existing_card_defaults_with_redcloth_markup_will_edit_as_html_when_classic_is_deactivated
    card_type = @project.card_types.first
    card_type.create_card_defaults_if_missing
    defaults = card_type.card_defaults
    defaults.update_attributes(:description => "h1. I am a header", :redcloth => true)
    assert defaults.redcloth

    get :edit_defaults, :id => card_type, :project_id => @project.identifier
    assert_equal "<h1>I am a header</h1>", ckeditor_data
  end

  def test_should_get_rendered_contents_on_preview_post
    xhr :post, :preview, :id => @project.card_types.first.card_defaults.id, :card_defaults => {:description => '[[foo]]'}, :project_id => @project.identifier
    link_to_page_foo = "href=\"/projects/#{Project.current.identifier}/wiki/foo\""
    assert_match link_to_page_foo, @response.body
  end
  
  def test_update_removes_not_applicable_card_values_and_deletes_dependent_transitions
    story = nil
    create_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      setup_text_property_definition('text property')
      
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, 
         :card_defaults => {:description => 'First template description'}, :properties => {'text property' => 'hello'}

      assert_equal "First template description", story.reload.card_defaults.description
      assert_equal "hello", story.card_defaults.property_value_for('text property').db_identifier
    end
  end

  def test_update_card_default_should_escape_manual_macro
    create_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, :card_defaults => {:description => '{{ project }}'}
      assert_equal ManuallyEnteredMacroEscaper.new("{{ project }}").escape, story.reload.card_defaults.description
    end
  end

  def test_update_card_default_should_add_checklist_items
    create_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, :card_defaults => {:description => 'Some description', :checklist_items => %w(first second third)}
      assert_equal %w(first second third), story.reload.card_defaults.checklist_items.map(&:text)
      assert_equal [0, 1, 2], story.reload.card_defaults.checklist_items.map(&:position).sort
    end
  end

  def test_update_card_default_should_update_checklist_items
    create_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      story.card_defaults.set_checklist_items(%w(first second third))
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, :card_defaults => {:description => 'Some description', :checklist_items => %w(third new_item)}
      assert_equal %w(third new_item), story.reload.card_defaults.checklist_items.map(&:text)
      assert_equal [0, 1], story.reload.card_defaults.checklist_items.map(&:position).sort
    end
  end

  def test_update_card_default_should_remove_checklist_items_when_empty
    create_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      story.card_defaults.set_checklist_items(%w(first second third))
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults.id.to_s, :card_defaults => {:description => 'Some description'}
      assert_redirected_to :action => 'list'
      assert_equal 0, story.card_defaults.reload.checklist_items.count
    end
  end


  def test_update_card_default_should_preserve_macros_created_with_editor
    create_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, :card_defaults => {:description => create_raw_macro_markup("{{ project }}")}
      assert_equal "{{ project }}", story.reload.card_defaults.description
    end
  end

  def test_should_create_enum_values_when_defaults_are_updated_with_new_non_existent_values
    with_new_project(:admins => [@proj_admin]) do |p|
      story = p.card_types.create!(:name => 'Story')
      setup_property_definitions(:status =>[], :size => ['1'])
      
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, :properties => {'status' => 'open', 'size' => '8'}

      actual_statuses = p.find_property_definition('status').enumeration_values.collect(&:value).sort
      expected_statuses = ['open']
      assert_equal expected_statuses, actual_statuses
      
      actual_sizes = p.find_property_definition('size').enumeration_values.collect(&:value).sort
      expected_sizes = ['1', '8']
      assert_equal expected_sizes, actual_sizes
    end
  end  
  
  def test_update_defaults_should_not_save_enumeration_values_that_are_set_to_user_input_optional
    rescue_action_in_public!
    with_new_project do |p|
      story = p.card_types.create!(:name => 'Story')
      setup_property_definitions(:status =>[], :size => ['1'])
      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, :properties => {'status' => Transition::USER_INPUT_OPTIONAL, 'size' => '8'}
      
      status = p.find_property_definition('status')
      assert !status.contains_value?(Transition::USER_INPUT_OPTIONAL)
    end
  end
  
  def test_update_defaults_handles_property_errors
    story = nil
    project = create_project(:admins => [@proj_admin])
    project.with_active_project do |p|
      story = p.card_types.create!(:name => 'Story')
      setup_date_property_definition('date property')

      post :update_defaults, :project_id => p.identifier, :id => story.card_defaults, 
             :card_defaults => {:description => 'First template description'}, 
             :properties => {'date property' => 'hello'}
      assert_error
      assert "First template description" != story.reload.card_defaults.description      
    end
  end    
  
  # bug #2714
  def test_hidden_property_definition_should_shown_in_card_type_edit_page
    setup_default_property_definitions
    story = @project.card_types.create(:name => 'story')
    story.property_definitions = [@status, @size]
    story.save!
    @status.update_attribute(:hidden, true)
    @iteration.update_attribute(:hidden, true)
    get :edit, :project_id => @project.identifier, :id => story
    assert_select 'td', :text => @size.name
    assert_select 'td', :text => @iteration.name
    assert_select 'td', :text => @status.name
    assert_select 'tr[class=hidden-property]', true
    assert_checked "input[value=#{@status.id}]", true
  end
  
  def test_should_keep_system_properties_on_update
    create_planning_tree_project do |project, tree|
      setup_property_definitions(:status =>['open'], :size => [4])
      status_pd = project.property_definitions.detect{|pd|pd.name == 'status'}
      size_pd = project.property_definitions.detect{|pd|pd.name == 'size'}
      story = project.card_types.find_by_name('story')
      story.property_definitions += [status_pd, size_pd]
      story.save!

      assert_include 'Planning release', story.property_definitions.collect(&:name)
      assert_include 'Planning iteration', story.property_definitions.collect(&:name)
      
      post :update, :project_id => project.identifier, :id => story, 
        :card_type => {:name => 'another Story'}, :property_definitions => {status_pd.id => status_pd.id.to_s}, 
        :property_definitions_order => property_definitions_order(status_pd)
      assert_redirected_to :action => 'list'
      
      new_story = project.card_types.find_by_name('another Story')
      assert_include 'Planning release', new_story.property_definitions.collect(&:name)
      assert_include 'Planning iteration', new_story.property_definitions.collect(&:name)
      assert_include 'status', new_story.property_definitions.collect(&:name)
      assert_not_include 'size', new_story.property_definitions.collect(&:name)
    end
  end
  
  def test_should_not_allow_creation_of_card_type_that_has_a_formula_property_definition_but_not_its_components
    numeric_text = setup_numeric_text_property_definition('numeric_text')
    some_formula = setup_formula_property_definition('some formula', 'numeric_text + 1')
    
    post :create, :project_id => @project.identifier, :card_type => {:name => 'Story'}, :property_definitions => {some_formula.id => some_formula.id.to_s}, :property_definitions_order => property_definitions_order(numeric_text, some_formula)
    
    assert_error "The component property <b>numeric_text</b> should be available to all card types that formula property <b>some formula</b> is available to"
  end
  
  #for bug 2791
  def test_confirm_update_when_rename_card_type_to_a_name_has_been_taken_with_property_defs_ordered
    setup_default_property_definitions
    story = setup_card_type(@project, 'story', :properties => ['status', 'iteration'])
    defect = @project.card_types.create(:name => 'Defect')
    post :confirm_update, :project_id => @project.identifier, :id => story, :card_type => {:name => 'Defect'},:property_definitions_order => property_definitions_order,
      :property_definitions => {'1' => @project.find_property_definition('iteration').id.to_s,
                                '2' => @project.find_property_definition('status').id.to_s}
    assert_response :success
    assert_template 'edit'
    assert_error "Name has already been taken"
  end

  def test_should_only_show_property_definitions_that_type_as_in_edit_default_page
    type_release, type_iteration, type_story = init_planning_tree_types
    tree = create_three_level_tree
    planning_iteration = @project.find_property_definition('Planning iteration')
    planning_release = @project.find_property_definition('Planning release')
    aggregate_story_count_for_release = setup_aggregate_property_definition('story count for release', AggregateType::COUNT, nil, tree.configuration.id, type_release.id, type_story)

    get :edit_defaults, :id => type_iteration, :project_id => @project.identifier
    assert_response :success

    assert_select "span[id=defaults_#{planning_release.html_id}_label]", :text => 'Planning release'
    assert_select "span[id=defaults_#{planning_iteration.html_id}_label]", false
    assert_select "span[id=defaults_#{aggregate_story_count_for_release.html_id}_label]", false

    get :edit_defaults, :id => type_release, :project_id => @project.identifier
    assert_response :success
    assert_select "span[id=defaults_#{planning_iteration.html_id}_label]", false
    assert_select "span[id=defaults_#{planning_release.html_id}_label]", false
    assert_select "span[id=defaults_#{aggregate_story_count_for_release.html_id}_label]", aggregate_story_count_for_release.name
  end

  def test_should_create_new_card_defaults_if_none_exist
    card_type = @project.card_types.first
    card_type.card_defaults.destroy
    assert_nil(card_type.card_defaults)
    get :edit_defaults, :id => card_type, :project_id => @project.identifier
    assert_response :success
    assert_select "h1", "Edit '#{card_type.name}' defaults"
  end
  
  def test_that_aggregates_remain_on_card_type_during_update
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      
      size = setup_numeric_text_property_definition('size')
      size.card_types = [type_iteration, type_story]
      size.save!
      
      iteration_size = setup_aggregate_property_definition('iteration size',
                                                            AggregateType::SUM,
                                                            size,
                                                            configuration.id,
                                                            type_iteration.id,
                                                            type_story)
      
      post :update, :project_id => project.identifier, :id => type_iteration, :card_type => {:name => 'Iteration'},
           :property_definitions => { size.id.to_s => size.id.to_s },
           :property_definitions_order => property_definitions_order(size)
      
      assert_equal ['Iteration'], iteration_size.card_types.collect(&:name)
    end
  end
  
  # bug 5337
  def test_that_checked_property_definitions_stay_checked_after_error_on_create
    setup_default_property_definitions
    existing_card_type_name = @project.card_types.first.name
    
    post :create, :project_id => @project.identifier, :card_type => {:name => existing_card_type_name}, :property_definitions => {@status.id => @status.id.to_s, @size.id => @size.id.to_s}, :property_definitions_order => property_definitions_order
    
    assert_response :success
    assert_template 'new'
    assert_error "Name has already been taken"
    
    assert_checked "input[name='property_definitions[#{@status.id}]']", true
    assert_checked "input[name='property_definitions[#{@size.id}]']", true
    assert_checked "input[name='property_definitions[#{@iteration.id}]']", false
  end
  
  def test_checked_property_definitions_stay_checked_after_update_fails
    setup_default_property_definitions
    empty_name = ''
    card_type = @project.card_types.first
    
    post :update,
      :project_id => @project.identifier,
      :id => card_type,
      :card_type => {:name => empty_name},
      :property_definitions => { @size => @size.id.to_s, @status.id => @status.id.to_s },
      :property_definitions_order => property_definitions_order
    
    assert_response :success
    assert_template 'edit'
    assert_error "Name can't be blank"
    
    assert_checked "input[name='property_definitions[#{@status.id}]']", true
    assert_checked "input[name='property_definitions[#{@size.id}]']", true
    assert_checked "input[name='property_definitions[#{@iteration.id}]']", false
  end
  
  def test_should_not_block_removing_one_property_from_card_type_A_when_property_is_only_used_with_card_type_B
    type_A = @project.card_types.create(:name => 'A')
    type_B = @project.card_types.create(:name => 'B')
    setup_property_definitions :status => ['closed']
    status = @project.find_property_definition('status')
    type_A.add_property_definition status
    type_B.add_property_definition status
    type_A.save
    type_B.save
    @project.card_list_views.create_or_update({:view => {:name => "view"}, :filters => ['[type][is][B]', '[status][is][closed]']})
    post :confirm_update, 
         :project_id => @project.identifier, 
         :id => type_A, 
         :card_type => {:name => 'A'}, 
         :property_definitions_order => property_definitions_order(status)
    assert_select 'p', :html => /This update will remove property/
  end

  def test_should_add_card_type_name_field_for_edit_defaults
    card_type = @project.card_types.first
    card_type.create_card_defaults_if_missing

    get :edit_defaults, :id => card_type, :project_id => @project.identifier
    assert_select '#card_type_name_field[value=?]', card_type.name
  end

  private
  
  def setup_default_property_definitions
    setup_property_definitions(:status =>['open'], :iteration => ['1', '2', '3', '4'], :size => [4], :priority => ['low', 'high'], :release => ['1','2'])
    @status = @project.find_property_definition('status')
    @size = @project.find_property_definition('size')
    @iteration = @project.find_property_definition('iteration')
  end
  
  def assert_card_type_exist(type)
    assert_select 'td', :text => type
  end
  
  def assert_card_type_not_exist(type)
    assert_select 'td', {:text => type, :count => 0}
  end
  
  def property_definitions_order(*properties)
    properties = [@status, @iteration, @size] if properties.empty?
    [properties.map { |property| "reorder_container[]=#{property.id}" }.join('&')]
  end
end
