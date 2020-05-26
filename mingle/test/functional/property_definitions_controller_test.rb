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

class PropertyDefinitionsControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @controller = create_controller PropertyDefinitionsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @first_user = User.find_by_login('first')
    @proj_admin = User.find_by_login('proj_admin')
    @project = create_project :users => [@first_user], :admins => [@proj_admin]
    login_as_proj_admin
  end

  def test_index_should_list_all_properties_including_hidden_properties
    @project.create_text_list_definition!(:name => 'feature')
    @project.create_text_list_definition!(:name => 'old_type', :hidden => true)
    @project.create_text_list_definition!(:name => 'status', :hidden => true)
    get :index, :project_id  => @project.identifier
    assert_text_present 'feature', 'status', 'old_type'
  end

  def test_if_no_properties_in_project_no_properties_flash_should_show_up
    @project.all_property_definitions.destroy_all
    get :index, :project_id  => @project.identifier
    assert_text_present "There are currently no card properties to list."
  end

  def test_property_descriptions_should_be_shown
    @project.create_text_list_definition!(:name => 'feature',:description => 'desc for feature property')
    get :index, :project_id  => @project.identifier
    assert_text_present  'desc for feature property'
  end

  def test_create_new_property_definition
    post :create, :project_id  => @project.identifier, :property_definition => {:name => 'status', :description => 'desc the status property' }
    post :create, :project_id  => @project.identifier, :property_definition => {:name => 'iteration', :description => 'desc the iteration property' }
    post :create, :project_id  => @project.identifier, :property_definition => {:name => 'old_type', :description => 'desc the old_type property' }
    assert_redirected_to :action => 'index'
    assert @response.has_flash_object?(:notice)

    follow_redirect
    ['status', 'iteration', 'old_type'].each do |property_def|
      assert_text_present property_def, "desc the #{property_def} property"
    end
  end

  def test_create_new_card_relationship_property_definition
    post :create, :project_id  => @project.identifier, :definition_type => 'card relationship', :property_definition => {:name => 'timmy', :description => 'desc timmy' }
    assert_redirected_to :action => 'index'
    assert @response.has_flash_object?(:notice)

    follow_redirect
    assert_text_present "Any card"
    assert_select "div.notes", :text => 'desc timmy (Card)'
  end

  def test_all_card_types_should_select_as_default_when_create_new_property_definition
    @project.card_types.create(:name => 'Story')
    get :new, :project_id => @project.identifier
    @project.card_types.each do |card_type|
      assert_checked "input#card_types_#{card_type.id}"
    end
  end

  def test_new_formula_property_definition_should_use_null_is_zero_checkbox
    get :new, :project_id => @project.identifier
    assert_select "#formula-input input[type=checkbox]"
  end

  def test_create_formula_property_with_null_is_zero_checked
    post :create, :project_id  => @project.identifier, :definition_type => 'formula', :property_definition => {:name => 'my formula', :description => '', :null_is_zero => true, :formula => '2+2' }
    assert @project.all_property_definitions.find_by_name('my formula').null_is_zero?
  end

  def test_create_formula_property_with_null_is_zero_unchecked
    post :create, :project_id  => @project.identifier, :definition_type => 'formula', :property_definition => {:name => 'my formula', :description => '', :formula => '2+2' }
    assert !@project.all_property_definitions.find_by_name('my formula').null_is_zero?
  end

  def test_create_new_property_definition_with_card_types
    card_type1 = @project.card_types.create :name => 'this type is for status'
    card_type2 = @project.card_types.create :name => 'this is another type for status'
    post :create, :project_id  => @project.identifier, :property_definition => {:name => 'status'}, :card_types => {1 => card_type1, 2 => card_type2}
    assert_redirected_to :action => 'index'
    assert @response.has_flash_object?(:notice)
    @project.all_property_definitions.reload
    status_prop_def = @project.find_property_definition 'status'

    assert_equal 2, status_prop_def.card_types.length
    assert status_prop_def.card_types.include?(card_type1)
    assert status_prop_def.card_types.include?(card_type2)
    assert_equal [status_prop_def], card_type1.reload.property_definitions
    assert_equal [status_prop_def], card_type2.reload.property_definitions
  end

  def test_update_property_with_card_types
    card_type1 = @project.card_types.create :name => 'this type is for status'
    card_type2 = @project.card_types.create :name => 'this is another type for status'
    status_prop_def = @project.create_text_list_definition!(:name => 'status')
    post :update, :project_id  => @project.identifier, :id => status_prop_def.id, :card_types => {1 => card_type1, 2 => card_type2}, :property_definition => {}
    assert_redirected_to :action => 'index'
    assert @response.has_flash_object?(:notice)

    status_prop_def.reload
    @project.all_property_definitions.reload

    assert_equal 2, status_prop_def.card_types.length
    assert status_prop_def.card_types.include?(card_type1)
    assert status_prop_def.card_types.include?(card_type2)
    assert_equal [status_prop_def], card_type1.reload.property_definitions
    assert_equal [status_prop_def], card_type2.reload.property_definitions
  end

  # bug 2275
  def test_update_property_with_invalid_name_should_maintain_selected_card_type_state
    card_type1 = @project.card_types.create :name => 'this type is for status'
    card_type2 = @project.card_types.create :name => 'this is another type for status'
    status_prop_def = @project.create_text_list_definition!(:name => 'status')

    post :update, :project_id  => @project.identifier, :id => status_prop_def.id, :property_definition => {:name => '[status#]'}, :card_types => {"#{card_type1.id}" => "#{card_type1.id}"}

    assert_error "Name should not contain '&amp;', '=', '#', '&quot;', ';', '[' and ']' characters".gsub(/'/, '&#39;')
    assert_tag :tag => 'input', :attributes => {:id => "card_types_#{card_type1.id}", :checked => "checked" }
    assert_tag :tag => 'input', :attributes => {:id => "card_types_#{card_type2.id}", :checked => false }
  end

  def test_create_new_text_property_definition
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'text property name'}, :definition_type => 'any text'
    assert_redirected_to :action => 'index'
    follow_redirect

    assert_text_present 'text property name'
    @project.all_property_definitions.reload
    assert @project.text_property_definitions_with_hidden.collect(&:name).include?('text property name')
  end

  def test_create_new_date_property_definition
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'date property name'}, :definition_type => 'date'

    assert_redirected_to :action => 'index'
    follow_redirect

    assert_text_present 'date property name'
    @project.all_property_definitions.reload
    assert @project.date_property_definitions_with_hidden.collect(&:name).include?('date property name')
  end

  def test_create_new_numeric_enumeration_property_definition
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'numeric enumeration property name'}, :definition_type => 'number list'

    assert_redirected_to :action => 'index'
    follow_redirect

    assert_text_present 'numeric enumeration property name'
    @project.all_property_definitions.reload
    property = @project.enum_property_definitions_with_hidden.detect {|property_definition| property_definition.name = 'numeric enumeration property name'}
    assert property.is_numeric
  end

  def test_create_new_numeric_text_property_definition
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'numeric text property name'}, :definition_type => 'any number'

    assert_redirected_to :action => 'index'
    follow_redirect

    assert_text_present 'numeric text property name'
    @project.all_property_definitions.reload
    property = @project.text_property_definitions_with_hidden.detect {|property_definition| property_definition.name = 'numeric text property name'}
    assert property.is_numeric
  end

  def test_create_new_formula_property_definition
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'formula property name', :formula => '2+2'},
    :definition_type => 'formula', :card_types => {'1' => @project.card_types.first}

    assert_redirected_to :action => 'index'
    follow_redirect

    assert_text_present 'formula property name'
    @project.all_property_definitions.reload
    property = @project.formula_property_definitions_with_hidden.detect {|property_definition| property_definition.name = 'formula property name'}
    assert_equal '2+2', property.attributes['formula']
  end

  def test_create_new_formula_property_definition_applies_formula_to_all_cards
    create_cards(@project, 3)

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'formula property name', :formula => '2+2'},
    :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}

    formula_property_definition = @project.reload.find_property_definition('formula property name')

    @project.cards.each { |card| assert_equal 4, formula_property_definition.value(card) }
  end

  # bug 3186
  def test_update_card_types_of_formula_property_definition
    @project.with_active_project do |project|
      size = setup_numeric_property_definition('size', [1, 2, 3])
      size_times_two = setup_formula_property_definition('size times two', 'size * 2')

      size.card_types = [project.card_types.first]
      size_times_two.card_types = []
      size_times_two.save!

      post :update, :project_id => project.identifier, :id => size_times_two.id, :property_definition => {:name => 'size times two'},
      :card_types => {'1' => project.card_types.first.id}

      assert_equal ["Card"], size_times_two.reload.card_types.collect(&:name)
    end
  end

  # bug 3427
  def test_update_card_types_and_formula_will_not_validate_the_new_formula_against_the_old_card_types_or_vice_versa
    bug_size = setup_numeric_property_definition('bugsize', [1, 2, 3])
    story_size = setup_numeric_property_definition('storysize', [1, 2, 3])

    bug_type = @project.card_types.create!(:name => 'bugtype')
    bug_type.update_attributes(:property_definitions => [bug_size])

    story_type = @project.card_types.create!(:name => 'storytype')
    story_type.update_attributes(:property_definitions => [story_size])

    size_times_two = setup_formula_property_definition('size times two', 'bugsize * 2')
    size_times_two.card_types = [bug_type]
    size_times_two.save!

    post :update, :project_id => @project.identifier, :id => size_times_two.id, :property_definition => {:name => 'size times two', :formula => 'storysize * 2'},
    :card_types => {'1' => story_type}

    assert_redirected_to :action => 'index'
    follow_redirect
    assert_select "div#flash", :text => /.*Property was successfully updated.*/
  end

  def test_update_formula_property_definition_applies_formula_to_all_cards
    definition = @project.with_active_project do |project|
      setup_formula_property_definition('formula definition', '3*2')
    end

    create_cards(@project, 3)

    post :update, :project_id => @project.identifier, :id => definition.id, :property_definition => {:formula => '2+2'},
    :card_types => {'1' => @project.card_types.first.id}

    @project.cards.each { |card| assert_equal 4, definition.value(card) }
  end

  #bug 3001
  def test_create_new_formula_property_definition_without_any_card_types_selected
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'formula property name', :formula => '2+2'},
    :definition_type => 'formula', :card_types => {}

    assert_redirected_to :action => 'index'
    follow_redirect
    assert_text_present 'formula property name'
  end

  def test_show_any_text_message_for_text_property_definition
    @project.with_active_project do |project|
      setup_text_property_definition('id')
      (1..4).each { |number| create_card!(:name => "card #{number}", :id => number.to_s) }
    end
    get :index, :project_id => @project.identifier
    assert_text_present 'Any text'
  end

  def test_edit_text_property_definition
    definition = @project.with_active_project do |project|
      definition = project.create_any_text_definition!(:name => 'text property definition', :description => 'this is our superawesome description')
      project.reload.update_card_schema
      definition
    end
    get :edit, :project_id => @project.identifier, :id => definition.id
    assert_tag :input, :attributes => {:type => 'text', :name => 'property_definition[name]', :value => 'text property definition'}

    post :update, :project_id => @project.identifier, :id => definition.id, :property_definition => {:name => 'text id', :description => 'different description'}
    follow_redirect
    @project.all_property_definitions.reload
    assert_text_present 'text id', 'different description'
    assert @project.text_property_definitions_with_hidden.collect(&:name).include?('text id')
  end

  def test_edit_formula_property_definitions
    formula_definition = @project.with_active_project do |project|
      project.create_formula_property_definition!(:name => 'formula property definition', :description => 'a description', :formula => '2 + 2')
    end

    get :edit, :project_id => @project.identifier, :id => formula_definition.id
    assert_select "input#property_definition_formula[value = '2 + 2']"
  end

  def test_edit_formula_property_definition_should_show_null_is_zero_checkbox
    formula_definition = @project.with_active_project do |project|
      project.create_formula_property_definition!(:name => 'formula property definition', :description => 'a description', :formula => '2 + 2', :null_is_zero => true)
    end

    get :edit, :project_id => @project.identifier, :id => formula_definition.id
    assert_select "input[type=checkbox][checked]#property_definition_null_is_zero"
  end

  def test_update_formula_property_definition_should_update_null_is_zero
    @project.with_active_project do |project|
      formula_definition = project.create_formula_property_definition!(:formula => '2 + 2', :null_is_zero => false, :name => 'formula property definition', :description => 'a description')
      post :update, :project_id => @project.identifier, :id => formula_definition.id, :property_definition => {:formula => '2 + 2', :null_is_zero => true, :name => 'formula property definition', :description => 'different description'}
      assert PropertyDefinition.find(formula_definition.id).null_is_zero?
      post :update, :project_id => @project.identifier, :id => formula_definition.id, :property_definition => {:formula => '2 + 2', :name => 'formula property definition', :description => 'different description'} #unchecked checkbox isn't sent by browser
      assert_false PropertyDefinition.find(formula_definition.id).null_is_zero?
    end
  end

  def test_edit_action_should_show_delete_link
    formula_definition = @project.with_active_project do |project|
      project.create_formula_property_definition!(:name => 'formula property definition', :description => 'a description', :formula => '2 + 2')
    end

    get :edit, :project_id => @project.identifier, :id => formula_definition.id
    assert_select "a.delete"
  end

  def test_editing_non_formula_property_definitions_will_not_display_formula_input_box
    text_definition = @project.with_active_project do |project|
      setup_text_property_definition('id')
    end

    get :edit, :project_id => @project.identifier, :id => text_definition.id
    assert_select "input#property_definition_formula", false
  end

  def test_creating_a_user_property_updates_card_schema_to_contain_a_reference_to_user_table
    post :create, :project_id => @project.identifier, :definition_type => "user", :property_definition => {:name => 'owner', :description => "who owns you?"}
    assert_redirected_to :action => 'index'
    assert @response.has_flash_object?(:notice)

    follow_redirect
    assert_text_present 'owner'
    assert_text_present "who owns you?"
    assert Card.columns.collect(&:name).include?('cp_owner_user_id')
  end

  def test_error_on_create_redirect_user_to_new_action_and_show_error
    post :create, :project_id  => @project.identifier, :property_definition => {:description => 'desc the status property' }
    assert_error "Name can't be blank".gsub(/'/, '&#39;')
    assert_template 'new'
    assert_text_present 'desc the status property'
  end

  def test_should_not_allow_a_definition_type_that_mingle_doesnt_understand
    assert_raise NoMethodError do
      post :create, :project_id  => @project.identifier, :property_definition => {:description => 'desc the status property' }, :definition_type => 'boo'
    end
  end

  def test_property_definition_rename
    setup_property_definitions :status => ['new', 'open'], :iteration => []
    status = @project.find_property_definition('status')
    post :update, :project_id => @project.identifier, :id => status.id,
    :property_definition => {:name => 'condition', :description => "how we're doing"},
    :card_types => {'1' => @project.find_card_type('card').id}
    assert @response.has_flash_object?(:notice)

    get :index, :project_id  => @project.identifier
    assert_text_present 'condition'
    assert_equal ['new', 'open'], @project.reload.find_property_definition('condition').enumeration_values.collect(&:value)
  end

  def test_property_definition_rename_fails_without_name
    setup_property_definitions :status => ['new', 'open'], :iteration => []
    status = @project.find_property_definition('status')
    post :update, :project_id => @project.identifier, :id => status.id,
    :property_definition => {:name => '', :description => "how we're doing"}
    assert_error
    assert_equal ['new', 'open'], @project.reload.find_property_definition('status').enumeration_values.collect(&:value)
  end

  # bug 10348
  def test_rename_property_definition_used_in_formula_updates_even_with_extra_whitespace_in_formula_definition
    dev_estimate_property = setup_numeric_text_property_definition('developer estimate')
    qa_estimate_property = setup_numeric_text_property_definition('qa estimate')
    total_estimate_property = setup_formula_property_definition('total estimate', "' developer estimate ' + 'qa estimate'")

    post :update, :project_id => @project.identifier, :id => dev_estimate_property.id,
    :property_definition => {:name => 'dev estimate' }

    assert_equal "('dev estimate' + 'qa estimate')", total_estimate_property.reload.formula.to_s
  end

  def test_should_not_find_hidden_property_after_hide_it
    setup_property_definitions :status => ['new', 'fixed']
    post :hide, :project_id => @project.identifier, :name => 'status'
    assert_nil @project.reload.find_property_definition_or_nil('status')
    post :unhide, :project_id => @project.identifier, :name => 'status'
    assert @project.reload.find_property_definition_or_nil('status')
  end

  def test_should_destroy_saved_views_used_property_def_when_hide_the_property_def
    setup_property_definitions :status => ['new', 'fixed'], :iteration => ['1']

    @project.card_list_views.create_or_update(:view => {:name => 'view should not been removed'}, :style => 'list', :filters => ["[iteration][is][1]"])
    @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :lanes => 'new', :group_by => 'status')
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 2'}, :style => 'grid', :group_by => 'status')
    view.update_attribute :tab_view, true
    @project.reload

    post :hide, :project_id => @project.identifier, :name => 'status'

    assert_equal 1, @project.card_list_views.size
    assert_equal 'view should not been removed', @project.card_list_views[0].name
  end

  def test_should_not_escape_view_names_in_hide_success_message
    setup_property_definitions :status => ['new', 'fixed']
    @project.card_list_views.create_or_update(:view => { :name => '<h1>some view</h1>' }, :style => 'grid', :lanes => 'new', :group_by => 'status')

    post :hide, :project_id => @project.identifier, :name => 'status'
    assert_match "The following favorites have been deleted: <h1>some view</h1>.", flash[:notice]
  end

  def test_create_failure_message_should_be_html_escaped
    formula_with_html_tag = '<h1>foo'
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'formula', :formula => formula_with_html_tag },
    :definition_type => 'formula', :card_types => {'1' => @project.card_types.first}
    assert_match formula_with_html_tag.escape_html, flash[:error]
  end

  def test_update_failure_message_should_be_html_escaped
    definition = @project.with_active_project do |project|
      project.create_formula_property_definition!(:name => 'formula property definition', :description => 'a description', :formula => '2 + 2')
    end

    formula_with_html_tag = '<h1>foo'
    post :update, :project_id => @project.identifier, :id => definition.id, :property_definition => { :formula => formula_with_html_tag },
    :card_types => {'1' => @project.card_types.first.id}
    assert_match formula_with_html_tag.escape_html, flash[:error]
  end

  def test_should_flash_error_when_hide_an_hidden_property_definition
    setup_property_definitions :status => ['new', 'fixed']
    post :hide, :project_id => @project.identifier, :name => 'status'
    assert_raise(RuntimeError){post :hide, :project_id => @project.identifier, :name => "status"}
  end

  def test_should_show_correct_checkbox_value_according_to_property_definitions_hidden_status
    setup_property_definitions :Material => ['sand', 'gold']
    material = @project.find_property_definition('Material')
    get :index, :project_id => @project.identifier
    assert_select "input#visibility-#{material.id}[checked]", false

    post :hide, :project_id => @project.identifier, :name => 'Material'
    assert_redirected_to :action => :index
    get :index, :project_id => @project.identifier, :include_hidden => 'true'
    assert_select "input#visibility-#{material.id}[checked]"
  end

  def test_should_show_correct_property_type_to_user
    setup_property_definitions :material => []
    setup_numeric_property_definition 'Release', []
    setup_numeric_text_property_definition 'Estimate'
    setup_user_definition 'Owner'
    owner = @project.find_property_definition('owner')
    material = @project.find_property_definition('material')
    get :edit, :project_id => @project.identifier, :id => owner.id
    assert_text_present 'Automatically generated from the team list'

    @controller = PropertyDefinitionsController.new
    get :edit, :project_id => @project.identifier, :id => material.id
    assert_text_present 'Managed text list'

    @controller = PropertyDefinitionsController.new
    release = @project.find_property_definition('Release')
    get :edit, :project_id => @project.identifier, :id => release.id
    assert_text_present 'Managed number list'

    @controller = PropertyDefinitionsController.new
    estimate = @project.find_property_definition('Estimate')
    get :edit, :project_id => @project.identifier, :id => estimate.id
    assert_text_present 'Any number'
  end

  def test_lock_and_unlock_property_even_it_is_hidden
    setup_property_definitions :status => ['new', 'fixed']
    status = @project.find_property_definition('status')
    go_to_test_lock_and_unlock_property_with(status)

    status.update_attribute(:hidden, true)
    go_to_test_lock_and_unlock_property_with(status)
  end

  def go_to_test_lock_and_unlock_property_with(property)
    xhr :post, :toggle_restricted, :project_id => @project.identifier, :id => property.id
    assert_notice
    assert property.reload.restricted?

    xhr :post, :toggle_restricted, :project_id => @project.identifier, :id => property.id
    assert_notice
    assert !property.reload.restricted?
  end

  def test_toggle_transition_only
    setup_property_definitions :status => ['new', 'open']
    status = @project.find_property_definition('status')
    assert !status.transition_only

    xhr :post, :toggle_transition_only, :project_id => @project.identifier, :id => status.id
    assert_notice
    assert status.reload.transition_only
    get :index, :project_id => @project.identifier
    assert_select "input#transitiononly-#{status.id}[checked]"

    xhr :post, :toggle_transition_only, :project_id => @project.identifier, :id => status.id
    assert_notice
    assert !status.reload.transition_only
    get :index, :project_id => @project.identifier
    assert_select "input#transitiononly-#{status.id}[checked]", false
  end

  def test_confirm_update_prop_def_skips_confirmation_if_not_removing_card_types
    setup_property_definitions(:status => ['new', 'open'])
    status = @project.find_property_definition('status')
    story = setup_card_type(@project, 'story', :properties => ['status'])
    bug = setup_card_type(@project, 'bug', :properties => ['status'])
    post :confirm_update, :project_id => @project.identifier, :id => status, :property_definition => {:name => 'new status'},
    :card_types => {'1' => story.id, '2' => bug.id, '3' => @project.find_card_type('card').id}
    assert_redirected_to :action => 'index'
    assert_equal 'new status', status.reload.name
  end

  def test_confirm_update_does_not_skip_confirmation_when_removing_card_types
    setup_property_definitions(:status => ['new', 'open'])
    status = @project.find_property_definition('status')
    story = setup_card_type(@project, 'story', :properties => ['status'])
    bug = setup_card_type(@project, 'bug', :properties => ['status'])
    post :confirm_update, :project_id => @project.identifier, :id => status, :property_definition => {:name => 'new status'},
    :card_types => {'1' => @project.find_card_type('card').id}

    assert_template 'property_definitions/confirm_update'
    assert_equal 'status', status.reload.name
  end

  def test_confirm_update_displays_proper_warnings_when_removing_card_types
    setup_property_definitions(:status => ['new', 'open'])
    status = @project.find_property_definition('status')
    story = setup_card_type(@project, 'story', :properties => ['status'])
    bug = setup_card_type(@project, 'bug', :properties => ['status'])
    open_story = create_transition(@project, 'open bug', :card_type => bug, :set_properties => {:status => 'open'})
    post :confirm_update, :project_id => @project.identifier, :id => status, :property_definition => {:name => 'new status'},
    :card_types => {'1' => story.id, '2' => @project.find_card_type('card').id}
    assert_select 'p', /This update will remove card type bug from property status/
    assert_select 'p', /Any cards that are currently of type bug will no longer have values for status/
    assert_select 'p', /This update will delete transition open bug/
  end

  def test_confirm_update_displays_blockings_of_affected_formula_caused_by_the_update
    dev_size = setup_numeric_text_property_definition('dev size')
    dave_size = setup_formula_property_definition('dave size', "3 * 'dev size'")
    dan_size = setup_formula_property_definition('dan size', "4 * 'dev size'")

    story = setup_card_type(@project, 'story', :properties => ['dev size', 'dave size'])
    bug = setup_card_type(@project, 'bug', :properties => ['dev size', 'dave size', 'dan size'])
    task = setup_card_type(@project, 'task', :properties => ['dev size', 'dan size'])

    post :confirm_update, :project_id => @project.identifier, :id => dev_size, :property_definition => {:name => 'dev size'},
    :card_types => {'1' => story.id, '2' => @project.find_card_type('card').id}
    assert_select "p", /Property dev size cannot be updated:/
    assert_select "div[class=flash-content] li", /#{dev_size.name} is used as a component property of #{dan_size.name}. To manage #{dan_size.name}, please go to/
    assert_select "div[class=flash-content] li", /#{dev_size.name} is used as a component property of #{dave_size.name}. To manage #{dave_size.name}, please go to/
  end

  def test_should_not_update_formulae_in_order_to_show_blockings_caused_by_formula_property_usage
    dev_size = setup_numeric_text_property_definition('dev size')
    dave_size = setup_formula_property_definition('dave size', "3 * 'dev size'")

    story = setup_card_type(@project, 'story', :properties => ['dev size', 'dave size'])

    post :confirm_update, :project_id => @project.identifier, :id => dev_size, :property_definition => {:name => 'mike size'},
    :card_types => {}
    assert_rollback
    assert_select "p", /Property mike size cannot be updated:/
  end

  def test_case_name

  end

  def test_confirm_update_shows_error_when_available_card_types_make_aggregate_invalid
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


    post :confirm_update, :project_id => @project.identifier, :id => size, :property_definition => {:name => 'size', :description => "new description"}, :card_types => {"1" => type_release.id}

    assert_select 'p', :text => "Property size cannot be updated:"
    assert_select 'div[class=flash-content] li', :text => "size is used as the target property of some agg. To manage some agg, please go to configure aggregate properties page."
    assert_select "input[value='new description']"
  end

  def test_confirm_update_shows_error_when_available_card_types_make_aggregate_on_formula_invalid
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


    post :confirm_update, :project_id => @project.identifier, :id => size, :property_definition => {:name => 'size', :description => "new description"}, :card_types => {"1" => type_release.id}

    assert_select 'p', :text => "Property size cannot be updated:"
    assert_select 'div[class=flash-content] li', :text => "size is used as a component property of john. To manage john, please go to card property management page."

    assert_select "input[value='new description']"
  end


  def test_confirm_update_shows_error_in_one_descendant_case_when_available_card_types_make_all_descendants_aggregate_invalid
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


    post :confirm_update, :project_id => @project.identifier, :id => size, :property_definition => {:name => 'size', :description => "new description"}, :card_types => {"1" => type_release.id}
    assert_select 'p', :text => "Property size cannot be updated:"
    assert_select 'div[class=flash-content] li', :text => "size is used as the target property of some agg. To manage some agg, please go to configure aggregate properties page."
    assert_select "input[value='new description']"
  end

  def test_confirm_update_shows_error_in_many_descendants_case_when_available_card_types_make_all_descendants_aggregate_invalid
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


    post :confirm_update, :project_id => @project.identifier, :id => size, :property_definition => {:name => 'size', :description => "new description"}, :card_types => {"1" => type_release.id}
    assert_select 'p', :text => "Property size cannot be updated:"
    assert_select 'div[class=flash-content] li', :text => "size is used as the target property of some agg. To manage some agg, please go to configure aggregate properties page."
    assert_select "input[value='new description']"
  end

  def test_confirm_delete_displays_bubbly_error_message_when_property_definition_is_used_in_formulas
    dev_size = setup_numeric_text_property_definition('dev size')
    dave_size = setup_formula_property_definition('dave size', "3 * 'dev size'")

    get :confirm_delete, :project_id => @project.identifier, :id => dev_size, :property_definition => {:name => 'dev size'},
    :card_types => {'1' => @project.find_card_type('card').id}

    assert_template 'deletion_blockings'
  end

  def test_confirm_delete_warns_that_plv_associations_will_be_removed
    cake = setup_text_property_definition('cake')
    treat = setup_text_property_definition('treat')
    best_cake = create_plv!(@project, :name => 'best cake', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'cheesecake', :property_definition_ids => [cake.id])
    best_treat = create_plv!(@project, :name => 'best treat', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'chocolate', :property_definition_ids => [cake.id, treat.id])

    get :confirm_delete, :project_id => @project.identifier, :id => treat.id, :property_definition => {:name => 'treat'},
    :card_types => {'1' => @project.find_card_type('card').id}
    assert_select "li", :text => "Used by 1 ProjectVariable: best treat. This will be disassociated."

    get :confirm_delete, :project_id => @project.identifier, :id => cake.id, :property_definition => {:name => 'cake'},
    :card_types => {'1' => @project.find_card_type('card').id}
    assert_select "li", :text => "Used by 2 ProjectVariables: best cake and best treat. These will be disassociated."
  end

  def test_update_removes_not_applicable_card_values_and_deletes_dependent_transitions
    setup_property_definitions(:priority => ['low', 'high'], :release => ['1', '2'])
    priority = @project.find_property_definition('priority')
    story = setup_card_type(@project, 'story', :properties => ['priority', 'release'])
    bug = setup_card_type(@project, 'bug', :properties => ['priority', 'release'])
    issue = setup_card_type(@project, 'issue', :properties => ['priority', 'release'])

    card = @project.cards.create!(:name => 'a card', :card_type_name => 'story', :cp_priority => 'low', :cp_release => '2')

    create_transition(@project, 'make story high', :card_type => story, :set_properties => {:priority => 'high'})
    create_transition(@project, 'make bug high', :card_type => bug, :set_properties => {:priority => 'high'})
    create_transition(@project, 'make issue high', :card_type => issue, :set_properties => {:priority => 'high'})

    post :update, :project_id => @project.identifier, :id => priority, :property_definition => {:name => 'priority'},
    :card_types => {'1' => issue}

    assert_nil card.reload.cp_priority
    assert_equal '2', card.cp_release
    assert_equal ['make issue high'], @project.reload.transitions.collect(&:name)
  end

  def test_should_set_formula_values_to_zero_when_removing_the_applicability_of_a_formula_to_a_particular_card_type
    size = setup_numeric_property_definition('size', ['1', '2', '3'])
    twice_size = setup_formula_property_definition('twice-size', ' 2 * size')
    half_size = setup_formula_property_definition('half-size', 'size /2')

    story_type = setup_card_type(@project, 'story', :properties => ['size', 'twice-size', 'half-size'])
    bug_type = setup_card_type(@project, 'bug', :properties => ['size', 'half-size'])
    @project.card_types.find_by_name('Card').destroy

    bug = @project.cards.create!(:name => 'Bug', :card_type_name => 'bug', :cp_size => '2')
    story = @project.cards.create!(:name => 'Story', :card_type_name => 'story', :cp_size => '2')

    post :update, :project_id => @project.identifier, :id => half_size, :property_definition => {:name => 'half-size'}, :card_types => {'1' => bug_type.id}

    assert_nil half_size.value(story.reload)
  end

  def test_update_can_rename_property_and_remove_card_types_in_single_transaction
    setup_property_definitions(:priority => ['low', 'high'], :release => ['1', '2'])
    priority = @project.find_property_definition('priority')
    story = setup_card_type(@project, 'story', :properties => ['priority', 'release'])
    issue = setup_card_type(@project, 'issue', :properties => ['priority', 'release'])

    card = @project.cards.create!(:name => 'a card', :card_type_name => 'story', :cp_priority => 'low', :cp_release => '2')

    post :update, :project_id => @project.identifier, :id => priority, :property_definition => {:name => 'all new priority'},
    :card_types => {'1' => issue}

    assert_nil card.reload.cp_priority
    assert_equal '2', card.cp_release
    assert_equal 'all new priority', priority.reload.name
    assert_equal ['issue'], priority.card_types.collect(&:name)
  end

  def test_any_numeric_property_definitions_should_display_any_numbers_as_property_values
    setup_numeric_text_property_definition 'Size'
    size = @project.find_property_definition('Size')
    get :index, :project_id => @project.identifier
    assert_text_present 'Any number'
  end

  def test_should_be_able_to_change_formula_for_a_property_that_involves_negative_numbers
    setup_numeric_text_property_definition 'free number'
    formula_prop_def = setup_formula_property_definition 'thrice free', "3 * ('free number')"

    post :update, :project_id => @project.identifier, :id => formula_prop_def.id, :property_definition => {:name => 'thrice free', :formula => "-3 * ('free number')"}, :card_types => {'1' => @project.card_types.first}

    @project.reload
    assert_equal "(-3 * ('free number'))", @project.find_property_definition('thrice free').formula.to_s
  end

  def test_should_not_throw_exception_when_numeric_free_text_subtracted_from_date
    setup_date_property_definition 'startdate'
    setup_numeric_text_property_definition 'numerictext'

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'startdate minus numerictext', :formula => "startdate - numerictext"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
  end

  def test_should_create_property_when_numeric_list_added_to_date
    setup_date_property_definition 'startdate'
    setup_numeric_property_definition 'numericlist', [1, 2, 3]

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'startdate plus numericlist', :formula => "startdate + numericlist"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}

    assert_redirected_to :action => 'index'
    @project.all_property_definitions.reload
    assert_equal ['numericlist', 'startdate', 'startdate plus numericlist'], @project.property_definitions_in_smart_order.collect(&:name)
  end

  def test_should_not_allow_creation_of_a_formula_property_with_numeric_types_that_are_not_valid_across_all_its_card_types
    story_type = @project.card_types.create! :name => "Story"
    bug_type = @project.card_types.create! :name => "Bug"

    bug_size = setup_numeric_text_property_definition('bug size')
    bug_size.update_attributes(:card_types => [bug_type])

    story_size = setup_numeric_text_property_definition('story size')
    story_size.update_attributes(:card_types => [story_type])

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'twice story size', :formula => "2 * ('story size')"}, :definition_type => 'formula', :card_types => {'1' => story_type.id, '2' => bug_type.id}

    error = Regexp.escape("The component property should be available to all card types that formula property is available to.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)
  end

  def test_should_not_allow_creation_of_a_formula_property_that_subtracts_a_date_from_a_scalar
    setup_date_property_definition 'start date'
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'two minus start date', :formula => "2 - 'start date'"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}

    error = Regexp.escape("The expression <b>2 - 'start date'</b> is invalid because a date (<b>'start date'</b>) cannot be subtracted from a number (<b>2</b>). The supported operation is addition.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)
  end

  def test_should_not_allow_creation_of_a_formula_property_that_subtracts_a_date_from_an_expression_that_evaluates_to_a_scalar
    setup_date_property_definition 'start date'

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'two minus start date', :formula => "('start date' - 'start date') - 'start date'"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}

    error = Regexp.escape("The expression <b>('start date' - 'start date') - 'start date'</b> is invalid because a date (<b>'start date'</b>) cannot be subtracted from a number (<b>('start date' - 'start date')</b>). The supported operation is addition.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)
  end

  def test_should_not_allow_creation_of_a_formula_property_that_adds_multiplies_or_divides_two_dates
    setup_date_property_definition 'start date'
    setup_date_property_definition 'end date'

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'add', :formula => "'start date' + 'end date'"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("The expression <b>'start date' + 'end date'</b> is invalid because a date (<b>'start date'</b>) cannot be added to a date (<b>'end date'</b>). The supported operation is subtraction.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'mul', :formula => "'start date' * 'end date'"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("The expression <b>'start date' * 'end date'</b> is invalid because a date (<b>'start date'</b>) cannot be multiplied by a date (<b>'end date'</b>). The supported operation is subtraction.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'div', :formula => "'start date' / 'end date'"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("The expression <b>'start date' / 'end date'</b> is invalid because a date (<b>'start date'</b>) cannot be divided by a date (<b>'end date'</b>). The supported operation is subtraction.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)
  end

  def test_should_display_number_of_values_for_property_which_has_date_values
    setup_date_property_definition 'start date'
    setup_formula_property_definition('add', "'start date'")
    create_card!(:name => "card", "start date" => "10/10/10")

    get :index, :project_id  => @project.identifier

    assert_text_present 'add'
  end

  def test_should_not_allow_creation_of_a_formula_property_that_adds_multiplies_or_divides_two_expressions_that_result_in_dates
    setup_date_property_definition 'start date'
    setup_date_property_definition 'end date'

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'add', :formula => "'start date' + ('start date' - 2)"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("The expression <b>'start date' + ('start date' - 2)</b> is invalid because a date (<b>'start date'</b>) cannot be added to a date (<b>('start date' - 2)</b>). The supported operation is subtraction.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'mul', :formula => "'start date' * ('start date' - 2)"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("The expression <b>'start date' * ('start date' - 2)</b> is invalid because a date (<b>'start date'</b>) cannot be multiplied by a date (<b>('start date' - 2)</b>). The supported operation is subtraction.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)

    post :create, :project_id => @project.identifier, :property_definition => {:name => 'div', :formula => "'start date' / ('start date' - 2)"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("The expression <b>'start date' / ('start date' - 2)</b> is invalid because a date (<b>'start date'</b>) cannot be divided by a date (<b>('start date' - 2)</b>). The supported operation is subtraction.".gsub(/'/, '&#39;'))
    assert_error(/#{error}/)
  end

  def test_should_not_allow_a_formula_property_within_another_formulae
    setup_numeric_property_definition('size', ['2', '4'])
    setup_formula_property_definition('double size', 'size * 2')
    post :create, :project_id => @project.identifier, :property_definition => {:name => 'add', :formula => "'double size' * 2"}, :definition_type => 'formula', :card_types => {'1' => @project.card_types.first.id}
    error = Regexp.escape("Property <b>double size</b> is a formula property and cannot be used within another formula.")
    assert_error(/#{error}/)
  end

  def test_delete_should_remove_property_definition
    setup_numeric_property_definition('size', ['2', '4'])
    post :delete, :project_id => @project.identifier, :id => @project.find_property_definition('size').id
    assert_not_nil flash[:notice]
    assert_nil @project.reload.find_property_definition_or_nil('size')
  end

  def test_should_delete_personal_favorites_on_destroy_of_prop_def
    setup_numeric_property_definition('size', ['2', '4'])
    CardListView.find_or_construct(@project, :name => 'hello', :columns => 'size', :user_id => User.current.id)
    post :delete, :project_id => @project.identifier, :id => @project.find_property_definition('size').id
    assert_nil CardListView.find_by_name('hello')
  end

  def test_delete_should_trigger_project_health_check
    setup_numeric_property_definition('size', ['2', '4'])
    post :delete, :project_id => @project.identifier, :id => @project.find_property_definition('size').id
    assert_redirected_to :action => 'index'
  end

  def test_should_clear_project_cache_if_exception_thrown_during_create_property_definition
    project_from_cache = ProjectCacheFacade.instance.load_project(@project.identifier)
    ProjectCacheFacade.instance.cache_project(project_from_cache)
    def @controller.create
      raise 'bad thing happend'
    end
    assert_raise(RuntimeError) do
      post :create, :project_id  => @project.identifier, :property_definition => {:name => 'status'}
    end
    assert_object_id_not_equal project_from_cache, ProjectCacheFacade.instance.load_project(@project.identifier)
  end

  def test_edit_action_should_redirect_to_tree_aggregation_page_for_aggregate_property
    login_as_proj_admin
    with_three_level_tree_project do |project|
      sum_of_size_aggregate = project.find_property_definition('Sum of size')
      tree_configuration = sum_of_size_aggregate.tree_configuration
      get :edit, :project_id => project.identifier, :id => sum_of_size_aggregate.id
      assert_redirected_to  :controller => 'card_trees',
      :action => 'edit_aggregate_properties',
      :project_id => project.identifier,
      :id => tree_configuration.id,
      :popup_card_type_id => sum_of_size_aggregate.aggregate_card_type.id
    end
  end

  # bug 8453
  def test_should_clear_dependant_formulas_property_after_save
    setup_property_definitions :status => ['new', 'fixed']
    status = @project.find_property_definition('status')

    5.times do
      xhr :post, :toggle_restricted, :project_id => @project.identifier, :id => status.id
      assert_response :ok
    end

    value = @project.connection.select_value(SqlHelper::sanitize_sql("SELECT dependant_formulas FROM #{PropertyDefinition.table_name} WHERE #{@project.connection.quote_column_name 'id'} = ?", status.id))
    assert_nil value
  end

  def test_should_update_correct_values_when_creating_new_formula_property
    card_type = @project.card_types.first
    start = setup_date_property_definition('start')
    create_card!(:name => 'c1', :start => Date.parse("2013-01-01"))
    create_card!(:name => 'c2', :start => Date.parse("2014-01-01"))
    post :create, :project_id => @project.identifier, :definition_type => 'formula', :property_definition => {:name => 'end', :null_is_zero => false, :formula => 'start + 2' }, :card_types => { card_type.id.to_s => card_type }
    assert_response :redirect
    @project.reload

    assert_equal 'c2', CardQuery.parse('select name where end > "2014-01-01"').single_value
  end


  def test_values_should_return_all_values_of_a_property_definition
    expected_values = ['new', 'fixed', 'in to do']
    setup_property_definitions :status => expected_values
    status = @project.find_property_definition('status')

    get :values, :project_id => @project.identifier, :api_version => 'v2', :id => status.id, :format => 'json'
    assert_equal expected_values,  JSON.parse(@response.body)['values']
  end

  def assert_link(link_text, location)
    assert_tag 'a', :attributes => {:href => location}, :content => link_text
  end

  def assert_no_link(link_text, location)
    assert_no_tag 'a', :attributes => {:href => location}, :content => link_text
  end

  def assert_text_present(*texts)
    texts.each {|text| assert(@response.body.include?(text))}
  end

end
