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

class RailsTmpDir
  
  class << self
    def file_name(*args)
      File.join(RAILS_TMP_DIR, args)
    end
    alias :file_path :file_name
  end
  
  module Database
    def self.file
      RailsTmpFileProxy.new 'test_db_dump.sql'
    end
  end
  
  module BrokerRepository
    def self.file
      RailsTmpFileProxy.new ['brokers', Rails.env.to_s, 'messaging_broker.pstore']
    end
  end
  
  module RepositoryDriver
    def self.repos(name)
      RailsTmpFileProxy.new ['test', 'cached_svn', name.md5, 'repos']
    end

    def self.wc(name)
      RailsTmpFileProxy.new ['test', 'cached_svn', name.md5, 'wc']
    end
  end
  
  module RepositoryHgDriver
    def self.repos(name)
      RailsTmpFileProxy.new ['test', 'cached_hg', name.md5, 'repos']
    end
  end
  
  module Repositoryp4Driver
    def self.repos(name)
      RailsTmpFileProxy.new ['test', 'cached_p4', name.md5, 'repos']
    end
    
    def self.wc(name)
      RailsTmpFileProxy.new ['test', 'cached_p4', name.md5, 'wc']
    end
  end
  
  module PdfExport
    def self.file
      RailsTmpFileProxy.new ['pdf_export', 'pdf'.uniquify + '.html']
    end
  end
  
  module DependenciesExport
    class << self
      def new_temporary_directory(identifier)
        dir = new_dir(identifier)
        while dir.exist?
          sleep 0.1
          dir = retry_new_dir(identifier)
        end
        dir.create
      end

      protected

      def retry_new_dir(identifier)
        RailsTmpDirProxy.new ['exports', identifier, Clock.now.to_i.to_s]
      end
      alias :new_dir :retry_new_dir
    end
  end


  module ProjectExport
    class << self
      def new_temporary_directory(deliverable)
        dir = new_dir(deliverable)
        while dir.exist?
          sleep 0.1
          dir = retry_new_dir(deliverable)
        end
        dir.create
      end
      
      protected

      def retry_new_dir(deliverable)
        RailsTmpDirProxy.new ['exports', deliverable.identifier, Clock.now.to_i.to_s]
      end
      alias :new_dir :retry_new_dir
    end
  end
  
  class RailsTmpDirProxy
    include Zipper
    
    def initialize(path_parts)
      @path_parts = path_parts
    end
    
    def exist?
      File.exist? dirname
    end
    
    def create
      FileUtils.mkdir_p dirname
      self
    end

    def dirname
      File.join(RAILS_TMP_DIR, @path_parts)
    end
    
    def zip
      raise "Unable to zip directory '#{dirname}' without it being created first." unless exist?
      filename = super(dirname)
      delete
      filename
    end
    
    protected
    
    def delete
      FileUtils.rm_rf dirname
    end
  end


  class RailsTmpFileProxy < TmpFileProxy
    def pathname
      File.join(RAILS_TMP_DIR, @path_parts)
    end
  end
  
end
