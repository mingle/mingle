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

module CardsImportHelper
  
  def display_value(cell, mapping)
    return cell if mapping.import_as != CardImport::Mappings::DATE_PROPERTY
    PropertyType::DateType::error(@project, cell)
  end  
  
  def preview_tree_options(tree_configs)
    tree_configuration_id =  @card_reader.tree_configuration ? @card_reader.tree_configuration.id : nil  
    options_for_select(tree_configs.collect{ |config| [config.name, config.id] }.unshift(['none', nil]), tree_configuration_id)
  end
  
  def tab_separated_import_content
    return flash[:tab_separated_import] if flash[:tab_separated_import]
    return params[:tab_separated_import] if params[:tab_separated_import]

    if preview_request = AsynchRequest.find_by_id(params[:tab_separated_import_preview_id])
      local_tmp_file = preview_request.localize_tmp_file
      return CardImport::ExcelContent.new(local_tmp_file).raw_content if File.exist?(local_tmp_file)
    end
  end

end
