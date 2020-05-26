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

# Tags: project-variable-usage
class Scenario117UsingProjectVariableInCardDefaultTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
  CARD = 'Card'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_117', :admins => [@project_admin], :users => [@project_member])
    @type_super_card = setup_card_type(@project, "Super Card")   
  end  
  
  MANAGED_TEXT_TYPE = "Managed text list"
  FREE_TEXT_TYPE = "Allow any text"
  MANAGED_NUMBER_TYPE = "Managed number list"
  FREE_NUMBER_TYPE = "Allow any number"
  USER_TYPE = "team"
  DATE_TYPE = "date"
  CARD_TYPE = "card"
  RELATIONSHIP_TYPE = 'relationship'

  @@data = [
    {:property_type => "Managed text list", :property_name => "status", :plv_type => "StringType", :plv_name => "plv for managed text", :plv_value => "new"},
    {:property_type => "Allow any text", :property_name => "iteriter", :plv_type => "StringType", :plv_name => "plv for free text", :plv_value => "new new"},
    {:property_type => "Managed number list", :property_name => "size", :plv_type => "NumericType", :plv_name => "plv for managed number", :plv_value => "1"},
    {:property_type => "Allow any number", :property_name => "reversion", :plv_type => "NumericType", :plv_name => "plv for free number", :plv_value => "10"},
    {:property_type => "date", :property_name => "reported on", :plv_type => "DateType", :plv_name => "plv for date", :plv_value => "10 Oct 2008"},
    {:property_type => "team", :property_name => "owner", :plv_type => "UserType", :plv_name => "plv for user"},
    {:property_type => "card", :property_name => "dependency", :plv_type => "CardType", :plv_name => "plv for card type"},
    {:property_type => "relationship", :property_name => "Tree - Card", :plv_type => "CardType", :plv_name => "plv for relationship"}  
  ]

  def test_plv_presence_on_card_default_dropdown_associated_with_text_list_property
    data = {:property_type => "Managed text list", :property_name => "status", :plv_type => "StringType", :plv_name => "plv for managed text", :plv_value => "new"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_any_text_property
    data = {:property_type => "Allow any text", :property_name => "iteriter", :plv_type => "StringType", :plv_name => "plv for free text", :plv_value => "new new"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_number_list_property
    data = {:property_type => "Managed number list", :property_name => "size", :plv_type => "NumericType", :plv_name => "plv for managed number", :plv_value => "1"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_any_number_property
    data = {:property_type => "Allow any number", :property_name => "reversion", :plv_type => "NumericType", :plv_name => "plv for free number", :plv_value => "10"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_date_property
    data = {:property_type => "date", :property_name => "reported on", :plv_type => "DateType", :plv_name => "plv for date", :plv_value => "10 Oct 2008"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_team_property
    data = {:property_type => "team", :property_name => "owner", :plv_type => "UserType", :plv_name => "plv for user"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_card_property
    data = {:property_type => "card", :property_name => "dependency", :plv_type => "CardType", :plv_name => "plv for card type"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def test_plv_presence_on_card_default_dropdown_associated_with_tree_relationship_property
    data = {:property_type => "relationship", :property_name => "Tree - Card", :plv_type => "CardType", :plv_name => "plv for relationship"}
    assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
  end

  def assert_plv_presence_on_card_default_dropdown_with_property_correctly(data)
    login_as_proj_admin_user
    assert_plv_name_present_property_dropdown_in_card_default_after_created(data)
    assert_plv_name_not_present_property_dropdown_in_card_default_after_disassociated_with_property(data)
    assert_plv_name_present_property_dropdown_in_card_default_after_associated_with_property(data)
    assert_plv_name_present_property_dropdown_in_card_default_after_renamed(data)
    assert_plv_name_not_present_property_dropdown_in_card_default_after_deleted(data)
  end

  def assert_plv_name_present_property_dropdown_in_card_default_after_created(data)
    create_property_of_particular_type(data[:property_type], data[:property_name])
    create_plv_and_associate_to_property(data[:plv_type], data[:plv_name], data[:property_type], data[:property_name])
    open_edit_defaults_page_for(@project, CARD)   
    assert_plv_name_present_property_dropdown_in_card_default(data[:property_name], data[:plv_name])
  end

  def assert_plv_name_not_present_property_dropdown_in_card_default_after_disassociated_with_property(data)
    disassociate_project_variable_from_property(@project, data[:plv_name], data[:property_name])
    open_edit_defaults_page_for(@project, CARD)
    wait_for_wysiwyg_editor_ready
    if data[:property_type].starts_with?('Allow any')
      assert_free_text_does_not_have_drop_down(data[:property_name], "edit")
    else
      assert_plv_name_not_present_property_dropdown_in_card_default(data[:property_name], data[:plv_name], data[:property_type])
    end
  end

  def assert_plv_name_present_property_dropdown_in_card_default_after_associated_with_property(data)
    associate_project_varible_from_property(@project, data[:plv_name], data[:property_name])
    open_edit_defaults_page_for(@project, CARD)
    assert_plv_name_present_property_dropdown_in_card_default(data[:property_name], data[:plv_name])
  end

  def assert_plv_name_present_property_dropdown_in_card_default_after_renamed(data)
    new_plv_name = "#{data[:property_name]}-#{data[:plv_name]}"
    rename_project_varible(@project, data[:plv_name], new_plv_name)
    open_edit_defaults_page_for(@project, CARD)
    if data[:property_type].starts_with?('Allow any')
      assert_free_text_does_not_have_drop_down(data[:property_name], "edit")
    else
      assert_plv_name_not_present_property_dropdown_in_card_default(data[:property_name], data[:plv_name], data[:property_type])
    end
    assert_plv_name_present_property_dropdown_in_card_default(data[:property_name], new_plv_name)
  end

  def assert_plv_name_not_present_property_dropdown_in_card_default_after_deleted(data)
    new_plv_name = "#{data[:property_name]}-#{data[:plv_name]}"
    delete_project_variable(@project, new_plv_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{new_plv_name} was successfully deleted")
    
    open_edit_defaults_page_for(@project, CARD)
    if data[:property_type].starts_with?('Allow any')
      assert_free_text_does_not_have_drop_down(data[:property_name], "edit")
    else
      assert_plv_name_not_present_property_dropdown_in_card_default(data[:property_name], data[:plv_name], data[:property_type])
    end
  end
  
  def test_usage_of_plv_on_card_default
    login_as_proj_admin_user
    user_for_plv_value = @project_member
    card_for_plv_value = get_one_card_for_plv_value
    
    0.upto(7) do |i|
      data = @@data[i]
      create_property_of_particular_type(data[:property_type], data[:property_name])
      
      if (data[:property_type] == FREE_NUMBER_TYPE || data[:property_type] == FREE_TEXT_TYPE || data[:property_type] == MANAGED_NUMBER_TYPE || data[:property_type] == MANAGED_TEXT_TYPE || data[:property_type] == DATE_TYPE)
        plv_value = "#{data[:plv_value]}"       
      elsif data[:property_type] == USER_TYPE
        plv_value = user_for_plv_value
      elsif data[:property_type] == CARD_TYPE
        plv_value = card_for_plv_value
      elsif data[:property_type] == RELATIONSHIP_TYPE
        plv_value = card_for_plv_value
      else
        raise "Property type #{data[:property_type]} is not supported"                   
      end
            
      create_plv_and_associate_to_property(data[:plv_type], data[:plv_name], data[:property_type], data[:property_name],:plv_value => plv_value)      
      open_edit_defaults_page_for(@project, CARD)   
      set_property_defaults(@project, data[:property_name] =>  "(#{data[:plv_name]})")
      click_save_defaults
      navigate_to_view_for(@project, 'list')
      card_number = add_new_card("with #{data[:property_type]} default", :type => CARD)
      sleep 1
      open_card(@project, card_number)
      sleep 1

      if data[:plv_type] == 'UserType'
        plv_value = 'member@ema...'
      elsif data[:plv_type] == 'CardType'
        plv_value = card_number_and_name(plv_value)      
      end
      
      assert_property_set_on_card_show(data[:property_name], plv_value)
    end
  end
  
  # bug 6894
  def test_user_can_update_card_default_after_using_plv_as_default_value
    login_as_proj_admin_user
    card_for_plv_value = get_one_card_for_plv_value
    
    create_property_of_particular_type("card", "dependency")
    create_property_of_particular_type("relationship", "Tree - Card")
    create_plv_and_associate_to_property("CardType", "current parent", "relationship", "Tree - Card", :plv_value => card_for_plv_value)
    associate_project_varible_from_property(@project, "current parent", "dependency")
    open_edit_defaults_page_for(@project, CARD)   
    set_property_defaults(@project, "Tree - Card" =>  "(current parent)")
    set_property_defaults(@project, "dependency" =>  "(current parent)")
    click_save_defaults
    
    open_edit_defaults_page_for(@project, CARD)   
    set_property_defaults(@project, "Tree - Card" =>  "(not set)")
    set_property_defaults(@project, "dependency" =>  "(not set)")
    click_save_defaults
    
    navigate_to_view_for(@project, 'list')
    card_number = add_new_card("with default", :type => CARD)
    open_card(@project, card_number)
    assert_property_set_on_card_show('dependency', '(not set)')
    assert_property_set_on_card_show('Tree - Card', '(not set)')
  end
  
  private 
  def create_property_of_particular_type(property_type, property_name)
    if property_type == RELATIONSHIP_TYPE
      get_one_simple_relationship_property(property_name)
    else
      create_property_for_card(property_type, property_name)
    end   
  end
  
  def create_plv_and_associate_to_property(plv_type, plv_name,property_type, property_name, options={})
    if property_type == RELATIONSHIP_TYPE
      setup_project_variable(@project, :name => plv_name, :data_type => plv_type, :value => options[:plv_value], :card_type => @type_super_card,:properties => [property_name])
    else
      setup_project_variable(@project, :name => plv_name, :data_type => plv_type, :value => options[:plv_value], :properties => [property_name])
    end
  end
   
  def get_one_simple_relationship_property(relationship_property_name)
    type_card = @project.card_types.find_by_name(CARD)    
    tree = setup_tree(@project, 'Simple Tree', :types => [@type_super_card, type_card], :relationship_names => ["#{relationship_property_name}"])
  end
  
  def get_one_card_for_plv_value
    create_card!(:card_type => @type_super_card, :name => 'plv value card') 
  end
  
end
