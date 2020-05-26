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

class DataDir

  module Public
    def self.directory
      DataFileProxy.new(['public'])
    end
  end

  module ActiveMQData
    def self.directory
      DataFileProxy.new(['activemq-data'])
    end
  end

  module PluginData
    def self.pathname(plugin_name, *path_fragments)
      DataFileProxy.new(["plugin_data", plugin_name, *path_fragments]).pathname
    end
  end

  module Attachments
    DEFAULT_ATTACHMENTS_PER_DIRECTORY = 30_000
    def self.attachments_per_directory=(limit)
      @attachments_per_directory = limit
    end
    def self.reset
      @attachments_per_directory = DEFAULT_ATTACHMENTS_PER_DIRECTORY
      @last_root_directory = nil
    end

    reset

    def self.tmp_dir
      AttachmentFileProxy.new([RAILS_TMP_DIR, "attachments-tmp-dir"])
    end

    def self.random_directory
      AttachmentFileProxy.new([root_directory, SecureRandomHelper.random_32_char_hex])
    end

    def self.file(attachment)
      DataFileProxy.new(['public', attachment.path.to_s, attachment.file_relative_path.to_s])
    end

    def self.directory
      DataFileProxy.new(['public', root_directory])
    end

    # never changed for tmp dir
    def self.first_root_directory
      root_directory_by_index(0)
    end

    def self.root_directory
      @last_root_directory ||= find_last_root_directory
      ensure_exist(@last_root_directory)
      @last_root_directory = full?(@last_root_directory) ? next_root_directory(@last_root_directory) : @last_root_directory
    end

    def self.next_root_directory(previous)
      root_directory_by_index(index(previous) + 1)
    end

    def self.all_root_directories
      Dir.entries(Public.directory.pathname).select { |f| f=~/^attachments/ }
    end

    def self.full?(dir)
      sub_dirs_size = Dir.entries(path(dir)).size - ['.', '..'].size
      sub_dirs_size >= @attachments_per_directory
    end

    def self.find_last_root_directory
      max_index = Dir.entries(Public.directory.pathname).collect { |f| f=~/^attachments(_\d+)?/ ? $1.to_i : -1 }.max
      root_directory_by_index(max_index)
    end

    def self.path(dir)
      DataFileProxy.new(['public', dir]).pathname
    end
    private

    def self.root_directory_by_index(index)
      ensure_exist(index <= 0 ? 'attachments' : "attachments_#{index}")
    end

    def self.ensure_exist(dir)
      dir.tap{ FileUtils.mkdir_p(path(dir)) }
    end

    def self.index(path)
      path.split('_').last.to_i
    end
  end

  class DataFileProxy < TmpFileProxy
    def pathname
      File.join([MINGLE_DATA_DIR, MingleConfiguration.app_namespace, @path_parts].compact)
    end
  end

  class AttachmentFileProxy < TmpFileProxy
    def pathname
      File.join(@path_parts)
    end
  end
end

class ConfigDir
  def self.pathname(*path_fragments)
    File.join(MINGLE_CONFIG_DIR, *path_fragments)
  end
end
