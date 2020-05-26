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

class EnumerationValuesControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller EnumerationValuesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @project = create_project :admins => [User.find_by_login('proj_admin')]
    login_as_proj_admin
    setup_property_definitions :release => []
    @enum_release = @project.find_property_definition('release')
  end

  def test_should_link_to_filtered_cards_when_value_is_in_use
    create_enumeration_value('one', '#00ff00')

    get :list, :project_id => @project.identifier, :definition_id => @enum_release.id
    assert_response :ok

    assert_select "td.col2 span", :text => "no cards", :count => 1

    create_card! :name => "foo", :release => "one"
    assert_equal "one", @enum_release.value(@project.cards.first)

    mql_query = "filters%5Bmql%5D=%22#{@enum_release.name}%22+%3D+%22one%22"
    get :list, :project_id => @project.identifier, :definition_id => @enum_release.id
    assert_response :ok

    assert_select "td.col2 a", :text => "1 card", :count => 1
    assert_tag :a, :attributes => {:href => "/projects/#{@project.identifier}/cards/list?#{mql_query}"}
  end

  def test_create_new_enumeration_value
    create_enumeration_value('one', '#00ff00')
    assert_redirected_to :action => 'list'
    assert_equal 'one', first_item_of_release.value
    assert_equal '#00ff00', first_item_of_release.color
  end

  def test_create_strips_tags_from_value
    create_enumeration_value("<script>alert('foo')</script>", '#00ff00')
    assert_redirected_to :action => 'list'
    assert_equal "alert('foo')", first_item_of_release.value
  end

  def test_create_error_should_take_user_back_to_list_action
    create_enumeration_value('one', '#00ff00')
    create_enumeration_value('one', '#00ff00')

    assert_redirected_to :action => 'list'
    assert_not_nil flash[:error]
  end

  def test_should_not_be_able_to_create_enum_with_empty_value
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => @enum_release.id}
    assert_redirected_to :action => 'list'
    assert_not_nil flash[:error]
  end

  def test_update_name_action_should_change_enumerations
    create_enumeration_value('one', '#00ff00')
    update_enumeration_value_name(first_item_of_release.id, 'two')
    assert_equal 'two', first_item_of_release.value
  end

  def test_update_strips_tags_from_value
    create_enumeration_value('test', '#00ff00')
    update_enumeration_value_name(first_item_of_release.id, "<script>alert('foo')</script>")
    follow_redirect
    assert_equal "alert('foo')", first_item_of_release.value
  end

  def test_error_should_be_shown_when_update_error_happens
    create_enumeration_value('one', '#00ff00')
    create_enumeration_value('two', '#00ff00')
    update_enumeration_value_name(first_item_of_release.id, 'two')
    assert_not_nil flash[:error]
  end

  def test_update_color
    create_enumeration_value('one', '#00ff00')
    post :update_color, :project_id => @project.identifier, :id => first_item_of_release.id, :color_provider_color => '#0000ff'
    assert_equal 'one', first_item_of_release.value
    assert_equal '#0000ff', first_item_of_release.color
  end

  def test_destroy
    release_one = @enum_release.enumeration_values_association.create!(:value => 'one')
    post :destroy, :project_id => @project.identifier, :id => release_one.id
    assert_redirected_to :action => 'list'
    @project.reload
    assert_equal 0, @enum_release.reload.values.size
  end

  def test_creating_multiple_values_that_look_the_same_but_only_differ_in_case
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => @enum_release.id, :value => 'Two'}
    assert_redirected_to :action => 'list'
    assert_equal 1, @enum_release.reload.values.size

    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => @enum_release.id, :value => 'TWO'}
    assert_redirected_to :action => 'list'
    follow_redirect
    assert_equal 1, @enum_release.reload.values.size
    assert_error 'Value has already been taken'
  end

  def test_creating_numbers_that_are_formatted_differently_but_have_the_same_value_should_fail
    setup_numeric_property_definition 'estimate', []
    estimate = @project.find_property_definition('estimate')
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => '1'}
    assert_redirected_to :action => 'list'
    assert_equal 1, estimate.reload.values.size

    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => '1.0'}
    assert_redirected_to :action => 'list'
    follow_redirect
    assert_equal 1, estimate.reload.values.size
    assert_error 'Value has already been taken'
  end

  def test_enum_value_delete_links_only_appear_when_value_is_not_in_use
    setup_property_definitions :status => ['new', 'in progress'], :iteration => []
    status_new = @project.find_enumeration_value('status', 'new')
    status_in_progress = @project.find_enumeration_value('status', 'in progress')
    get :list, :project_id => @project.identifier, :definition_id => @project.find_property_definition('status')
    assert_tag :a, :attributes => {:id => delete_link_id(status_new)}
    assert_tag :a, :attributes => {:id => delete_link_id(status_in_progress)}

   create_card!(:name => 'first card', :status => 'new')
    get :list, :project_id => @project.identifier, :definition_id => @project.find_property_definition('status')
    assert_no_tag :a, :attributes => {:id => delete_link_id(status_new)}
    assert_tag :a, :attributes => {:id => delete_link_id(status_in_progress)}
  end

  def test_enum_values_and_theier_colors_should_be_listed
    setup_property_definitions :release => []
    enum_release = @project.find_property_definition('release')

    enum_release.create_enumeration_value(:value  => 'one', :color  => "#ff0000")
    enum_release.create_enumeration_value(:value  => 'two', :color  => "#00ff00")
    enum_release.create_enumeration_value(:value  => 'three', :color  => "#0000ff")

    get :list, :project_id  => @project.identifier, :definition_id => @project.find_property_definition('release')
    assert_text_present 'one', 'two', 'three'
    assert_text_present '#ff0000', "#00ff00", "#0000ff"
  end

  def test_should_not_be_able_to_add_non_numeric_value_on_numeric_property_definition
    setup_numeric_property_definition 'estimate', [4, 8]
    estimate = @project.find_property_definition('estimate')
    assert_equal 2, estimate.reload.values.size
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => 'abc'}
    assert_redirected_to :action => 'list'
    follow_redirect
    assert_equal 2, estimate.reload.values.size
    assert_error "Value <b>abc</b> is an invalid numeric value"
  end

  def test_should_give_only_empty_warning_when_creating_an_enum_value_with_a_blank_value
    estimate = setup_numeric_property_definition('estimate', [])
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => ''}
    follow_redirect
    assert_error "Value can't be blank"
  end

  def test_should_not_treat_numeric_value_of_zero_and_blank_as_two_errors
    estimate = setup_numeric_property_definition('estimate', ['0'])
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => ''}
    follow_redirect
    assert_error "Value can't be blank"
  end

  def test_should_not_give_duplicate_error_messages_when_adding_a_duplicate_numeric_value
    estimate = setup_numeric_property_definition('estimate', ['1'])
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => '1'}
    follow_redirect
    assert_error "Value has already been taken"
  end

  def test_should_not_create_history_events_for_invalid_enum_value_changes
    estimate = setup_numeric_property_definition('estimate', ['1'])
    card = @project.cards.create!(:name => 'Card 1', :card_type_name => @project.card_types.first.name, :cp_estimate => '1')
    old_change_descriptions = card.versions.last.describe_changes

    estimate_of_one = estimate.enumeration_values.first

    update_enumeration_value_name(estimate_of_one.id, 'foo')
    follow_redirect
    assert_error 'Value <b>foo</b> is an invalid numeric value'

    card = @project.cards.find_by_number(card.number)
    assert_equal 1, card.versions.reload.size
    new_change_descriptions = card.versions.last.describe_changes
    assert_equal old_change_descriptions, new_change_descriptions
  end


  def test_should_give_right_error_msg_while_creating_enum_value_with_non_numeric_and_prop_is_numeric_and_there_is_0_value
    estimate = setup_numeric_property_definition('estimate', [0])
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => estimate.id, :value => 'foo'}

    follow_redirect
    assert_error 'Value <b>foo</b> is an invalid numeric value'
    assert_no_error 'Value has been taken'
  end

  def test_confirm_delete_warns_that_project_variable_associations_will_be_removed
    release = setup_numeric_property_definition('release2', ['1', '2', '3', '4'])
    one_value = release.enumeration_values.detect { |ev| ev.value == '1' }
    three_value = release.enumeration_values.detect { |ev| ev.value == '3' }
    pv = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :property_definition_ids => [release.id])

    post :confirm_delete, :project_id => @project.identifier, :id => three_value.id
    assert_select "li", "The following 1 project variable will be disassociated from property #{three_value.property_definition.name}: #{pv.display_name}"
    assert release.enumeration_values.include?(three_value)

    post :confirm_delete, :project_id => @project.identifier, :id => one_value.id
    assert_redirected_to :action => 'list'
    @project.clear_enumeration_values_cache
    assert !release.enumeration_values.include?(one_value)
  end

  def test_should_go_to_confirm_page_when_delete_enumeration_value_which_used_by_card_list_view
    setup_property_definitions :status => ['open', 'close']
    open_view = CardListView.construct_from_params(@project, {:filters => ["[status][is][open]"]})
    open_view.name = "opened view"
    open_view.save!
    open = @project.find_property_definition('status').find_enumeration_value('open')
    post :confirm_delete, :project_id => @project.identifier, :id => open.id
    assert_template 'confirm_delete'
    assert_select "li", "The following 1 card list view will be deleted: #{open_view.name}"
  end

  # bug 8668
  def test_confirm_delete_page_should_not_list_names_of_personal_favorites
    raise "An assertion in this test relies on there being no card list views in the project." if @project.card_list_views.any?
    setup_property_definitions :status => ['open', 'close']
    team_view = @project.card_list_views.create_or_update(:view => { :name => 'team' }, :filters => ["[status][is][open]"])
    personal_view = @project.card_list_views.create_or_update(:view => { :name => 'personal' }, :filters => ["[status][is][open]"], :user_id => User.current.id)

    open = @project.find_property_definition('status').find_enumeration_value('open')
    post :confirm_delete, :project_id => @project.identifier, :id => open.id
    assert_template 'confirm_delete'
    assert_select "li", "The following 1 card list view will be deleted: team"
    assert_select "li", "Any personal favorites that use this value will be deleted"
  end

  private

  def create_enumeration_value(value, color)
    post :create, :project_id  => @project.identifier, :enumeration => {:property_definition_id  => @enum_release.id, :value => value, :color  => color }
  end

  def update_enumeration_value_name(id, name)
    post :update_name, :project_id  => @project.identifier, :name => name, :id => id
  end

  def first_item_of_release
    @project.reload
    @enum_release.reload.enumeration_values.first
  end

  def delete_link_id(value)
    "delete-value-#{value.id}"
  end

  def assert_text_present(*texts)
    texts.each {|text| assert(@response.body.include?(text))}
  end
end
