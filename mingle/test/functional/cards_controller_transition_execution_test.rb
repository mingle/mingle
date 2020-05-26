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

class CardsControllerTransitionExecutionTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @project    = first_project
    @project.activate
    login_as_member
  end

  def test_set_value_for_card_does_not_exist
    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => '12345655', :group_by => {'lane' => "status"}, :style => "grid", :value => "closed"
    assert_response :success
  end

  def test_should_trigger_transition_when_set_value_for_transition_only_property_and_the_value_is_the_transition_action_is_going_to_set
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)
    create_transition(@project, 'open', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open', :iteration => '1'})
    a_card = @project.cards.first
    a_card.update_attribute :cp_status, 'new'

    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => a_card.number, :group_by => {'lane' => "status"}, :style => "grid", :value => "open"

    assert_response :success

    assert_equal 'open', a_card.reload.cp_status
    assert_equal '1', a_card.reload.cp_iteration
  end

  def test_should_have_notice_when_auto_transition_triggered
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)
    create_transition(@project, 'open as iteration 1', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open', :iteration => '1'})
    a_card = @project.cards.first
    a_card.update_attribute :cp_status, 'new'

    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => a_card.number, :group_by => {'lane' => "status"}, :style => "grid", :value => "open"

    assert_response :success

    assert_match(/#{"open as iteration"}.+successfully applied to card.+##{a_card.number}/, @response.body)
  end

  def test_should_have_info_and_not_refresh_card_div_when_auto_transition_triggered_and_card_is_not_in_view_anymore
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)
    create_transition(@project, 'open as iteration 1', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open', :iteration => '1'})
    a_card = @project.cards.first
    a_card.update_attribute :cp_status, 'new'

    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => a_card.number, :group_by => {'lane' => "status"}, :filters => ['[status][is][new]'], :style => "grid", :value => "open"

    assert_response :success

    assert_match(/property was updated, but is not shown because it does not match the current filter/, @response.body)
    assert(/card_inner_wrapper_#{a_card.number}/ !~ @response.body)
  end

  def test_should_ask_for_choosing_transition_while_matching_multi_transitions
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)

    transition_with_it1 = create_transition(@project, 'open tran with it 1', :set_properties => {:status => 'open', :iteration => 1})
    transition_with_it2 = create_transition(@project, 'open tran with it 2', :set_properties => {:status => 'open', :iteration => 2})
    a_card = @project.cards.first

    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => a_card.number, :group_by => {'lane' => "status"}, :style => "grid", :value => "open"

    assert_response :success

    assert_match(/Please select a transition to automate/, @response.body)
    assert_match(/open tran with it 1/, @response.body)
    assert_match(/open tran with it 2/, @response.body)
  end

  def test_select_transition_to_automate
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)

    transition_with_it1 = create_transition(@project, 'open tran with it 1', :set_properties => {:status => 'open', :iteration => 1})
    transition_with_it2 = create_transition(@project, 'open tran with it 2', :set_properties => {:status => 'open', :iteration => 2})
    a_card = @project.cards.first

    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => a_card.number, :group_by => {'lane' => "status"}, :style => "grid", :selected_auto_transition_id => transition_with_it2.id
    assert_response :success

    assert_match(/#{transition_with_it2.name}.+successfully applied to card.+##{a_card.number}/, @response.body)
  end

  # bug 6567
  def test_should_not_show_success_message_if_transition_did_not_execute
    login_as_admin
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)
    create_transition(@project, 'open as iteration 1', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open', :iteration => '1', :dev => PropertyType::UserType::CURRENT_USER})
    a_card = @project.cards.first
    a_card.update_attribute :cp_status, 'new'

    xhr :post, :set_value_for, :project_id => @project.identifier, :card_number => a_card.number, :group_by => {'lane' => "status"}, :style => "grid", :value => "open"
    assert_response :success
    assert_select "div", :text => /admin@email\.com is not a project member/
  end

  #bug 8012
  def test_should_not_display_success_message_if_transition_execution_fails
    @project.find_property_definition('priority').update_attributes(:restricted => true)
    card = @project.cards.create!(:name => 'Card One', :card_type_name => 'Card', :cp_status => 'new')
    open_transition = create_transition(@project, 'Open',
            :required_properties => {:status => 'new'},
            :set_properties => {:status => 'open', :priority => Transition::USER_INPUT_REQUIRED},
            :require_comment => false)
    close_transition = create_transition(@project, 'Close',
            :required_properties => {:status => 'open'},
            :set_properties => {:status => 'close'},
            :require_comment => false)
    xhr :post, :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'priority' => 'absoluteJUNK'}
    assert_select "div#error", :text => /Priority is restricted to low, medium, and high/
    assert_select "div#notice", :count => 0
  end

  def test_transition_should_keep_showing_hidden_properties
    update_property_status_to_hidden_property

    session[:show_hidden_properties] = true

    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card! :name => 'a card'
    xhr :post, :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id

    assert_rjs_replace 'toggle_hidden_properties_bar'
  end

  def test_transition_should_show_confirmation_message
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'})
    card = create_card! :name => 'a card'
    xhr :post, :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id
    assert_match(/#{open_transition.name.bold} successfully applied to card.*##{card.number}/, flash.now[:notice])
  end

  # bug 3618
  def test_error_message_on_invoking_transition_is_not_duplicated
    transition = create_transition(@project, 'open card', :set_properties => {:release => Transition::USER_INPUT_REQUIRED})
    card = @project.cards.create!(:name => 'hi there', :card_type => @project.card_types.first)

    xhr :post, :transition, :project_id => @project.identifier, :transition_id => transition.id, :id => card.id, :comment => {:content => ""},
               :user_entered_properties => {'release' => 'foo'}

    assert_error "Release: <b>foo</b> is an invalid numeric value"
  end

  def test_transition_in_popup_should_save_user_entered_properties
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => Transition::USER_INPUT_REQUIRED, :priority => Transition::USER_INPUT_OPTIONAL, :old_type => Transition::USER_INPUT_OPTIONAL},
            :require_comment => false)
    card = create_card!(:name => "I am card")
    xhr :post, :transition_in_old_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'status' => 'closed', 'priority' => 'high'}
    assert_equal 'closed', card.reload.cp_status
    assert_equal 'high', card.cp_priority
    assert_nil card.cp_old_type

    card.cp_status = nil
    card.save!

    xhr :post, :transition_in_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'status' => 'pending', 'priority' => 'low'}
    assert_equal 'low', card.reload.cp_priority
    assert_equal 'pending', card.reload.cp_status
  end

  def test_require_user_to_enter_text_properties_must_be_set
    textproperty = @project.find_property_definition('id')
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :set_properties => {:id => Transition::USER_INPUT_REQUIRED},
            :require_comment => false)
    card = create_card!(:name => "I am card")
    textproperty.update_card(card, "closed")
    card.save!

    xhr :post, :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'id' => ''}
    assert_rjs 'replace', 'flash', /Value of id property for this transition must not be empty/
    assert_equal 'closed', card.reload.cp_id

    xhr :post, :transition_in_old_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'id' => ''}
    assert_error
    assert_equal 'closed', card.reload.cp_id

    response = xhr :post, :transition_in_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'id' => ''}
    assert_match 'showApplyTransitionError', response.body
    assert_equal 'closed', card.reload.cp_id

    post :bulk_transition, :project_id => @project.identifier, :transition => open_transition.name, :selected_cards => [card.id.to_s], :user_entered_properties => {'id' => ''}
    follow_redirect
    assert_error
    assert_equal 'closed', card.reload.cp_id
  end

  # bug 4579
  def test_should_show_notice_message_after_using_transition_in_old_popup
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'} )
    card = create_card!(:name => "I am card")
    xhr :post, :transition_in_old_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id

    assert_response :success
    assert_match(/#{open_transition.name.bold} successfully applied to card.*##{card.number}/, flash[:notice])

    # bug 7902 The message should be a flash.now and not a flash
    get :list
    assert_no_match(/#{open_transition.name.bold} successfully applied to card.*##{card.number}/, flash[:notice])
  end

  def test_should_save_comment_on_transition_execution_if_require_comment
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card!(:name => "I am card")
    post :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :comment => { :content => "transition comment"}
    assert_equal "transition comment", card.reload.discussion.first.murmur
  end

  def test_transition_in_old_popup_should_save_comment_on_transition_execution_if_require_comment
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card!(:name => "I am card")
    xhr :post, :transition_in_old_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :comment => { :content => "transition comment"}
    assert_equal "transition comment", card.reload.discussion.first.murmur

    card.cp_status = nil
    card.save!

    xhr :post, :transition_in_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :comment => { :content => "another transition comment"}
    assert_equal "another transition comment", card.reload.discussion.first.murmur
  end

  def test_should_save_user_entered_properties
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => Transition::USER_INPUT_REQUIRED, :priority => Transition::USER_INPUT_OPTIONAL, :old_type => Transition::USER_INPUT_OPTIONAL},
            :require_comment => false)
    card = create_card!(:name => "I am card")
    post :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id, :user_entered_properties => {'status' => 'closed', 'priority' => 'high'}
    assert_equal 'closed', card.reload.cp_status
    assert_equal 'high', card.cp_priority
    assert_nil card.cp_old_type
  end

  def test_should_not_execute_transition_if_no_comment_when_transition_is_require_comment
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card!(:name => "I am card")
    xhr :post, :transition, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id
    assert_rjs 'replace', 'flash', Regexp.new(json_escape('Transition <b>Open<\/b> requires a comment'))
    assert_nil card.reload.cp_status
  end

  def test_transition_in_popup_should_not_execute_transition_if_no_comment_when_transition_is_require_comment
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card!(:name => "I am card")
    xhr :post, :transition_in_old_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id
    assert_error
    assert_equal nil, card.reload.cp_status

    response = xhr :post, :transition_in_popup, :project_id => @project.identifier, :transition_id => open_transition.id, :id => card.id
    assert_match "showApplyTransitionError", response.body
    assert_equal nil, card.reload.cp_status
  end

  # bug 5051
  def test_transition_in_old_popup_should_not_show_success_message_if_there_was_an_error
    admin = User.find_by_login('admin')
    login_as_admin
    some_story = @project.cards.create!(:name => 'some story', :card_type_name => 'Card')
    transition = create_transition(@project, 'set to current user', :set_properties => {'dev' => '(current user)'})

    post :transition_in_old_popup, :project_id => @project.identifier, :id => some_story.id, :transition_id => transition.id
    assert_error "#{admin.name.html_bold} is not a project member"
    assert_select "p", :text => /success/, :count => 0
  end

  def test_should_be_able_to_execute_transitions_from_another_project_and_not_update_current_projects_grid_view
    other_project = project_without_cards
    story1 = create_card!(:name => 'story 1')
    transition = create_transition(@project, 'user thing', :set_properties => {'dev' => '(current user)'})

    response = post :transition_in_old_popup, :project_id => @project.identifier, :id => story1.id, :transition_id => transition.id, :current_project_id => other_project.identifier
    assert_response :success
    assert !response.body.include?('color-legend-container')
    assert !response.body.include?('filters-panel')

    response = post :transition_in_popup, :project_id => @project.identifier, :id => story1.id, :transition_id => transition.id, :current_project_id => other_project.identifier
    assert_response :success
    assert !response.body.include?('color-legend-container')
    assert !response.body.include?('filters-panel')

    response = post :transition_in_popup, :project_id => @project.identifier, :id => story1.id, :transition_id => transition.id, :current_project_id => @project.identifier
    assert_response :success
    assert response.body.include?('color-legend-container')
    assert response.body.include?('filters-panel')

    response = post :transition_in_popup, :project_id => @project.identifier, :id => story1.id, :transition_id => transition.id
    assert_response :success
    assert response.body.include?('color-legend-container')
    assert response.body.include?('filters-panel')
  end

  def test_should_show_error_message_when_invoke_transition_that_set_user_is_not_team_member
    admin = create_user!(:admin => true)
    login(admin.email)
    story1 = create_card!(:name => 'story 1')
    transition = create_transition(@project, 'set to current user', :set_properties => {'dev' => '(current user)'})

    post :transition, :id => story1.id, :transition_id => transition.id, :project_id => @project.identifier
    assert_error "#{admin.name.html_bold} is not a project member"

    post :bulk_transition, :project_id => @project.identifier, :transition_id => transition.id, :selected_cards => story1.id.to_s
    follow_redirect
    assert_error "#{admin.name.html_bold} is not a project member. All work was cancelled."

    post :transition_in_old_popup, :project_id => @project.identifier, :id => story1.id, :transition_id => transition.id
    assert_error "#{admin.name.html_bold} is not a project member"

    response = post :transition_in_popup, :project_id => @project.identifier, :id => story1.id, :transition_id => transition.id
    assert_match "showApplyTransitionError", response.body
  end

  def test_tansition_should_allow_to_comment_as_murmur
    card = @project.cards.first
    open_transition = create_transition(@project, 'Open',
            :card_type => card.card_type,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    post :transition, :id => card.id, :transition_id => open_transition.id, :project_id => @project.identifier, :comment => {:content => 'this is a bla comment'}
    assert_response :success
    assert_equal 'this is a bla comment', find_murmur_from(card).murmur
  end

  def test_tansition_in_popup_should_allow_to_comment_as_murmur
    card = @project.cards.first
    open_transition = create_transition(@project, 'Open',
            :card_type => card.card_type,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    post :transition_in_old_popup, :id => card.id, :transition_id => open_transition.id, :project_id => @project.identifier, :comment => {:content => 'this is a bla comment'}
    assert_response :success
    assert_equal 'this is a bla comment', find_murmur_from(card).murmur
  end

  private

  def update_property_status_to_hidden_property
    status = @project.find_property_definition('status')
    status.update_attribute(:hidden, true)
  end

  def assert_aggregate_value_text_replaced(html_id, value = nil)
    replace_pattern = "$j('##{html_id}_agg_value').text"
    replace_pattern << "(' (#{value})')" if value
    assert_match(Regexp.compile(Regexp.escape(replace_pattern)), @response.body)
  end
end
