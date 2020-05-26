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

class CardImportAsynchRequest< AsynchRequest

  def processor_queue
    CardImportProcessor::QUEUE
  end

  def progress_msg
    progress_msg = "Importing #{completed? ? 'complete' : status}, #{progress_message || "0 rows, 0 updated, 0 created"}, #{pluralize(error_count, 'error')}."
    line_break = MingleFormatting::MINGLE_LINE_BREAK_MARKER
    if (self.error_details.size > 0)
      progress_msg << "#{line_break}#{line_break}Error detail:#{line_break}#{line_break}" << self.error_details.join(line_break)
    end
    if (self.warning_details.size > 0)
      progress_msg << "#{line_break}#{line_break}Warning detail:#{line_break}#{line_break}" << self.warning_details.join(line_break)
    end
    progress_msg
  end

  def reconstruct_card_reader
    original_message = self.reload.message
    ignore = original_message[:ignore] ? original_message[:ignore].keys.map { |key| key[/\d+/].to_i } : []
    mapping_overrides = original_message[:mapping].keys.sort_by { |key| key[/\d+/].to_i }.collect { |key| original_message[:mapping][key] } if original_message[:mapping]
    CardImporter.fromActiveMQMessage(original_message.merge(:mapping => mapping_overrides, :ignore => ignore)).create_card_reader
  end  

  def callback_url(params, project)
    project.with_active_project do |project|
      return view_params(params, project).merge(:controller => 'asynch_requests', :action => 'progress', :id => id)
    end
  end

  def success_url(controller, params)
    controller.deliverable.with_active_project do |project|
      return view_params(params, project).merge(:controller => 'cards')  
    end
  end
  
  def failed_url(controller, params)
    controller.deliverable.with_active_project do |project|
      return view_params(params, project).merge(:controller => 'cards_import', :action => 'repreview', :import_id => self.id)
    end
  end

  def view_header
    "asynch_requests/card_import_view_header"
  end

  private
  def view_params(params, project)
    (@view ||= CardListView.find_or_construct(project, params)).to_params.merge(:project_id => project.identifier)
  end
end

