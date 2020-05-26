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
namespace :templates do

  desc "read mingle project exported file path from environment variable 'FILE' and convert it into yaml spec template"
  task :yaml => :environment do
    require 'deliverable_import_export/select_by_project_sql_models_ext'

    User.first_admin.with_current do
      file = ENV['FILE']
      fname = File.basename(file).split(".").first
      puts "file name: #{fname}"
      puts "import project into #{Rails.env} database"
      pid = fname.uniquify
      asynch_request = ProjectImportPublisher.new(User.current, pid, pid).publish_message(File.new(file))
      DeliverableImportExport::ProjectImporter.fromActiveMQMessage(asynch_request.message).process!

      puts "exporting as yaml spec"
      exported_file = YamlExporter.export(pid)
      target = File.join(File.dirname(exported_file), "#{fname}.yml")
      FileUtils.mv(exported_file, target)
      puts "exported yaml file: #{target.inspect}"
    end
  end

end
