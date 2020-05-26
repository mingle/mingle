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

class CardsControllerPopupTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    login_as_member
    @project = first_project
    @project.activate
  end

  def test_render_cards_on_grid_view
    get :list, :project_id => @project.identifier, :style => 'grid'
    assert_response :success
  end

  def test_show_card_popup
    card = @project.cards.first
    xhr :get, :popup_show, :project_id => @project.identifier, :number => card.number
    assert_response :success
    assert_include "##{card.number}", @response.body
    assert_include "[#{@project.identifier}/##{card.number}] #{card.name}", @response.body
  end

  def test_should_return_404_when_card_not_found_for_popup
    xhr :get, :popup_show, :project_id => @project.identifier
    assert_response :not_found

    xhr :get, :popup_show, :project_id => @project.identifier, :number => '-1'
    assert_response :not_found
  end

  def test_card_popup_show_for_redcloth_card_will_convert_it_to_html
    card_type = @project.card_types.first
    card1 = @project.cards.create!(:name => "card1", :description => "h1. I am a header", :card_type => @project.card_types.first)
    card1.update_attribute :redcloth, true
    assert card1.redcloth

    xhr :get, :popup_show, :number => card1.number, :project_id => @project.identifier
    assert_false card1.reload.redcloth
    assert_include "<h1>I am a header</h1>", json_unescape(@response.body)
  end

  def test_restful_load_murmurs_for_card
    card1 = @project.cards.create!(:name => "card1", :description => "h1. I am a header", :card_type => @project.card_types.first)
    body = "this murmur came from a card"
    murmur = create_murmur(:murmur => body)
    CardMurmurLink.create!(:project => @project,:card => card1, :murmur => murmur)

    xhr :get, :murmurs, :number => card1.number, :project_id => @project.identifier, :format => "json"
    assert_include body, @response.body
  end

  def test_property_should_be_displayed_on_lightbox
    login_as_admin
    with_new_project do |project|
      prop = setup_text_property_definition('revision blah blah')
      card = create_card!(:name => 'foo', 'revision blah blah' => 'r23030')
      xhr :get, :popup_show, :project_id => project.identifier, :number => card.number
      assert_response :success
      assert_include 'revision blah blah', @response.body
    end
  end

  def test_property_should_not_be_editable_on_lightbox_for_a_readonly_user
    bob = User.find_by_login('bob')
    login_as_bob
    with_new_project do |project|
      project.add_member(bob, :readonly_member)
      prop = setup_text_property_definition("some property")
      card = create_card!(:name => "foo", "some property" => "hello there")
      xhr :get, :popup_show, :project_id => project.identifier, :number => card.number

      assert_response :success
      assert_include "some property", @response.body
      assert_include "hello there", @response.body
      assert_include "property-in-popup", @response.body
      assert_not_include "property-definition", @response.body
    end
  end

  def test_readonly_member_cannot_update_property_in_lightbox
    card = @project.cards.create!(:name => 'hi there', :card_type => @project.card_types.first, :cp_status => "goodbye")
    @bob = User.find_by_login('bob')
    @project.add_member(@bob, :readonly_member)
    login_as_bob

    assert_equal "goodbye", card.cp_status

    assert_raise(ErrorHandler::UserAccessAuthorizationError) do
      post :update_property_on_lightbox,
           :project_id => @project.identifier,
           :card => card.id,
           :property_value => "hello",
           :property_name => "status"
    end

    assert_equal "goodbye", card.reload.cp_status
  end

  def test_property_should_be_editable_on_lightbox_for_a_fulluser
    bob = User.find_by_login('bob')
    login_as_bob
    with_new_project do |project|
      project.add_member(bob, :full_member)
      prop = setup_text_property_definition("some property")
      card = create_card!(:name => "foo", "some property" => "hello there")
      xhr :get, :popup_show, :project_id => project.identifier, :number => card.number

      assert_response :success
      assert_include "some property", @response.body
      assert_include "hello there", @response.body
      assert_include "property-definition", @response.body
    end
  end

  def test_can_change_property_on_card_lightbox
    card = @project.cards.create!(:name => 'hi there', :card_type => @project.card_types.first)
    post :update_property_on_lightbox, :project_id => @project.identifier, :card => card.id,
          :property_value => "hello", :property_name => 'status', :style => 'grid'

    assert_equal 'hello', card.reload.cp_status
    assert_rjs 'replace', 'card-properties'
    assert_rjs 'replace', 'color-legend-container'
    assert_rjs 'replace', 'filters-panel'
    assert_rjs 'replace', 'card-description'
    assert_match /\$\("card_results"\)\.update/, @response.body
    assert_match /ParamsController\.update/, @response.body
  end

  def test_can_update_card_type_on_card_preview_lightbox
    story = @project.card_types.create(:name => 'story')
    feature = @project.card_types.create(:name => 'feature')
    card = @project.cards.create!(:name => 'hey hey', :card_type => story)
    post :update_property_on_lightbox, :property_name => 'Type', :property_value => feature.name, :project_id => @project.identifier, :card => card.id
    assert_equal feature.name, card.reload.card_type_name
  end

  def test_render_error_message_when_update_property_on_lightbox_with_deleted_card_id
    post :update_property_on_lightbox, :project_id => @project.identifier, :card => 12342423423,
          :property_value => "hello", :property_name => 'status'
    assert_response :ok
    assert_match /Card may have been destroyed by someone else\./, @response.body
  end

  def test_render_error_message_when_update_property_on_lightbox_failed
    status = @project.find_property_definition('status')
    status.update_attribute(:restricted, true)
    card = @project.cards.create!(:name => 'hi there', :card_type_name => 'Card')
    post :update_property_on_lightbox, :project_id => @project.identifier, :card => card.id,
          :property_value => "hello1", :property_name => 'status'

    assert_response :ok
    assert_match /showSavePropertyErrorMessage/, @response.body
    assert_match /"<b>Status<\/b> is restricted to/, @response.body
  end

  def test_should_not_show_hidden_property
    login_as_admin
    with_new_project do |project|
      prop = setup_text_property_definition('revision blah blah', :hidden => true)
      card = create_card!(:name => 'foo', 'revision blah blah' => 'r23030')
      xhr :get, :popup_show, :project_id => project.identifier, :number => card.number
      assert_response :success
      assert_not_include 'revision blah blah', @response.body
    end
  end

  def test_should_render_transition_forms_when_no_referer_is_there
    login_as_admin
    with_new_project do |project|
      card = create_card!(:name => 'foo')
      xhr :get, :popup_show, :project_id => project.identifier, :number => card.number

      assert_response :success
      assert_include 'transition_popup_form', @response.body
      assert_include 'transition_execute_form', @response.body
    end
  end

  def test_should_render_transition_forms_when_referer_is_present_but_is_not_grid_list_or_hierarchy_view
    login_as_admin
    with_new_project do |project|
      card = create_card!(:name => 'foo')
      @request.env['HTTP_REFERER'] = 'http://example.com/cards/'
      xhr :get, :popup_show, :project_id => project.identifier, :number => card.number

      assert_response :success
      assert_include 'transition_popup_form', @response.body
      assert_include 'transition_execute_form', @response.body
    end
  end

  def test_should_not_render_transition_forms_when_referer_is_present_and_is_grid_list_or_hierarchy_view
    login_as_admin
    with_new_project do |project|
      card = create_card!(:name => 'foo')
      %w(grid list hierarchy).each do |view|
        @request.env['HTTP_REFERER'] = "http://example.com/cards/#{view}?foo=bar"
        xhr :get, :popup_show, :project_id => project.identifier, :number => card.number

        assert_response :success
        assert_not_include 'transition_popup_form', @response.body
        assert_not_include 'transition_execute_form', @response.body
      end
    end
  end

end
