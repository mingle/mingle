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

class TransitionWorkflowsControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller TransitionWorkflowsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_proj_admin
    @project = three_level_tree_project
    @project.activate
  end

  def test_new_assigns_properties_for_all_project_card_types_and_render
    get :new, :project_id => @project.identifier
    assert_response :success
    assert_equal @project.card_type_ids.sort, assigns(:card_types).map(&:id).sort
  end

  def test_preview_builds_preview_transitions_and_renders
    card_type = @project.card_types.first
    property_definition = @project.find_property_definition('size')
    create_transition @project, 'Persisted Transition', :card_type => card_type, :set_properties => { :size => '1' }
    assert_no_difference 'Transition.count' do
      xhr :get, :preview, :project_id => @project.identifier, :workflow => { :property_definition_id => property_definition.id, :card_type_id => card_type.id }
    end

    assert_response :success
    assert_select '.warning-box p', :text => "There is already 1 transition using Card and size. Click here to view these existing transitions."
    assert_select '.info-box p', :text => "You are previewing the transitions that are about to get generated. The transitions below will be created only if you complete the process by clicking on 'Generate transition workflow'. Also note that the listed hidden date properties will be created along with the transitions.".gsub("'", "&#39;")
    assert_transition 'Card', :property => 'size', :from => '(not set)', :to => '1'
    assert_transition 'Card', :property => 'size', :from => '1',         :to => '2'
    assert_transition 'Card', :property => 'size', :from => '2',         :to => '3'
    assert_transition 'Card', :property => 'size', :from => '3',         :to => '4'
  end

  def test_preview_displays_message_when_chosen_property_has_no_values
    with_new_project do |project|
      login_as_admin
      type_card = project.card_types.first
      no_values_property_definition = setup_managed_text_definition('no values', [])
      type_card.add_property_definition(no_values_property_definition)
      xhr :get, :preview, :project_id => project.identifier, :workflow => { :property_definition_id => no_values_property_definition.id, :card_type_id => type_card.id }
      assert_select "div", :text => "There is no transition to preview because the selected property does not have any values."
    end
  end

  def test_generate_creates_transitions_and_renders
    with_new_project do |project|
      login_as_admin
      card_type = project.card_types.first
      property_definition = setup_managed_text_definition('priority', ['low', 'medium', 'high'])

      assert_difference 'Transition.count', 3 do
        post :generate, :project_id => project.identifier, :workflow => { :property_definition_id => property_definition.id, :card_type_id => card_type.id }

        assert_redirected_to :controller => 'transitions', :action => 'list', :project_id => project.identifier, :filter => { :card_type_id => card_type.id, :property_definition_id => property_definition.id }
        values = [
          'Move Card to low',
          'Move Card to medium',
          'Move Card to high',
          'Moved to low on',
          'Moved to medium on',
          'Moved to high on',
        ].map(&:bold)

        assert_equal ("Transitions %s, %s and %s and properties %s, %s and %s were successfully created." % values), flash[:notice]
      end
    end
  end

  def test_new_should_has_a_disabled_gernerated_link
    get :new, :project_id => @project.identifier
    assert_select ".generate_transitions.disabled", :count => 2
    assert_select ".generate_transitions[href=?]", nil, :count => 2
  end

  protected

  def assert_transition(card_type_name, params)
    assert_select ".transition-detail" do
      assert_select ".transition-from" do
        assert_select ".card-type" do
          assert_select ".property-name", :text => "Type:"
          assert_select ".property-value", :text => card_type_name
        end
        assert_select ".property" do
          assert_select ".property-name", :text => "#{params[:property]}:"
          assert_select ".property-value", :text => params[:from]
        end
      end

      assert_select ".transition-to" do
        assert_select ".property" do
          assert_select ".property-name", :text => "#{params[:property]}:"
          assert_select ".property-value", :text => params[:to]
        end
        assert_select ".hidden" do
          assert_select ".property-name", :text => "Moved to #{params[:to]} on:"
          assert_select ".property-value", :text => "(today)"
        end
      end
    end
  end

end
