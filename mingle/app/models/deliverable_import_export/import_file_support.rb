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

require "simple_bench"

module DeliverableImportExport
  module ImportFileSupport
    include Zipper

    def table(table_name, model=nil)
      @tables ||= {}
      @table_by_model ||= {}

      if @tables[table_name]
        return @tables[table_name]
      end

      return nil unless yaml_file_exists?(self.directory, table_name)

      model = infer_model_from_table_name(table_name) if model.nil?

      @tables[table_name] = ImportExport::TableWithModel.new(directory, table_name, model)
      @table_by_model[model] = @tables[table_name] if model
      @tables[table_name]
    end

    def unzip_export(zip_file, extension="mingle")
      if zip_file.respond_to?(:path) && zip_file.path
        file_name = zip_file.path
      elsif zip_file.respond_to?(:read)
        input = zip_file
        # it's an opened IO object, save it to a file
        # file_name = @zip_file
        file_name = File.join(Rails.root, 'tmp', 'imports', "#{Process.pid}#{Time.now.to_i}.#{extension}") until file_name && !File.exist?(file_name)
        FileUtils.mkpath(File.join(Rails.root, 'tmp', 'imports'))
        File.open(file_name, 'wb') do |output|
          output.write(input.read)
        end
      else
        # it's a path to a file
        file_name = zip_file
      end

      # already unzipped
      return file_name if File.directory?(file_name)

      # loops until we find a directory that hasn't already been used
      directory = SwapDir::ProjectImport.directory until directory && !File.exist?(directory)
      FileUtils.mkpath(directory)
      SimpleBench.bench "unzipping archive" do
        unzip(file_name, directory)
      end
      directory
    end

    def schema_version
      migrations.max
    end

    def migrations
      schema_migrations = table('schema_migrations') || table('schema_info')
      schema_migrations.select { |record| record['version'].numeric? }.collect { |record| record['version'].to_i }.sort
    end

    def yaml_file_exists?(directory, table_name)
      new_style = File.join(directory, "#{table_name}_0.yml")
      old_style = File.join(directory, "#{table_name}.yml")
      File.exist?(new_style) || File.exist?(old_style)
    end

    def table_names_from_file_names
      files = Dir[File.join(directory, "*.yml")]
      table_names = files.collect do |file|\
        if File.basename(file) =~ /^(.*)(_[0-9]*)\.yml$/  # new style export format
          $1
        else
          File.basename(file, '.yml')  # old style export format
        end
      end
      table_names.uniq
    end

    def connection
      ActiveRecord::Base.connection
    end

  end
end
