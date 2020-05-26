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

module ExcelExportImportPage
  
  def assert_selected_property_column_in_import_preview(property_name, property_type, display_label='existing property')
    @browser.assert_selected_value("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", "#{property_type}") 
    @browser.assert_selected_label("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", "as #{display_label}") 
  end
  
  def assert_ignore_selected_for_property_column(property_name)
    @browser.assert_selected_value("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", "ignore") 
    @browser.assert_selected_label("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", "(ignore)")
  end
  
  def assert_ignore_only_available_mapping_for_property_column(property_name)
    values = @browser.get_all_drop_down_option_values("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as")
    assert_equal(['(ignore)'], values)
  end
  
  def assert_drop_down_disabled_for_property_column(property_name)
    assert_disabled("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as")
  end
  
  def assert_in_import_preview_does_not_contain_property_value(property_name, value)
     @browser.assert_text_not_present_in("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", value)
  end
  
  def assert_in_import_preview_contain_property_value(property_name, value)
    @browser.assert_drop_down_contains_value("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", value)
  end
  
  def assert_value_ordered_in_selected_property_column_dropdown_in_import_preview(property_name, value)
    @browser.assert_values_in_drop_down_are_ordered("#{property_name.to_s.downcase.gsub(/\W/, '_')}_import_as", value)
  end
  
  def assert_import_complete_with(options ={})
    rows = options[:rows ] || 0
    rows_or_row = return_row_or_rows(rows)
    @browser.assert_text_present("Importing complete, #{rows} #{rows_or_row}, #{options[:rows_updated] || 0} updated, #{options[:rows_created] || 0} created, #{options[:errors] || 0} errors.")
  end
  
  def assert_equal_ignore_cr(expected, actual)
    assert_equal(expected.strip_cr, actual.strip_cr)
  end
    
  def assert_value_in_import_text_area(data)
    @browser.assert_value(ExcelExportImportPageId::TAB_SEPERATED_IMPORT_ID, "#{data}")
  end
      
  def assert_tree_present_in_tree_select_drop_down(tree_name)
    @browser.assert_drop_down_contains_value(ExcelExportImportPageId::TREE_CONFIGURATION_SELECT_ID, tree_name)
  end
  
  def assert_tree_name_not_present_in_tree_select_drop_down(tree_name)
    @browser.assert_drop_down_does_not_contain_value(ExcelExportImportPageId::TREE_CONFIGURATION_SELECT_ID, tree_name)  
  end
  
  def assert_export_to_excel_page_present  
    @browser.assert_text_present "How to use export"
  end
  
  def assert_import_from_excel_page_present  
    @browser.assert_text_present "How to import"
  end
  
  def assert_export_to_excel_link_present
    @browser.assert_element_present(export_to_excel_class_locator)
  end
  
  def assert_export_to_excel_link_not_present
    @browser.assert_element_not_present(export_to_excel_class_locator)
  end
  
  def assert_import_to_excel_link_not_present
    @browser.assert_element_not_present(import_to_excel_class_locator)
  end
  
  def assert_export_and_export_as_template_present
    @browser.assert_element_present(ExcelExportImportPageId::EXPORT_PROJECT_LINK)
    @browser.assert_element_present(ExcelExportImportPageId::EXPORT_PROJECT_AS_TEMPLATE_LINK)
  end
  
  def assert_export_and_export_as_template_not_present   
    @browser.assert_element_not_present(ExcelExportImportPageId::EXPORT_PROJECT_LINK)
    @browser.assert_element_not_present(ExcelExportImportPageId::EXPORT_PROJECT_AS_TEMPLATE_LINK)
  end
  
  def assert_include_description_selected
    with_excel_export_lightbox do
      unless (@browser.get_eval("this.browserbot.getCurrentWindow().$('export_descriptions_yes').checked") == 'true') 
        raise SeleniumCommandError.new("include description is not checked") 
      end
    end
  end
  
  def assert_include_description_is_not_selected
    with_excel_export_lightbox do
      unless (@browser.get_eval("this.browserbot.getCurrentWindow().$('export_descriptions_no').checked") == 'true') 
        raise SeleniumCommandError.new("include description is checked") 
      end
    end
  end

  def assert_include_only_visible_columns_selected
    with_excel_export_lightbox do
      unless (@browser.get_eval("this.browserbot.getCurrentWindow().$('visible_columns_yes').checked") == 'true') 
        raise SeleniumCommandError.new("include only visible column is not checked") 
      end
    end
  end
  
  def assert_include_only_visible_columns_is_not_selected
    with_excel_export_lightbox do
      unless (@browser.get_eval("this.browserbot.getCurrentWindow().$('visible_columns_yes').checked") == 'false') 
        raise SeleniumCommandError.new("include only visible column is checked") 
      end
    end
  end
  
  private
  def with_excel_export_lightbox(&block)
    open_export_to_excel_options_lightbox
    yield
  ensure
    close_export_to_excel_options_lightbox 
  end
  
  def return_row_or_rows(rows)
     if(rows == 1)
       rows_or_row = 'row'
     else
       rows_or_row = 'rows'
     end
     rows_or_row
   end
end
