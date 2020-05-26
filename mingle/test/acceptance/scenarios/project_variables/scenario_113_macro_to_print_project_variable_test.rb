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

# Tags: scenario, wiki, macro, project, project_variable
class Scenario113MacroToPrintProjectVariableTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
  BLANK = ''
  NOT_SET = '(not set)'
  CARD = 'Card'
  JAN_FIRST = '01 Jan 2008'
  TEXT = 'Test'
  NUMBER = '100.22'
  
  PROJECT_VARIABLE = 'project-variable'
  PROJECT_VARIABLE_MACRO_TITLE = 'Insert Project Variable'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_113', :admins => [@project_admin], :users => [@project_member])
    login_as_proj_admin_user
    @card_1 = create_card!(:name => 'story 1', :card_type => CARD)
    @text_plv = setup_project_variable(@project, :name => 'text plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => TEXT)
    @numeric_plv = setup_project_variable(@project, :name => 'numeric plv', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => NUMBER)
    @user_plv = setup_project_variable(@project, :name => 'user plv', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member)
    @card_plv = setup_project_variable(@project, :name => 'card plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => @card_1)
    @date_plv = setup_project_variable(@project, :name => 'date plv', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => JAN_FIRST)  
  end
  
  #bug 5586
  def test_unset_plv_being_used_in_mql_macro
    new_plv = create_project_variable(@project, :name => 'plv of value Not Set', :data_type => ProjectVariable::CARD_DATA_TYPE)    
    open_wiki_page(@project, 'foo')
    print_plv_value(new_plv.name)
    click_save_link
    @browser.assert_text_present(NOT_SET)
  end
    
  def test_print_plv_value_of_different_data_type
    page_name = 'foo'
    open_wiki_page(@project, page_name)
    create_free_hand_macro("project-variable name: #{@text_plv.name}")
    create_free_hand_macro("project-variable name: #{@numeric_plv.name}")
    create_free_hand_macro("project-variable name: #{@user_plv.name}")
    create_free_hand_macro("project-variable name: #{@card_plv.name}")
    paste_query_and_save("project-variable name: #{@date_plv.name}")
    assert_contents_on_page(TEXT, NUMBER, @project_member.name, card_number_and_name(@card_1), JAN_FIRST)
  end
  
  def test_update_card_name_can_be_relected_on_plv_value_printed
    content = %{       
      project-variable name: #{@card_plv.name}
    }
    page_name = 'foo'
    open_wiki_page(@project, page_name)
    paste_query_and_save(content)
    assert_contents_on_page(card_number_and_name(@card_1))
    new_name = "new name"
    open_card(@project, @card_1)
    edit_card(:name => new_name)
    open_wiki_page(@project, page_name)
    @browser.click_and_wait('link=Edit')
    paste_query_and_save(content)
    open_wiki_page(@project, page_name)
    assert_contents_on_page("##{@card_1.number} #{new_name}")
  end
  
  def test_update_user_name_can_be_reflected_on_plv_value_printed
    content = %{     
      project-variable name: #{@user_plv.name}
    }
    page_name = 'foo'
    open_wiki_page(@project, page_name)
    paste_query_and_save(content)
    assert_contents_on_page(@project_member.name)
    logout
    login_as @project_member.login
    edit_user_profile_details(@project_member, :user_name => 'new project member new name')

    open_wiki_page(@project, page_name)
    assert_contents_on_page("new project member new name")
  end
  
  def test_update_date_format_can_be_relected_on_plv_value_printed
    content = %{        
      project-variable name: #{@date_plv.name}
    }
    page_name = 'foo'
    open_wiki_page(@project, page_name)
    paste_query_and_save(content)
    assert_contents_on_page(JAN_FIRST)
    navigate_to_project_admin_for(@project)
    set_project_date_format('dd/mm/yyyy')
    open_wiki_page(@project, page_name)
    assert_contents_on_page("01/01/2008")    
  end
  
  def test_update_numeric_precision_can_be_reflect_on_plv_value_printed
    content = %{        
      project-variable name: #{@numeric_plv.name}
    }
    page_name = 'foo'
    open_wiki_page(@project, page_name)
    paste_query_and_save(content)
    assert_contents_on_page(NUMBER)
    set_numeric_precision_to(@project, 1)
    open_wiki_page(@project, page_name)
    assert_contents_on_page("100.2")  
  end
  
  #bug 5137
  def test_plv_value_print_in_cross_project_report_should_navigate_to_the_valid_project_card
    project2 = create_project(:prefix => 'project2', :admins => [@project_admin], :users => [@project_member])
    content = %{
      project-variable
        project: #{@project.identifier}
        name: #{@card_plv.name}
      }
    open_wiki_page(project2, 'foo')
    paste_query_and_save(content)
    assert_contents_on_page("#1 story 1")
    assert_link_present("/projects/#{@project.identifier}/cards/#{@card_1.number}")
  end
  
  #bug 5129
  def test_PLV_name_having_reserved_keyword_should_not_throw_error_message
    plv_with_keyword = setup_project_variable(@project, :name => 'date plv - tree', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => JAN_FIRST)  
    content = %{
      project-variable name: #{plv_with_keyword.name}
    }
    page_name = 'foo'
    open_wiki_page(@project, page_name)
    paste_query_and_save(content)
    assert_contents_on_page("01 Jan 2008")
  end
  
  def test_macro_editor_for_project_variable_macro_on_wiki_edit
    plv_with_keyword = setup_project_variable(@project, :name => 'date plv - tree', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => JAN_FIRST)
    open_wiki_page_in_edit_mode
    select_macro_editor(PROJECT_VARIABLE_MACRO_TITLE)
    assert_should_see_macro_editor_lightbox
    assert_macro_parameters_field_exist(PROJECT_VARIABLE, ['name','project'])
    assert_text_present('Example: project_variable_name')
    type_macro_parameters(PROJECT_VARIABLE, :name => plv_with_keyword.name)
    submit_macro_editor
    assert_card_or_page_content_in_edit(JAN_FIRST)
   end


  def test_macro_editor_preview_for_project_variable_macro_on_card_edit
    error_message_of_empty_input = "Error in project-variable macro: Parameter name is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax."
    open_macro_editor_without_param_input(PROJECT_VARIABLE_MACRO_TITLE)
    type_macro_parameters(PROJECT_VARIABLE, :name => "")
    preview_macro
    preview_content_should_include(error_message_of_empty_input)
    
    type_macro_parameters(PROJECT_VARIABLE, :name => "cookie")
    preview_macro
    preview_content_should_include("Error in project-variable macro: Project variable cookie does not exist")
        
    type_macro_parameters(PROJECT_VARIABLE, :name => "#{@user_plv.name}")
    preview_macro
    preview_content_should_include("member@email.com")
  end
   

  def test_using_project_parameter_in_plv_macro
    open_macro_editor_without_param_input(PROJECT_VARIABLE_MACRO_TITLE)
    type_macro_parameters(PROJECT_VARIABLE, :name => "#{@user_plv.name}")
    type_macro_parameters(PROJECT_VARIABLE, :project => "123")
    preview_macro
    preview_content_should_include("Error in project-variable macro: There is no project with identifier 123")
  end
  
  def test_project_variable_should_show_display_name_and_log_in_name
    setup_user_definition('owner')
    associate_project_varible_from_property(@project, @user_plv.name, 'owner')  
    open_wiki_page(@project, 'project variable')
    print_plv_value(@user_plv.name)
    click_save_link
    @browser.assert_text_present("#{@project_member.name} (#{@project_member.login})")
  end

  private
  def set_numeric_precision_to(project, precision)
    location = @browser.get_location
    navigate_to_project_admin_for(project) unless location =~ /#{project.identifier}\/admin\/edit/
    click_show_advanced_options_link
    @browser.type('project_precision', precision.to_s)
    click_save_link
  end
end
