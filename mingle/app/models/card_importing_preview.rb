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

class CardImportingPreview
  include ProgressBar

  attr_accessor :project, :user, :progress
  delegate :status, :progress_message, :error_count, :warning_count, :total, :completed, :to => :@progress
  delegate :status=, :progress_message=, :error_count=, :warning_count=, :total=, :completed=, :to => :@progress

  def self.fromActiveMQMessage(message)
    new.tap do |preview|
      preview.project = Project.find message[:project_id]
      preview.progress = AsynchRequest.find message[:request_id]
      preview.user = User.find message[:user_id]

      preview.mark_queued
    end
  end

  def process!
    with_progress do |in_progress|
      begin
        user = self.progress ? self.progress.user : User.current
        reader = CardImport::CardReader.new(project, content, nil, user, &in_progress)
        in_progress.call("Validating...", 100, 99)
        reader.validate
        progress.update_mapping_with(reader.mapping_overrides)
      rescue => e
        log_error(e, e.message, :force_full_trace => true)
        progress.add_error(e.message)
        update_progress_message(e.message)
      end
    end
  end

  def content
    CardImport::ExcelContent.new(self.tab_separated_import_path)
  end

  def tab_separated_import_path
    progress.localize_tmp_file
  end
end
