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

class CardImportingPreviewAsynchRequest < AsynchRequest

  def processor_queue
    CardImportPreviewProcessor::QUEUE
  end

  def content
    self.localize_tmp_file
  end

  def mapping
    self.message[:mapping]
  end

  def update_mapping_with(mapping_overrides)
    self.message = self.message.merge(:mapping => mapping_overrides)
    save!
  end

  def progress_msg
    if completed? && success?
      "Preparing preview completed."
    else
      progress_message
    end
  end
  
  def callback_url(params, project)
    view_params(params).merge(:controller => 'asynch_requests', :action => 'progress', :id => id)
  end
  
  def success_url(controller, params)
    view_params(params).merge(:controller => 'cards_import', :action => 'display_preview', :id => id)
  end
  
  def failed_url(controller, params)
    nil
  end

  def view_header
    "asynch_requests/card_importing_preview_view_header"
  end

  private
  
  def view_params(params)
    Project.find_by_identifier(self.deliverable_identifier).with_active_project do |project|
      return (@view ||= CardListView.find_or_construct(project, params)).to_params
    end
  end
end
