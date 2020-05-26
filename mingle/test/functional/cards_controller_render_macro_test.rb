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

class CardsControllerRenderMacroTest < ActionController::TestCase
  include ActionController::Assertions::MacroContentAssertionHelpers

  def setup
    login_as_member
    @controller = create_controller CardsController
    @project = first_project
    @project.activate
  end

  def test_render_macro_replaces_macro_content_for_project_macro
    card = @project.cards.first
    get :render_macro, :project_id => @project.identifier, :macro => "{{ project }}", :id => card.id
    assert_response :success
    assert_equal_ignoring_container_element @project.identifier, @response.body
  end

  def test_render_macro_replaces_macro_content_for_value_macro
    card = @project.cards.second
    get :render_macro, :project_id => @project.identifier,
        :macro => "{{ value query: select number where number = #{card.number}}}", :id => card.id
    assert_response :success
    assert_equal_ignoring_container_element card.number.to_s, @response.body
  end

  def test_render_macro_replaces_macro_content_for_table_macro
    card = @project.cards.second
    get :render_macro, :project_id => @project.identifier, :macro => "{{ table query: select number }}", :id => card.id
    assert_response :success
  end

  def test_render_macro_without_macro_leaves_text_unchanged
    get :render_macro, :project_id => @project.identifier, :macro => 'Hi', :id => @project.cards.first.id
    assert_response :success
    assert_equal 'Hi', @response.body
  end

  def test_render_macro_with_project_macro_substitutes_properly
    get :render_macro, :project_id => @project.identifier, :macro => 'blah blah {{ project }} blah', :id => @project.cards.first.id
    assert_response :success
    assert_equal_ignoring_container_element "blah blah #{@project.identifier} blah", @response.body
  end

  def test_render_macro_with_error_should_respond_with_422
    get :render_macro, :project_id => @project.identifier, :macro => '{{ nonexistent }}', :id => @project.cards.first.id

    assert_response 422
    assert /No such macro: \<b\>nonexistent.*/ =~ @response.body
  end

  def test_should_render_this_card_macro_on_saved_card
    get :render_macro, :project_id => @project.identifier, :macro => "{{ value query: select name where number = THIS CARD.number }}", :id => @project.cards.first.id
    assert_equal_ignoring_container_element @project.cards.first.name, @response.body
  end

  def test_should_render_macro_for_new_unsaved_card
    get :render_macro, :project_id => @project.identifier, :macro => '{{
      pie-chart
        data: SELECT Name, Count(*) WHERE Type = Card
    }}'
    assert_include 'id="piechart-Card--1-preview"', @response.body
  end

end
