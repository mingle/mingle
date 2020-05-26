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

class CardsControllerEditingTest < ActionController::TestCase
  include RenderableTestHelper::Functional

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def test_entering_macro_in_card_description_correctly_sets_has_macro_flag
    card = create_card!(:name => "has macro?")

    post :update, :project_id => @project.identifier, :id => card.id, :card => {:description => "no macros here"}
    follow_redirect
    assert_false card.reload.has_macros

    post :update, :project_id => @project.identifier, :id => card.id, :card => {:description => "with a macro #{create_raw_macro_markup("{{ project }}")}"}
    follow_redirect
    assert card.reload.has_macros
    assert card.formatted_content(view_helper).include?(@project.identifier)
  end

  def test_macros_containing_special_characters_evaluate_correctly_and_are_saved_unescaped
    with_new_project do |project|
      login_as_admin
      setup_date_property_definition("<start_at>")
      content = %Q[{{value query: SELECT "<start_at>" }}]
      card = create_card!(:name => "macro with special characters")
      card.update_attribute(:cp_1, "05 Mar 2013")

      post :update, :project_id => project.identifier, :id => card.id, :card => {:description => create_raw_macro_markup(content)}
      follow_redirect

      assert_equal "05 Mar 2013", card.reload.formatted_content(view_helper)
      assert_include content, card.description

      title_with_special_characters = 'I have > and < and & in my title'
      create_card!(:name => title_with_special_characters)
      new_content = '{{ value query: select name where name = "I have > and < and & in my title"}}'
      post :update, :project_id => project.identifier, :id => card.id, :card => {:description => create_raw_macro_markup(new_content)}
      follow_redirect

      doc = Nokogiri::HTML::DocumentFragment.parse(@response.body)
      expected_title = Nokogiri::HTML::DocumentFragment.parse(title_with_special_characters).text

      assert_match expected_title, doc.css('#card-description').text
      assert_include new_content, card.reload.description
    end
  end

  def test_edit_should_not_show_message_that_latest_is_shown_if_coming_from_version_is_not_specified
    card = create_card!(:name => 'timmy')
    card.description = 'foo'
    card.save!
    get :edit, :project_id => @project.identifier, :number => card.number
    assert_response :success
    assert_nil flash[:info]
  end

  def test_edit_should_show_card_not_exist_error_when_card_number_not_found
    get :edit, :project_id => @project.identifier, :number => 888
    assert_equal 'Card 888 does not exist.', flash[:error]
    assert_redirected_to :action => "list"
  end


  def test_should_allow_deletion_of_multiple_cards_in_edit_mode
    card = create_card!(:name => 'test card')
    card.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    card.save!
    attachments_ids = card.attachments.collect(&:id)
    post :update, :project_id => @project.identifier, :id => card.id, :deleted_attachments => { 'sample_attachment.txt' => 'true', 'sample_attachment.gif' => 'true' }
    follow_redirect
    assert card.reload.attachments.empty?
    attachments_ids.each do |attachment_id|
      assert_no_tag :a, :attributes => {:id => "attachment_#{attachment_id}" }
    end
  end

  def test_redirect_to_add_another_card_after_updated_card
    card = create_card!(:name => 'test card')
    post :update, :project_id => @project.identifier, :id => card.id, :properties => {:priority => 'high'}, :add_another => true
    assert_equal 'high', card.reload.cp_priority
    assert_redirected_to :action => :new, :properties => {:Priority => 'high'}
  end

  def test_save_add_another_card_should_copy_all_properties_including_locked
    @project.find_property_definition('release').update_attribute :restricted, true
    card = create_card!(:name => 'test card', :release => 1)

    post :update, :project_id => @project.identifier, :id => card.id, :properties => {:priority => 'high', :Type => 'Card'}, :add_another => 'true'
    assert_redirected_to(:action => 'new', :properties => {:Type => 'Card', :Priority => 'high', :Release => "1"}, :project_id => @project.identifier)
  end

  def test_card_update_should_escape_manually_entered_macros
    card = @project.cards.first
    post :update, :project_id => @project.identifier, :id => card.id, :card => {:description => "{{ project }}"}
    assert_equal ManuallyEnteredMacroEscaper.new("{{ project }}").escape, card.reload.description
  end

  def test_card_update_should_preserve_macros_created_by_editor
    card = @project.cards.first
    post :update, :project_id => @project.identifier, :id => card.id, :card => {:description => create_raw_macro_markup("{{ project }}")}
    assert_equal "{{ project }}", card.reload.description
  end

  def test_update_for_js_format_should_respond_with_updated_card_resource_and_no_flash
    card = @project.cards.first
    xhr :post, :update, :project_id => @project.identifier, :id => card.id, :card => {:name => 'my new name', :description => 'new content'}, :format => "json"
    assert_response :ok
    json = JSON.parse(@response.body)
    assert_equal 'my new name', json['name']
    assert_equal card.number, json['number']
    assert_nil flash[:info]
  end

  def test_update_for_js_format_should_response_422_if_attributes_is_invalid
    card = @project.cards.first
    xhr :post, :update, :project_id => @project.identifier, :id => card.id, :card => {:name => nil}
    assert_response :unprocessable_entity
  end

  def test_update_for_js_format_should_response_404_if_card_can_not_be_found
    xhr :post, :update, :project_id => @project.identifier, :id => -1, :card => {:name => 'foo'}
    assert_response :not_found
  end

  # bug 3066
  def test_save_add_another_card_should_copy_multiword_properties_correctly
    login_as_admin
    with_new_project do |project|
      @project = project
      setup_numeric_property_definition('two word', [1, 2, 3]).update_attributes(:card_types => @project.card_types)
      @project.reload
      card = @project.cards.create!(:name => 'test card', :cp_two_word => 1, :card_type_name => 'Card')

      post :update, :project_id => @project.identifier, :id => card.id, :properties => {:Type => 'Card'}, :add_another => 'true'
      assert_redirected_to(:action => 'new', :properties => {"Type" => 'Card', "two word" => "1"}, :project_id => @project.identifier)
      follow_redirect
    end
  end

  # bug 3062
  def test_save_add_another_card_should_copy_relationship_properties_correctly
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      story2 = project.cards.find_by_name('story2')
      release1 = project.cards.find_by_name('release1')

      post :update, :project_id => project.identifier, :id => story2.id, :properties => {:Type => 'Story'}, :add_another => 'true'
      assert_redirected_to(:action => 'new', :properties => {"size"=>"3", "Type" => 'Story', "Planning iteration" => iteration1.number, "Planning release" => release1.number},
                           :project_id => project.identifier)
      follow_redirect # this used to blow up
    end
  end

  # bug 3332.
  def test_save_add_another_card_should_copy_tags
    card = create_card!(:name => 'test card', :release => 1)
    post :update, :project_id => @project.identifier, :id => card.id, :tagged_with => 'hey,now', :properties => {}, :add_another => 'true'
    assert_redirected_to(:action => 'new', :tagged_with => 'hey,now', :project_id => @project.identifier)
  end

  def test_should_not_allow_strings_faking_for_numbers_for_numeric_properties_on_cards
    card = @project.cards.create!(:name => 'Card 1', :card_type => @project.card_types.first, :cp_release => '1')

    post :update, :project_id => @project.identifier, :id => card.id, :properties => {'release' => '2 llamas'}, :changed_property => 'release'
    assert_error "Release: <b>2 llamas</b> is an invalid numeric value"
  end

  def test_can_set_protected_properties_when_creating_new_card
    @project.find_property_definition('priority').update_attribute(:transition_only, true)
    post :create, :project_id => @project.identifier, :card => {:name => 'a high open card', :card_type => @project.card_types.first},
      :properties => {:priority => 'high', :status => 'open'}
    assert_redirected_to :action => 'list'
    card = @project.reload.cards.find_by_name('a high open card')
    assert_equal 'high', card.cp_priority
    assert_equal 'open', card.cp_status
  end

  def test_create_should_apply_card_defaults_to_hidden_properties
    @status = @project.find_property_definition('status')
    @status.update_attribute :hidden, true

    card_defaults = @project.card_types.first.card_defaults
    card_defaults.update_properties(:status => 'open')
    card_defaults.save!

    post :create, :project_id => @project.identifier, :card => {:name => 'card name', :card_type => @project.card_types.first}, :properties => {}

    card = @project.cards.find_by_name('card name')
    assert_equal 'open', @status.value(card)
  end

  # bug 3070
  def test_update_with_error_and_attachment_will_reset_attachment_widget_to_appear_as_if_there_are_no_attachments
    card_type = @project.card_types.first
    card = @project.cards.create!(:name => 'hi', :card_type => card_type)

    post :update, :project_id => @project.identifier, :id => card.id, :card => {:name => ''}, :properties => {:Type => card_type.name},
         :attachments => {"0" => sample_attachment('1.txt')}

    assert_select "a", :text => '1.txt', :count => 0
    assert_info "You will need to reattach the file #{'1.txt'.html_bold}"
  end

  def test_should_show_list_of_tags_on_edit_view
    card = create_card!(:name => 'i am card')
    card.tag_with(['foo', 'bar'])
    card.save!

    get :edit, :project_id => @project.identifier, :number => card.number
    assert_response :ok
    assert_select '.tageditor li', :text => 'foo'
    assert_select '.tageditor li', :text => 'bar'
  end

  def test_should_update_card_relationship_properties_with_ids_of_existing_cards
    login_as_admin
    with_new_project do |project|
      setup_card_relationship_property_definition('generic')
      generic = project.find_property_definition('generic')
      card = create_card!(:name => 'the name', :card_type_name => project.card_types.first.name)
      post :update, :project_id => project.identifier, :id => card.id, :card => {:name => 'foo'}, :properties => {'Type' => project.card_types.first.name, 'generic' => card.id}
      assert :success
      assert_equal card, card.reload.cp_generic
    end
  end

  def test_should_cause_error_if_attempting_to_update_card_relationship_properties_with_ids_of_non_existent_cards
    login_as_admin
    with_new_project do |project|
      setup_card_relationship_property_definition('generic')
      card = create_card!(:name => 'the name', :card_type_name => project.card_types.first.name)

      post :update, :project_id => project.identifier, :id => card.id, :card => {:name => 'foo'}, :properties => {'Type' => project.card_types.first.name, 'generic' => 'foo'}
      assert :success
      assert_error 'generic: Card properties can only be updated with ids of existing cards: cannot find card or card version with id 0'
    end
  end

  def test_update_should_create_card_comment_murmur_if_murmur_this_flag_is_set
    card = @project.cards.first
    post :update, :id => card.id, :comment => {:content => "Murmured comment"}, :project_id => @project.identifier
    card.reload
    assert_equal "Murmured comment", card.versions.last.comment
    assert_equal 1, Murmur.count(:all, :conditions => ["origin_type = ? AND origin_id = ? AND project_id = ?", card.class.name, card.id, @project.id])
  end

  def test_create_card_comment_murmur_should_cope_when_card_is_not_found
    @project.with_active_project do
      assert_nothing_raised do
        post :update, :id => -1, :comment => "Murmured comment", :project_id => @project.identifier
      end
    end
  end

  def test_should_not_be_able_to_add_illegal_parenthesis_values_inline
    jimmy_walker = @project.cards.create!(:name => 'jimmy walker', :card_type => @project.card_types.first, :cp_status => expected_status = 'open')
    #todo temp solution because we do not support using plv to edit card yet
    begin
      post :update, :project_id => @project.identifier, :id => jimmy_walker.id, :properties => {'status' => '(dyno-mite)'}, :changed_property => 'status'
    rescue RuntimeError => e
      assert_equal "status: #{'(dyno-mite)'.html_bold} is not a defined project variable", e.message
    end
    assert_equal expected_status, jimmy_walker.reload.cp_status
  end

  def test_should_redirect_to_list_when_getting_update_action
    get :update, :project_id => @project.identifier
    assert_redirected_to :action => :list, :project_id => @project.identifier
  end

  def test_edit_redcloth_card_will_convert_it_to_html
    card_type = @project.card_types.first
    card1 = @project.cards.create!(:name => "card1", :description => "h1. I am a header", :card_type => @project.card_types.first)
    card1.update_attribute :redcloth, true
    assert card1.redcloth

    get :edit, :number => card1.number, :project_id => @project.identifier
    assert_false card1.reload.redcloth
    assert_equal "<h1>I am a header</h1>", ckeditor_data
  end

end
