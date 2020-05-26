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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: mql, macro
class Scenario95MiscMqlTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PROJECT = 'project'
  TABLE_QUERY = 'table-query'
  INSERT_TABLE_QUERY = 'Insert Table Query'
  VALUE = 'value'
  INSERT_VALUE= 'Insert Value'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_95', :admins => [@project_admin_user], :users => [users(:project_member)],:read_only_users => [users(:bob)])
    login_as_proj_admin_user
  end

  # bug 2740 - not valid as of now... need to add diff test
  def ignored_test_can_use_project_macro_when_project_identifier_has_two_underscores_in_a_row
    wiki_text = %{
      <a href="/projects/{{ project }}/cards/list"> +Bug</a>
      <a href="/projects/{{ project  }}/cards/list">+Story</a>
    }

    @project.identifier = "some__2_0_project"
    @project.save!

    navigate_to_project_overview_page(@project)
    add_content_to_wiki(wiki_text)

    click_link("+Bug")
    assert_tab_highlighted("All")

    click_tab("Overview")
    click_link("+Story")
    assert_tab_highlighted("All")
  end

    def test_preview_for_THIS_Card_syntax
      setup_card_relationship_property_definition('related_card')
      cookie = create_card!(:name => 'cookie')
      cracker = create_card!(:name => 'cracker', :related_card => cookie.id)

      open_card(@project, cookie.number)
      click_edit_link_on_card
      select_macro_editor(INSERT_VALUE)
      type_macro_parameters(VALUE, :query => "select name where related_card = this card", :project => '')
      preview_macro
      preview_content_should_include(cracker.name)
    end

    def test_error_message_when_inproper_src_parameter_value_is_given_in_google_map_macro
      no_url_provided  = ""
      unrecgonized_url = "This is not a URL"
      url_but_not_goole_map = "http://www.thoughtworks.com"
      has_string_before_url = "abchttp://www.thoughtworks.com"

      Outline(<<-Examples) do | wrong_value_for_src_prameter    |
        | #{no_url_provided}              |
        | #{unrecgonized_url}             |
        | #{url_but_not_goole_map}        |
        | #{has_string_before_url}        |
        Examples
        open_project(@project.identifier)
        edit_overview_page
        add_google_maps_macro_and_saved_on(:src => wrong_value_for_src_prameter)
        assert_url_error_message_for_google_maps_macro
      end
    end

    def test_error_message_when_inproper_src_parameter_value_is_given_in_google_calendar_macro
      no_url_provided  = ""
      unrecgonized_url = "This is not a URL"
      url_but_not_goole_calendar = "http://www.thoughtworks.com"
      has_string_before_url = "abchttp://www.thoughtworks.com"

      Outline(<<-Examples) do | wrong_value_for_src_prameter    |
        | #{no_url_provided}              |
        | #{unrecgonized_url}             |
        | #{url_but_not_goole_calendar}   |
        | #{has_string_before_url}        |
        Examples
        open_project(@project.identifier)
        edit_overview_page
        add_google_calendar_macro_and_saved_on(:src => wrong_value_for_src_prameter)
        assert_url_error_message_for_google_calendar_macro
      end
    end

    #bug #9343 Make the "too many" messages consistent with other messages and increase the limit to 10 macros (instead of 4)
    def test_too_many_macros_warning_is_worded_correctly_and_help_is_a_link
      many_macro_description = "{{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }} {{ stack-bar-chart }}"
      expected_warning = "Loading more than 10 macros on a card or a page will slow down your system. To learn more, please visit help. Please be aware that in the future Mingle may prevent users from having more than 10 macros on cards or pages. To hide this message, please click here."

      card_containing_many_macros = create_card!(:name => 'many-macro card', :description => many_macro_description)
      open_card(@project, card_containing_many_macros.number)
      assert_info_message(expected_warning, :element_id => "too_many_macros_warning")
      help_link_locator = css_locator("#too_many_macros_warning a")
      @browser.assert_element_text(help_link_locator, "help")
      assert_html_link("too_many_macros.html", help_link_locator)
    end

    #9606
    def test_no_500_error_given_when_chart_name_is_invalid
      cherry = create_card!(:name => 'cherry')
      open_card_for_edit(@project, cherry)

      pie_filling = %{
        pie-chart *&$%%
          data: select name, COUNT(*)
          render_as_text: true
        }

      create_free_hand_macro(pie_filling)
      assert_mql_error_messages("Error in pie-chart macro: Please check the syntax of this macro. The macro markup has to be valid YAML syntax.")
    end

    #9606
    def test_chart_rendered_correctly_when_following_chart_with_invalid_name
      apple = create_card!(:name => 'apple')
      open_card_for_edit(@project, apple)

      daily_filling = %{
        daily-history-chart *^%$)_
            render_as_text: true
            aggregate: COUNT(*)
            start-date: 2011 Jan 10
            end-date: 2011 Jan 16
            series:
              - label:
                conditions: type = Card
      }

      pie_filling = %{
        pie-chart
          data: select name, COUNT(*)
          render_as_text: true
      }

      create_free_hand_macro(daily_filling)
      assert_mql_error_messages("Error in daily-history-chart macro: Please check the syntax of this macro. The macro markup has to be valid YAML syntax.")
      open_card_for_edit(@project, apple)
      create_free_hand_macro(pie_filling)
      save_card
      with_ajax_wait { reload_current_page }
      click_link_with_ajax_wait("Chart Data")
      assert_chart("slice_sizes", "1")
    end
  end
