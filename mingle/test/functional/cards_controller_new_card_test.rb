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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class CardsControllerNewCardTest < ActionController::TestCase
  include RenderableTestHelper::Functional

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def test_card_create_should_escape_manually_entered_macros
    post :create, :project_id => @project.identifier, :card => {:name => 'manual macro', :card_type_name => @project.card_types.first.name, :description => "{{ project }}"}
    assert_equal ManuallyEnteredMacroEscaper.new("{{ project }}").escape, @project.cards.find_by_name("manual macro").description
  end

  def test_card_create_should_preserve_macros_created_by_editor
    post :create, :project_id => @project.identifier, :card => {:name => 'macro', :card_type_name => @project.card_types.first.name, :description => create_raw_macro_markup("{{ project }}")}
    assert_equal "{{ project }}", @project.cards.find_by_name("macro").description
  end

  def test_can_set_user_property_from_usr_login_in_url_when_rendering_new_card_form
    member = User.find_by_login('member')
    get :new, :project_id => @project.identifier, :properties => {'dev' => member.login}, :card => {:name => 'This is my first card', :card_type_name => @project.card_types.first.name}
    assert_equal member, assigns['card'].cp_dev
  end

  def test_can_set_protected_properties_when_rendering_new_card_form
    @project.find_property_definition('priority').update_attribute(:transition_only, true)
    get :new, :project_id => @project.identifier, :card => {:name => 'new card', :card_type_name => @project.card_types.first.name}, :properties => {:priority => 'high', :status => 'open'}
    assert_select "span[data-read-only='false']", :text => "high"
    assert_select "span[data-read-only='false']", :text => "open"
  end

  def test_should_set_the_type_to_the_first_card_type_when_no_card_type_is_specified_when_rendering_new_card_form
    first_card_type = @project.card_types.first
    get :new, :project_id => @project.identifier, :card => {:name => 'newer card'}
    assert_name_equal first_card_type, assigns['card'].card_type
  end

  def test_should_set_the_type_to_the_first_card_type_when_card_type_are_invalid
    first_card_type = @project.card_types.first
    get :new, :project_id => @project.identifier, :card => {:card_type_name => 'not exists'}
    assert_name_equal first_card_type, assigns['card'].card_type

    get :new, :project_id => @project.identifier, :properties => {:type => 'not exists'}
    assert_name_equal first_card_type, assigns['card'].card_type
  end


  def test_new_card_uses_card_defaults_when_properties_are_passed
    first_card_type = @project.card_types.first
    second_card_type = @project.card_types.create!(:name => 'second type')
    get :new, :project_id => @project.identifier, :card => {:name => 'newer card', :card_type_name => first_card_type.name}, :properties => {:type => second_card_type.name}
    assert_name_equal second_card_type, assigns['card'].card_type
  end

  def test_new_card_passed_properties_take_precedence_over_card_defaults
    second_card_type = @project.card_types.create!(:name => 'second type')
    second_card_type.card_defaults.update_properties(:status => 'open')

    get :new, :project_id => @project.identifier, :card => {:name => 'newer card'},
      :properties => {:Type => second_card_type.name, :status => 'closed'}

    assert_equal 'closed', assigns['card'].cp_status
  end

  def test_add_with_detail_should_use_card_property_defaults
    second_card_type = @project.card_types.create!(:name => 'second type')
    second_card_type.card_defaults.update_properties(:status => 'open', :priority => 'low')

    get :new, :project_id => @project.identifier, :card => {:name => 'newer card', :card_type_name => second_card_type.name}

    assert_name_equal second_card_type, assigns['card'].card_type
    assert_equal 'open', assigns['card'].cp_status
    assert_equal 'low', assigns['card'].cp_priority
  end

  def test_error_due_to_defaults_should_not_be_duplicated_on_new_card_screen_when_add_with_detail
    card_type = @project.card_types.first
    card_type.card_defaults.update_properties :dev => PropertyType::UserType::CURRENT_USER

    non_member_admin = User.find_by_login('admin')
    login(non_member_admin.email)

    get :new, :project_id => @project.identifier, :card => {:name => 'card for current user'}
    assert_warning "Unable to set default for #{'dev'.html_bold} to (current user) because #{non_member_admin.name.html_bold} is not a project member"
  end

  def test_add_with_detail_should_retain_description_from_card_type_default
    second_card_type = @project.card_types.create!(:name => 'second type')
    second_card_type.card_defaults.update_attribute(:description, 'my description')
    get :new, :project_id => @project.identifier, :card => {:name => 'newer card', :card_type_name => second_card_type.name}
    assert_equal 'my description', assigns['card'].description
  end
end
