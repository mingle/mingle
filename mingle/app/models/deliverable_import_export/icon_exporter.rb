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

module DeliverableImportExport
  class IconExporter

    def self.icon_exported_path(basedir, model, id, icon_file_name)
      File.join(basedir, ActiveSupport::Inflector.underscore(model.name).to_s, 'icon', id.to_s, icon_file_name)
    end

    def initialize(icon_target_dir)
      @icon_target_dir = icon_target_dir
    end

    def export_icons(icon_holders)
      icon_holders.each do |icon_holder|
        next unless icon_holder.icon
        target = IconExporter.icon_exported_path(@icon_target_dir, icon_holder.class, icon_holder.id, File.basename(icon_holder.icon))

        begin
          icon_holder.icon_copy_to(target)
        rescue => e
          Rails.logger.error { "ignore error when copy icon #{icon_holder.icon_relative_path} to #{target}: #{e.message}\n#{e.backtrace.join("\n")}" }
        end
      end
    end
  end
end
