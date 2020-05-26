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

class CardsControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree, ::RenderableTestHelper::Functional

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def teardown
    logout_as_nil
    Clock.reset_fake
  end

  def test_should_show_warnings_for_anon_users
    with_new_project(:anonymous_accessible => true) do |project|
      card = create_card!(:name => "hello world", :description => "sdfvsdf #{"{{ dummy }}" * 11} blabla")
      set_anonymous_access_for(project, true)
      change_license_to_allow_anonymous_access
      logout_as_nil
      get 'show', :project_id => project.identifier, :number => card.number
      assert_select "#too_many_macros_warning"
    end
  end

  def test_should_show_warnings_for_non_project_users
    with_new_project(:anonymous_accessible => true) do |project|
      card = create_card!(:name => "hello world", :description => "sdfvsdf #{"{{ dummy }}" * 11} blabla")
      set_anonymous_access_for(project, true)
      change_license_to_allow_anonymous_access
      logout_as_nil
      get 'show', :project_id => project.identifier, :number => card.number
      assert_select "#too_many_macros_warning"
    end
  end

  def test_show_should_provide_warning_when_more_than_10_macros
    card = @project.cards.first
    card.update_attribute(:description, "sdfvsdf #{"{{ dummy }}" * 11} blabla")
    view_card(card)

    assert_select "#too_many_macros_warning"
  end

  def test_should_not_count_project_macro_for_too_many_macros_warning
    card = @project.cards.first
    card.update_attribute(:description, "sdfvsdf #{"{{ project }}" * 11} blabla")
    view_card(card)

    assert_select "#too_many_macros_warning", :count => 0
  end

  def test_should_not_count_google_maps_macro_for_too_many_macros_warning
    card = @project.cards.first
    card.update_attribute(:description, "sdfvsdf #{"{{ google-maps }}" * 11} blabla")
    view_card(card)

    assert_select "#too_many_macros_warning", :count => 0
  end


  private
  def view_card(card)
    get 'show', :project_id => @project.identifier, :number => card.number
  end

end
