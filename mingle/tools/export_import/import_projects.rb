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

require File.expand_path(File.join(File.dirname(__FILE__), 'lib/environment.rb'))

class MingleTools::Import
  extend DeliverableImportExport::ImportFileSupport

  def self.import(export_file, dir)
    user = User.first_admin

    zip_file = unzip_export(File.join(dir, export_file))
    project_name = default_name(zip_file, nil)
    project_identifier = default_identifier(zip_file, nil)
    asynch_request = user.asynch_requests.create_project_import_asynch_request(project_identifier, nil)

    import = DeliverableImportExport::ProjectImporter.new(:progress => asynch_request)
    import.set_directory(zip_file)
    import.create_project_if_needed(project_name, project_identifier)
    import.import
  end

  def self.default_identifier(zip_file, identifier)
    Project.unique(:identifier, identifier.blank? ? project_table_attribute(zip_file, 'identifier') : identifier)
  end

  def self.default_name(zip_file, name)
    Project.unique(:name, name.blank? ? project_table_attribute(zip_file, 'name') : name)
  end

  def self.project_table_attribute(zip_file, attribute_name)
    begin
      project_table_attribute_from_table(zip_file, attribute_name, 'deliverables')
    rescue
      project_table_attribute_from_table(zip_file, attribute_name, 'projects')
    end
  end

  def self.project_table_attribute_from_table(zip_file, attribute_name, table_name)
    table = ImportExport::Table.new(zip_file, table_name)
    attribute_values = table.collect { |p| p[attribute_name] }
    raise 'Export contains information for more than one project' if attribute_values.size > 1
    raise 'Export contains no information for any project' if attribute_values.empty?
    attribute_values.first
  end

  private

  def self.to_project_identifier(file_name)
    file_name.gsub(/[^a-zA-Z0-9]/,'_').gsub(/^_/, '').gsub(/_$/, '').downcase
  end
end

def get_project_files(directory_name, filename)
  if filename.blank?
    match = /\.mingle$/i
  else
    match = /^#{filename.gsub(/\.mingle$/i, '')}\.mingle$/i
  end

  Dir.open(directory_name) do |dir|
    dir.select { |filename| filename =~ match }
  end
end

def with_sending_messages(&block)
  begin
    Messaging::Mailbox.transaction do
      yield
      puts "Sending reindexing messages..."
    end
  rescue NativeException => e
    if e.cause.is_a? Java::JavaxJms::JMSException
      puts "WARNING: This project will be imported, but it may not contain up to date information for history, aggregates and search results. Please see the README or the help documentation to fix this problem."
    else
      raise
    end
  end
end

unless Database.need_config?
  User.first_admin.with_current do
    filename = ENV["FILE_NAME"]
    project_files = get_project_files("exported_projects", filename)
    if project_files.empty?
      if filename.blank?
        puts "No Mingle project files were found to import."
      else
        puts "#{filename} was not found. Nothing imported."
      end
    end

    with_sending_messages do
      project_files.each do |project_file|
        puts "Importing project file #{project_file}..."
        imported_project = MingleTools::Import.import(project_file, "exported_projects")
        puts "Done importing project #{imported_project.identifier}!"
      end
    end
  end
end
