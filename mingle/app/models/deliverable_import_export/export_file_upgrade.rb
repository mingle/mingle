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
  module ExportFileUpgrade

    def need_upgrade?
      local_version = Project.connection.select_values("SELECT version FROM #{ActiveRecord::Base.table_name_prefix}schema_migrations").map(&:to_i).max || 0
      !(schema_version == local_version && plugins_valid?)
    end

    def upgrade_if_needed
      return nil unless need_upgrade?

      upgraded_export = RailsTmpDir.file_name('upgrades', "#{Process.pid}#{Clock.now.to_i}.mingle") until upgraded_export && !File.exist?(upgraded_export)

      FileUtils.mkdir_p(File.dirname(upgraded_export))

      local_version = Project.connection.select_values("SELECT version FROM #{ActiveRecord::Base.table_name_prefix}schema_migrations").map(&:to_i).max || 0
      if schema_version > local_version
        @progress.step("Upgrade failed...") do
          raise schema_incompatible
        end
      end

      @progress.step("Upgrading from a previous version, could take a long time...") do
        run_upgrade_script_in_jruby(upgraded_export)
        save_file_without_creating_project(upgraded_export)
      end
    end

    def save_file_without_creating_project(zip_file)
      use_new_import_dir(zip_file)
    end

    class SchemaIncompatible < StandardError; end

    private

    def create_upgrade_export_scripting_container
      container = com.thoughtworks.mingle.MingleScriptingContainer.new(Rails.root.to_s)
      container.setEnvironment(ENV)
      container.setLoadPaths($:)

      container
    end

    def synchronize(&block)
      $upgrade_export_scripting_container_mutex ||= Mutex.new
      $upgrade_export_scripting_container_mutex.synchronize(&block)
    end

    def run_upgrade_script_in_jruby(upgraded_export)
      synchronize do
        $upgrade_export_scripting_container ||= create_upgrade_export_scripting_container
        # should only have one prefix for one container, because Rails caches all table name
        # if we change the prefix every time, we'll need reset all table names
        # here we give a random mi prefix, so that different process has different prefix,
        # hence they can run in parallel
        $mi_prefix ||= random_mi_prefix
        scriptlet = load_environment_scriptlet + jruby_upgrade_scriptlet(upgraded_export)
        result = $upgrade_export_scripting_container.runScriptlet(scriptlet)
        raise "Upgrade failed, please contact Mingle support" if result != 0
      end
    end

    def random_mi_prefix
      prefix = "mi_"
      6.times { prefix << rand(10).to_s }
      prefix + '_'
    end

    def load_environment_scriptlet
      <<-RUBY
          MINGLE_DATA_DIR = #{MINGLE_DATA_DIR.inspect} unless defined?(MINGLE_DATA_DIR)
          MINGLE_SWAP_DIR = #{MINGLE_SWAP_DIR.inspect} unless defined?(MINGLE_SWAP_DIR)
          MINGLE_CONFIG_DIR = #{MINGLE_CONFIG_DIR.inspect} unless defined?(MINGLE_CONFIG_DIR)
          CONTEXT_PATH = #{CONTEXT_PATH.inspect} unless defined?(CONTEXT_PATH)
          RAILS_ROOT = #{Rails.root.to_s.inspect} unless defined?(RAILS_ROOT)
          RAILS_ENV = #{Rails.env.inspect} unless defined?(RAILS_ENV)
          MINGLE_MEMCACHED_HOST = #{MINGLE_MEMCACHED_HOST.inspect}
          MINGLE_MEMCACHED_PORT = #{MINGLE_MEMCACHED_PORT.inspect}

          require File.join(RAILS_ROOT, 'config', 'boot')
          require 'active_record'

          ActiveRecord::Base.table_name_prefix = #{$mi_prefix.inspect}
          require File.join(RAILS_ROOT, 'config', 'environment')

          FileColumn.config_store(:filesystem)
          # disable all indexing/caching/etc to speed up the import
          Messaging.disable
          Renderable.disable_caching
      RUBY
    end

    def jruby_upgrade_scriptlet(upgraded_export)
      script = <<-RUBY
          input = #{File.expand_path(self.directory).inspect}
          output = #{File.expand_path(upgraded_export).inspect}
          #{File.read(upgrade_script)}
      RUBY

      tenant = Multitenancy.active_tenant
      tenant ? with_active_tenant(tenant, script) : script
    end

    def with_active_tenant(tenant, script)
      <<-RUBY
          Multitenancy.activate_tenant("#{tenant.name}") do
            #{script}
          end
       RUBY
    end

    def upgrade_script
      File.join(Rails.root, 'script', 'upgrade_export')
    end

  end
end
