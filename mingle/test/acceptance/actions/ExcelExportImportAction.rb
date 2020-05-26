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

module ExcelExportImportAction
  def click_twisty_for_export_import
    unless @browser.is_element_present(ExcelExportImportPageId::IMPORT_FROM_EXCEL_LINK) && @browser.is_visible(ExcelExportImportPageId::IMPORT_FROM_EXCEL_LINK)
      @browser.click(ExcelExportImportPageId::COLLAPSIBLE_HEADER_FOR_IMPORT_EXPORT_ID)
    end
  end

  # export
  def open_export_to_excel_options_lightbox
    click_twisty_for_export_import
    @browser.with_ajax_wait do
      @browser.click(ExcelExportImportPageId::EXPORT_TO_EXCEL_LINK)
    end
  end

  def close_export_to_excel_options_lightbox
    @browser.click(ExcelExportImportPageId::CLOSE_EXPORT_EXCEL_LIGHTBOX_ID)
  end

  def export_to_excel(options={:with_description => true, :visible_columns_only => false})
    open_export_to_excel_options_lightbox
    if options[:with_description]
      choose_to_export_descriptions
    else
      choose_not_to_export_descriptions
    end
    if has_visible_columns_option?
      if options[:visible_columns_only]
        choose_to_export_only_visible_columns
      else
        choose_to_export_all_columns
      end
    end
    start_excel_export
  end

  def export_all_columns_to_excel_with_description
    export_to_excel(:with_description => true, :visible_columns_only => false)
  end

  def export_all_columns_to_excel_without_description
    export_to_excel(:with_description => false, :visible_columns_only => false)
  end

  def has_visible_columns_option?
    @browser.is_element_present(ExcelExportImportPageId::VISIBLE_COLUMNS_OPTION_ID)
  end

  def choose_to_export_descriptions
    @browser.click ExcelExportImportPageId::EXPORT_DESCRIPTIONS_YES_ID
  end

  def choose_not_to_export_descriptions
    @browser.click ExcelExportImportPageId::EXPORT_DESCRIPTIONS_NO_ID
  end

  def choose_to_export_all_columns
    @browser.click ExcelExportImportPageId::VISIBLE_COLUMNS_NO_ID
  end

  def choose_to_export_only_visible_columns
    @browser.click ExcelExportImportPageId::VISIBLE_COLUMNS_YES_ID
  end

  def start_excel_export
    @browser.eval_javascript("document.getElementById('skip_download').value = 'yes';")
    @browser.click ExcelExportImportPageId::EXPORT_ID
    @browser.wait_for_text_present('Number,')
  end

  def click_back_link
    @browser.get_eval('this.browserbot.getCurrentWindow().window.history.go(-1)')
    @browser.wait_for_page_to_load
  end

  def get_exported_data
    @browser.get_body_text
  end

  # import
  def excel_copy_string(header_row, card_data)
    import_string = header_row.join("\t") << "\n"
    card_data.each do |row|
      import_string << row.join("\t") << "\n"
    end
    import_string
  end

  def import(excel_copy_string, options={})
    preview(excel_copy_string)
    import_from_preview(options)
  end

  def preview(excel_copy_string, option={})
    click_import_from_excel
    type_in_tab_separated_import(excel_copy_string)
    submit_to_preview(option)
    HtmlTable.new(@browser, ExcelExportImportPageId::PREVIEW_TABLE_ID, [], 1, 1)
  end

  def type_in_tab_separated_import(excel_copy_string)
    @browser.type ExcelExportImportPageId::TAB_SEPERATED_IMPORT_ID, excel_copy_string
  end

  def click_import_from_excel
    click_twisty_for_export_import
    @browser.click_and_wait(ExcelExportImportPageId::IMPORT_FROM_EXCEL_LINK)
  end

  def select_tree_to_import(tree_name)
    if(@browser.is_visible(ExcelExportImportPageId::TREE_CONFIGURATION_SELECT_ID))
      @browser.select(ExcelExportImportPageId::TREE_CONFIGURATION_SELECT_ID, tree_name)
    else
      raise 'no trees in import data...'
    end
  end

  def click_next_to_preview
    @browser.with_ajax_wait do
      @browser.click ExcelExportImportPageId::NEXT_TO_PREVIEW_LINK
    end
  end

  def submit_to_preview(option={})
    click_next_to_preview
    CardImportPreviewProcessor.run_once
    if option[:failed]
      @browser.wait_for_element_visible ExcelExportImportPageId::CLOSE_LIGHTBOX_LINK
      assert_error_message(option[:error_message]) if option[:error_message]
      @browser.click ExcelExportImportPageId::CLOSE_LINK
    else
      @browser.wait_for_text_present('Preparing preview completed.')
      @browser.wait_for_text_present('Preview import')
    end
  end

  def import_from_preview(options={})
    options = {:map => {}, :ignores => []}.merge(options)
    @browser.wait_for_element_present ExcelExportImportPageId::TAB_SEPARATED_IMPORT_FORM
    options[:map].each do |key, value|
      @browser.select select_column_property_for_import(key), value
    end
    options[:ignores].each do |i|
      @browser.check ignore_checkbox(i)
    end
    @browser.with_ajax_wait do
      @browser.click ExcelExportImportPageId::NEXT_TO_COMPLETE_IMPORT
    end
    CardImportProcessor.run_once
    @browser.wait_for_page_to_load

    @browser.wait_for_text_present('Importing complete')
  end

  def import_in_grid_view(excel_copy_string, options={})
    preview(excel_copy_string)
    import_from_preview(options)
  end
end
