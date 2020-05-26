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

class SwapDir

  module RevisionCache
    def self.pathname
      SwapFileProxy.new(parent_folder_parts).pathname
    end

    def self.error_file(project, revision_number)
      SwapFileProxy.new(repository_cache_path_parts(project.repository_configuration) + ["#{revision_number}.error"])
    end

    def self.cache_file(project, revision_number)
      SwapFileProxy.new(repository_cache_path_parts(project.repository_configuration) + ["#{revision_number}.cache"])
    end

    def self.project_cache_dir(project)
      SwapDirectoryProxy.new(parent_folder_parts + [project.id.to_s])
    end

    def self.repository_cache_path_parts(repository_configuration)
      project_cache_dir(repository_configuration.project).path_parts + [repository_configuration.plugin_db_id.to_s]
    end

    def self.parent_folder_parts
      ['cache', 'revision']
    end
  end

  module DailyHistoryChart
    def self.root
      SwapDirectoryProxy.new ['cache', 'daily_history']
    end

    def self.chart_path(relative_path)
      SwapDirectoryProxy.new ['cache', 'daily_history', relative_path]
    end
  end

  module CardImport
    def self.file(card_import)
      path_parts = [ Mingle::Revision::SWAP_SUBDIR, 'card_imports', card_import.progress.deliverable_identifier, "#{card_import.progress.id}-data.txt" ]
      SwapFileProxy.new path_parts
    end
  end

  module CardImportingPreview
    def self.file(project, content=nil)
      path_parts = [ Mingle::Revision::SWAP_SUBDIR, 'card_importing_preview', project.identifier, "#{SecureRandomHelper.random_32_char_hex[0..15]}-data.txt" ]
      SwapFileProxy.new(path_parts).tap do |f|
        if content
          f.write(content)
        end
      end
    end
  end

  module ProgressBar
    def self.error_file(model)
      file(model, 'error')
    end

    def self.warning_file(model)
      file(model, 'warning')
    end

    def self.file(model, suffix)
      path_parts = [ Mingle::Revision::SWAP_SUBDIR, model.class.name.underscore, model.progress.deliverable_identifier, "#{model.progress.id}-#{suffix}.txt" ] #must include project level sub-dir
      SwapFileProxy.new path_parts, :write_mode => 'a+'
    end
  end

  module ProgramExport
    def self.file(program)
      SwapFileProxy.new [ Mingle::Revision::SWAP_SUBDIR, 'program_exports', Clock.now.to_i.to_s, program.identifier + '.program' ]
    end
  end

  module Export
    def self.base_directory(export_id)
      SwapFileProxy.new([ 'mingle_data_exports', export_id.to_s ]).pathname
    end

    def self.data_directory(export_id)
      export = ::Export.find(export_id)
      SwapFileProxy.new([ 'mingle_data_exports', export_id.to_s, export.dirname ]).pathname
    end

    def self.project_directory(export_id, project)
      export = ::Export.find(export_id)
      SwapFileProxy.new([ 'mingle_data_exports', export_id.to_s, export.dirname, 'Projects', project.export_dir_name ]).pathname
    end

    def self.program_directory(export_id, program)
      export = ::Export.find(export_id)
      SwapFileProxy.new([ 'mingle_data_exports', export_id.to_s, export.dirname, 'Programs', program.export_dir_name ]).pathname
    end
  end

  module ProjectExport
    def self.file(project)
      SwapFileProxy.new [ Mingle::Revision::SWAP_SUBDIR, 'exports', Clock.now.to_i.to_s, project.identifier + '.mingle' ]
    end
  end

  module DependencyExport
    def self.file(filename)
      SwapFileProxy.new [ Mingle::Revision::SWAP_SUBDIR, 'dependency_exports', Clock.now.to_i.to_s, "#{filename}.dependencies" ]
    end
  end

  module ProjectImport
    def self.directory
      SwapFileProxy.new([ Mingle::Revision::SWAP_SUBDIR, 'imports', "#{Process.pid}#{Time.now.to_i}" ]).pathname
    end
  end

  def self.relativize(absolute_path)
    start = SwapFileProxy.new([Mingle::Revision::SWAP_SUBDIR]).pathname.length + 1 # account for file separator
    absolute_path[start..-1]
  end

  def self.absolutize(relative_path)
    SwapFileProxy.new([Mingle::Revision::SWAP_SUBDIR, relative_path]).pathname
  end


  class SwapDirectoryProxy
    attr_reader :path_parts

    def initialize(path_parts)
      @path_parts = path_parts
    end

    def pathname
      File.join([SWAP_DIR, MingleConfiguration.app_namespace, @path_parts].compact)
    end

    def entries
      Dir.glob("#{pathname}/**/*.*").entries
    end

    def delete
      FileUtils.rm_rf pathname
    end
  end

  class SwapFileProxy < TmpFileProxy
    def pathname
      File.expand_path(File.join([SWAP_DIR, MingleConfiguration.app_namespace, @path_parts].compact))
    end
  end
end
