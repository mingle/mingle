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

class UserIconExporter < BaseDataExporter

  def name
    'User icons'
  end

  def export
    export_dir = FileUtils.mkpath(File.join(@basedir, name)).first
    User.all.each do |user|
      next unless user.icon
      target = icon_exported_path(export_dir, user.login + '_' + File.basename(user.icon))
      begin
        user.icon_copy_to(target)
      rescue => e
        Rails.logger.error { "ignore error when copy icon #{user.icon_relative_path} to #{target}: #{e.message}\n" }
      end
    end
    Rails.logger.info("Exported user data to sheet")
  end

  def exports_to_sheet?
    false
  end

  def exportable?
    User.all_with_icon.count > 0
  end

  private
  def icon_exported_path(basedir, icon_file_name)
    File.join(basedir, icon_file_name)
  end

  def headings
    []
  end
end
