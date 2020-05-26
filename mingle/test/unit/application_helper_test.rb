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

class ApplicationHelperTest < ActionController::TestCase
  include RenderableTestHelper::Unit,
          TreeFixtures::PlanningTree,
          ApplicationHelper, FileColumnHelper
  attr_accessor :output_buffer  # capture method needs this; am putting this here instead of including ActionView::Base

  def setup
    @member = login_as_member
    @project = first_project
    @project.activate
    @url_for_returning = ""
  end

  def test_options_for_droplist_for_user_property_definition
    with_new_project do |project|
      setup_user_definition('dev')
      project.users.each do |user|
        assert options_for_droplist(project.find_property_definition('dev')).include?([user.name, user.id.to_s])
      end
    end
  end

  def test_js_options
    assert_equal({:selectOptions => 'something'}.to_json, js_options(:select_options => 'something'))
  end

  def test_initial_value_for_droplist_is_case_insensitive
    values = [['Foo', 'Foo'], ['bar', 'bar']]
    assert_equal values.first, initial_value_for_drop_list(nil, values)
    assert_equal 'Foo', initial_value_for_drop_list('foo', values).first
    assert_equal 'bar', initial_value_for_drop_list('bar', values).first
    assert_equal 'not exist', initial_value_for_drop_list('not exist', values).first
  end

  def test_hidden_view_tags
    with_new_project do |project|
      setup_property_definitions :status =>[], :iteration => []
      view = CardListView.find_or_construct(project, :columns => 'status,iteration',
        :sort => 'status', :order => 'asc', :filters => ["[iteration][is][5]", "[release][is][one]"])
      actual_tags = hidden_view_tags(view)
      assert actual_tags.index(expected_hidden_form_input('columns', 'columns', 'status,iteration'))
      assert actual_tags.index(expected_hidden_form_input('sort', 'sort', 'status'))
      assert actual_tags.index(expected_hidden_form_input(nil, 'filters[]', '[iteration][is][5]'))
      assert actual_tags.index(expected_hidden_form_input(nil, 'filters[]', '[release][is][one]'))
    end
  end

  def test_fix_word_break
    assert_equal "<wbr>thisisastr</wbr><wbr>ingwithout</wbr>wordbreak", fix_word_break('thisisastringwithoutwordbreak')
  end

  def test_javascript_with_rescue
    assert_match(/<script.*>.*try.*foo().*catch.*<\/script>/m, javascript_with_rescue('foo()'))
    assert !(/<script.*<script/m =~ javascript_with_rescue(javascript_tag('foo()')))
    assert !(/<\/script.*<\/script/m =~ javascript_with_rescue(javascript_tag('foo()')))
    assert !(/CDATA.*CDATA/m =~ javascript_with_rescue(javascript_tag('foo()')))
    self.output_buffer = javascript_with_rescue('foo()')
    assert_equal javascript_with_rescue('foo()'), self.output_buffer
  end

  def test_new_value_dropdown_message
    assert_equal "Enter value...", new_value_dropdown_message(@project.find_property_definition('id'))
    assert_equal "Enter value...", new_value_dropdown_message(@project.find_property_definition('start date'))
    assert_equal "New value...", new_value_dropdown_message(@project.find_property_definition('status'))
  end

  def test_cycle_on_index
    assert_equal 'black', cycle_on_index(0, 'black', 'red')
    assert_equal 'red',   cycle_on_index(1, 'black', 'red')
    assert_equal 'black', cycle_on_index(2, 'black', 'red')
    assert_equal 'white', cycle_on_index(2, 'black', 'red', 'white')
  end

  def test_relationship_property_to_remaining_tree_property_map
    with_three_level_tree_project do |project|
      @project = project
      map = tree_relationships_map(:html_id_postfix => "_sets")

      planning_release = project.find_property_definition('planning release')
      planning_iteration = project.find_property_definition('planning iteration')

      assert_equal ["#{planning_iteration.html_id}_sets"], map["#{planning_release.html_id}_sets"][:otherRelationshipsInTree]
      assert_equal ["#{planning_release.html_id}_sets"], map["#{planning_iteration.html_id}_sets"][:otherRelationshipsInTree]
    end
  end

  def test_relationship_property_to_remaining_tree_property_map_can_be_restricted_by_a_card_type
    with_filtering_tree_project do |project|
      @project = project
      type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types

      planning_release = project.find_property_definition('planning release')
      planning_iteration = project.find_property_definition('planning iteration')
      planning_story = project.find_property_definition('planning story')
      planning_task = project.find_property_definition('planning task')

      map = tree_relationships_map
      assert_equal ["#{planning_release.html_id}", "#{planning_iteration.html_id}", "#{planning_task.html_id}"], map["#{planning_story.html_id}"][:otherRelationshipsInTree]

      map = tree_relationships_map(:restricted_by_card_type => type_task)
      assert_equal ["#{planning_release.html_id}", "#{planning_iteration.html_id}"], map["#{planning_story.html_id}"][:otherRelationshipsInTree]

      map = tree_relationships_map(:restricted_by_card_type => type_story)
      assert_equal ["#{planning_release.html_id}"], map["#{planning_iteration.html_id}"][:otherRelationshipsInTree]
    end
  end

  def test_value_field_does_not_have_tree_belongings_value_field_when_tree_belongings_not_included
    with_three_level_tree_project do |project|
      @project = project
      map = tree_relationships_map(:html_id_prefix => "edit_", :include_tree_belongings => false)
      planning_release = project.find_property_definition('planning release')
      assert_equal "edit_treerelationshippropertydefinition_#{planning_release.id}_field", map["edit_treerelationshippropertydefinition_#{planning_release.id}"][:valueField]
    end
  end

  def test_relationship_index
    with_three_level_tree_project do |project|
      @project = project

      tree_configuration = project.tree_configurations.first
      planning_release = project.find_property_definition('planning release')
      planning_iteration = project.find_property_definition('planning iteration')

      map = tree_relationships_map(:html_id_postfix => "_sets", :include_tree_belongings => true)
      assert_equal 3, map.size
      assert_equal 0, map["tree_belonging_property_definition_#{tree_configuration.id}_sets"][:index]
      assert_equal 1, map["#{planning_release.html_id}_sets"][:index]
      assert_equal 2, map["#{planning_iteration.html_id}_sets"][:index]
    end
  end

  def test_relationship_value_field_map
    with_three_level_tree_project do |project|
      @project = project
      map = tree_relationships_map(:html_id_postfix => '_sets', :include_tree_belongings => true)
      planning_release = project.find_property_definition('planning release')
      planning_iteration = project.find_property_definition('planning iteration')
      tree_configuration = project.tree_configurations.first

      assert_equal 3, map.size
      assert_equal "treerelationshippropertydefinition_#{planning_release.id}_sets_field", map["treerelationshippropertydefinition_#{planning_release.id}_sets"][:valueField]
      assert_equal "treerelationshippropertydefinition_#{planning_iteration.id}_sets_field", map["treerelationshippropertydefinition_#{planning_iteration.id}_sets"][:valueField]
      assert_equal "tree_belonging_property_definition_#{tree_configuration.id}_sets_field", map["tree_belonging_property_definition_#{tree_configuration.id}_sets"][:valueField]
    end
  end

  def test_tree_name_label
    assert_equal "some tree".bold, tree_name_label("some tree")
    assert_equal "#{'other'.bold} tree", tree_name_label("other")
    assert_equal "#{'other tree hello'.bold} tree", tree_name_label("other tree hello")
  end

  def test_styled_box
    assert_nil(styled_box{})
    assert_nil(styled_box{
      %{
        <a href="http://www.thoughtworks-studios.com/mingle/2.0.1/help/card_properties.html" title="Click to open help document" style="" class="page-help-at-action-bar" target="blank">Help</a>
        <div class='clear-both'><!-- Clear floats --></div>
        <span id='xx'> </span>
        <img id="top_spinner" class="spinner" style="display: none;" src="/images/spinner.gif?1211177218" alt="Spinner"/>
      }
    })
  end

  def test_all_contents_from_special_header_wiki_page_should_be_ignored_when_user_role_is_readonly_or_anonymous
    user = User.find_by_email('member@email.com')
    special_header = @project.pages.create(:name => 'Special:HeaderActions', :content => 'I am very special')
    assert_include "I am very special", header_actions_page_with_user_access

    login_as_proj_admin
    assert_include "I am very special", header_actions_page_with_user_access

    @project.add_member(user, :readonly_member)
    login_as_member
    assert header_actions_page_with_user_access.nil?

    @project.update_attribute(:anonymous_accessible, true)
    logout_as_nil
    assert header_actions_page_with_user_access.nil?
  end

  def test_special_header_should_be_nil_when_none_exists
    user = User.find_by_email('member@email.com')
    special_header = @project.pages.create(:name => 'Special:HeaderActions', :content => '')
    assert_nil header_actions_page_with_user_access
  end

  def test_should_not_show_special_header_in_anonymous_when_the_user_is_login_but_not_the_member_of_the_project
    user = User.find_by_email('member@email.com')
    special_header = @project.pages.create(:name => 'Special:HeaderActions', :content => 'I am very special')
    @project.remove_member(user)
    @project.update_attribute(:anonymous_accessible, true)
    login_as_member
    assert header_actions_page_with_user_access.nil?
  end

  def test_mingle_admin_should_have_right_to_show_special_header
    special_header = @project.pages.create(:name => 'Special:HeaderActions', :content => 'I am very special')
    login_as_admin
    assert_include "I am very special", header_actions_page_with_user_access
  end

  def test_image_tag_for_user_icon_has_img_alt_text_as_filename_when_file_no_longer_exist
    MingleConfiguration.with_secure_site_u_r_l_overridden_to("https://test.com") do
      @member.update_attribute :icon, attachment = sample_attachment("user_icon.jpg")
      icon_tag = image_tag_for_user_icon(@member.reload)
      assert_include "alt=\"user_icon.jpg", icon_tag
      assert_include "src=\"https://test.com#{@member.icon_path}", icon_tag
    end
  end

  def test_replace_card_links_should_support_cross_project_card_link
    assert_equal "<a href=\"\" class=\"card-link-3\">#{@project.identifier}/#3</a>", replace_card_links("#{@project.identifier}/#3")
    assert_equal "<a href=\"\" class=\"card-link-3\">#{@project.identifier.upcase}/#3</a>", replace_card_links("#{@project.identifier.upcase}/#3")
  end

  def test_line_breaks_should_be_replaced_by_html_line_breaks
    assert_equal "<br/>uts", html_line_breaks("\nuts")
    assert_equal "conker<br/>uts", html_line_breaks("conker\nuts")
    assert_equal "conker<br/>uts<br/>", html_line_breaks("conker\nuts\n")
    assert_equal "conker <br/>uts <br/>", html_line_breaks("conker \nuts \n")
    assert_equal "I<br/>like<br/>lines&nbsp;", html_line_breaks("I\nlike\nlines&nbsp;")
  end

  def test_format_as_discussion_item_bug_10808
    expected = %{<a href="" class="card-tool-tip card-link-1" data-card-name-url="">#1</a><br/><br/><a href="http://www.google.com" target="_blank">www.google.com</a>}
    result = format_as_discussion_item("#1\n\nwww.google.com")
    assert_equal expected, result
  end

  def test_replace_card_links
    assert_equal %{<a href="" class="card-tool-tip card-link-1" data-card-name-url="">#1</a>/<a href=\"\" class="card-tool-tip card-link-2" data-card-name-url="">#2</a>}, replace_card_links("#1/#2")

    assert_equal %{[<a href="" class="card-tool-tip card-link-1" data-card-name-url="">#1</a>]}, replace_card_links("[#1]")
    assert_equal %{{<a href="" class="card-tool-tip card-link-1" data-card-name-url="">#1</a>}}, replace_card_links("{#1}")

    assert_equal %{[hello/<a href="" class="card-tool-tip card-link-1" data-card-name-url="">#1</a>] world}, replace_card_links("[hello/#1] world")
  end

  def test_contextual_help_url_should_use_controller_action
    params = { :controller => "murmurs", :action => "index" }
    assert_equal "/contextual_help/murmurs_index.html", contextual_help_location(params)

    params = { :controller => "cards", :action => "list" }
    assert_equal "/contextual_help/cards_list.html",  contextual_help_location(params)
  end

  def test_contextual_help_url_should_use_style_params_for_grid_view
    params = { :controller => "cards", :action => "list", :style => "grid" }
    assert_equal "/contextual_help/cards_grid.html", contextual_help_location(params)

    params = { :controller => "cards", :action => "grid" }
    assert_equal "/contextual_help/cards_grid.html", contextual_help_location(params)

    params = { :controller => "cards", :action => "show", :style => "grid" }
    assert_equal "/contextual_help/cards_show.html", contextual_help_location(params)
  end

  def test_contextual_help_url_should_use_view_if_available
    @view  = CardListView.find_or_construct(@project, { :style => 'grid' })
    @view.name = "my view"
    @view.save!

    params = { :controller => 'cards', :view => 'my view' }
    assert_equal "/contextual_help/cards_grid.html", contextual_help_location(params)
  end

  def test_contextual_help_url_should_detect_tree_name_parameter
    params = { :controller => 'cards', :action => 'list', :tree_name => 'some_tree_name' }
    assert_equal "/contextual_help/cards_list_with_tree.html", contextual_help_location(params)
  end

  def test_contextual_help_should_use_style_params_for_hierarchy_view
    params = { :controller => "cards", :action => "list", :style => "hierarchy", :tree_name => "some_tree_name" }
    assert_equal "/contextual_help/cards_hierarchy_with_tree.html", contextual_help_location(params)
  end

  def test_contextual_help_should_use_style_params_for_tree_view
    params = { :controller => "cards", :action => "list", :style => "tree", :tree_name => "some_tree_name" }
    assert_equal "/contextual_help/cards_tree_with_tree.html", contextual_help_location(params)
  end

  def test_link_to_with_long_url_handling_should_record_url_as_an_alternative_attribute_so_that_ie_do_not_truncated_it
    @url_for_returning = "http://url1"
    assert_not_include "_fhref", link_to_with_long_url_handling("short link", {})
    @url_for_returning = "http://url1/#{'a' * 3000}"
    assert_include "_fhref=\"http://url1/#{'a' * 3000}\"", link_to_with_long_url_handling("long link", {})
  end

  def test_request_a_project_resource
    assert request_a_project_resource?("/projects/abc")
    assert request_a_project_resource?("/projects/abc/cards/list")
    assert !request_a_project_resource?("/admin/projects/abc/cards/list")
    with_constant_set('CONTEXT_PATH', '/mingle') do
      assert !request_a_project_resource?("/projects")
      assert !request_a_project_resource?("/mingle/projects")
      assert request_a_project_resource?("/mingle/projects/abc")
    end
  end

  def test_time_lapsed_in_words
    current_date_time = DateTime.parse('Wed Oct 05 12:00:00 +0000 2016')
    Timecop.freeze(current_date_time) do
      assert_equal 'yesterday at 23:00 UTC', date_time_lapsed_in_words(current_date_time.to_time - 13.hours)
      assert_equal 'today at 07:00 UTC', date_time_lapsed_in_words(current_date_time.to_time - 5.hours)
      assert_equal 'yesterday at 12:00 UTC', date_time_lapsed_in_words(current_date_time.to_time - 1.day)
      assert_equal 'on 03 Oct 2016 at 12:00 UTC', date_time_lapsed_in_words(current_date_time.to_time - 2.day)

      assert_equal 'today at 05:30 IST', date_time_lapsed_in_words(current_date_time.to_time - 12.hours, '%d %b %Y', 'Chennai')
      assert_equal 'yesterday at 05:30 IST', date_time_lapsed_in_words(current_date_time.to_time - 36.hours, '%d %b %Y', 'Chennai')
      assert_equal 'on 03 Oct 2016 at 23:30 IST', date_time_lapsed_in_words(current_date_time.to_time - 42.hours, '%d %b %Y', 'Chennai')
      assert_equal 'yesterday at 23:00 PDT', date_time_lapsed_in_words(current_date_time.to_time - 6.hours, '%d %b %Y', 'Pacific Time (US & Canada)')
    end
  end

  def test_time_lapsed_in_words_for_project
    with_new_project(:time_zone => 'Pacific Time (US & Canada)', :date_format => '%d/%m/%y') do |project|
      current_date_time = DateTime.parse('Wed Oct 05 12:00:00 +0000 2016')
      Timecop.freeze(current_date_time) do
        assert_equal 'yesterday at 23:00 UTC', date_time_lapsed_in_words_for_project(current_date_time.to_time - 13.hours, nil)
        assert_equal 'on 03/10/16 at 08:00 PDT', date_time_lapsed_in_words_for_project(current_date_time.to_time - 45.hours, project)
      end
    end
  end

  def test_short_duration_in_words
    assert_equal "5 seconds", short_duration_in_words(5)
    assert_equal "1 minutes", short_duration_in_words(60)
    assert_equal "3 minutes 25 seconds", short_duration_in_words(60 * 3 + 25)
  end

  def test_prepend_hosts_and_proto_to_absolute_path_with_site_url
    MingleConfiguration.with_site_u_r_l_overridden_to("http://test.com") do
      MingleConfiguration.with_secure_site_u_r_l_overridden_to("") do
        assert_equal "http://test.com/foo/bar", prepend_protocol_with_host_and_port("/foo/bar")
      end
      MingleConfiguration.with_secure_site_u_r_l_overridden_to("https://test.com") do
        assert_equal "https://test.com/foo/bar", prepend_protocol_with_host_and_port("/foo/bar")
      end
    end
  end

  def test_prepend_hosts_and_proto_to_full_url_will_just_keep_url_as_it_as
    assert_equal "http://hostname.info:9090/foo/bar", prepend_protocol_with_host_and_port("http://hostname.info:9090/foo/bar")
  end

  def test_event_originator_should_check_for_event_source_only_for_card_version_event_type
    page = @project.pages.create(:name => 'History', :content => 'I am very special')
    page_version = page.versions.last

    assert_false event_originator(page_version).include? ('via slack')
  end

  def test_event_originator_should_contain_additional_field_if_slack_integration_is_enabled
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card_version = card.versions.last
    card_version.event.details = {:event_source => 'slack'}

    assert event_originator(card_version).include? ('via slack')

  end

  def test_user_notification_verifies_required_parts_are_present
    assert !user_notification?

    MingleConfiguration.overridden_to(:user_notification_heading => "heading", :user_notification_avatar => "foo.jpg", :user_notification_body => "hello world") do
      assert user_notification?
    end

    # url is optional
    MingleConfiguration.overridden_to(:user_notification_heading => "heading", :user_notification_avatar => "foo.jpg", :user_notification_body => "hello world", :user_notification_url => "http://google.com") do
      assert user_notification?
    end

    MingleConfiguration.overridden_to(:user_notification_heading => "heading", :user_notification_url => "http://google.com") do
      assert !user_notification?
    end
  end

  def test_remaining_time_for_mingle_eol_should_return_11_months_and_30_days
    time = DateTime.new(2018, 8, 1, 12, 0, 0)
    Timecop.travel(time) do
      assert_equal '11 months and 30 days', remaining_time_for_mingle_eol
    end
  end

  def test_remaining_time_for_mingle_eol_should_return_7_months
    time = DateTime.new(2018, 12, 31, 12, 0, 0)
    Timecop.travel(time) do
      assert_equal '7 months', remaining_time_for_mingle_eol
    end
  end

  def test_remaining_time_for_mingle_eol_should_return_6_months_and_30_days
    time = DateTime.new(2019, 1, 1, 12, 0, 0)
    Timecop.travel(time) do
      assert_equal '6 months and 30 days', remaining_time_for_mingle_eol
    end
  end

  def test_remaining_time_for_mingle_eol_should_return_20_days
    time = DateTime.new(2019, 7, 11, 12, 0, 0)
    Timecop.travel(time) do
      assert_equal '20 days', remaining_time_for_mingle_eol
    end
  end

  def test_remaining_time_for_mingle_eol_should_return_1_month_and_20_days
    time = DateTime.new(2019, 6, 10, 12, 0, 0)
    Timecop.travel(time) do
      assert_equal '1 month and 20 days', remaining_time_for_mingle_eol
    end
  end

  def test_remaining_time_for_mingle_eol_should_return_1_day
    time = DateTime.new(2019, 7, 30, 12, 0, 0)
    Timecop.travel(time) do
      assert_equal '1 day', remaining_time_for_mingle_eol
    end
  end

  def controller
    OpenStruct.new(:request =>
                   OpenStruct.new(:protocol => "https://",
                                  :host_with_port => "host.com:8080"))
  end

  def droplist_javascript(options)
    javascript_with_rescue "new DropList(#{js_options options});"
  end

  def expected_hidden_form_input(id, name, value)
    id_attr = id.present? ? "id=\"#{id}\" " : nil
    "<input #{id_attr}name=\"#{name}\" type=\"hidden\" value=\"#{value}\" />"
  end

  def url_for(options={})
    @url_for_returning
  end

  def params
    @params || {}
  end

end
