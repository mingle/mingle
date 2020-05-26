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

module ExcelExportImportPageId
  EXPORT_TO_EXCEL_LINK = "link=Export cards"
  EXPORT_ID = "export_to_excel"
  IMPORT_FROM_EXCEL_LINK ='link=Import cards'
  NEXT_TO_PREVIEW_LINK = 'link=Next to preview'
  NEXT_TO_COMPLETE_IMPORT = 'link=Next to complete import'
  COLLAPSIBLE_HEADER_FOR_IMPORT_EXPORT_ID = 'collapsible-header-for-Import---Export'
  CLOSE_EXPORT_EXCEL_LIGHTBOX_ID = 'close_export_excel_lightbox'
  VISIBLE_COLUMNS_OPTION_ID = 'visible_columns_option'
  EXPORT_DESCRIPTIONS_YES_ID = 'export_descriptions_yes'
  EXPORT_DESCRIPTIONS_NO_ID = 'export_descriptions_no'
  VISIBLE_COLUMNS_NO_ID = 'visible_columns_no'
  VISIBLE_COLUMNS_YES_ID = 'visible_columns_yes'
  BACK_LINK = "link=Back"
  EXPORT_PROJECT_LINK='link=Export project'
  EXPORT_PROJECT_AS_TEMPLATE_LINK='link=Export project as template'

  TREE_CONFIGURATION_SELECT_ID = 'tree_configuration_select'
  CLOSE_LIGHTBOX_LINK = 'close_lightbox_link'
  CLOSE_LINK = 'link=Close'
  LIGHTBOX_SCROLLING_CANVAS_ID = "lightbox_scrolling_canvas"
  TAB_SEPARATED_IMPORT_FORM = 'tab_separated_import_form'
  TAB_SEPERATED_EXPORT_ID = 'csv_export'
  TAB_SEPERATED_IMPORT_ID = 'tab_separated_import'
  PREVIEW_TABLE_ID ='preview_table'
  
  def export_to_excel_class_locator
    class_locator('export-cards')
  end
  
  
  def import_to_excel_class_locator
     
   class_locator('import-cards')
 end
  
  def select_column_property_for_import(key)
    "#{key.to_s.gsub("\s",'_').downcase}_import_as"
  end
  
  def ignore_checkbox(index)
    "ignore[#{index}]"
  end
end
