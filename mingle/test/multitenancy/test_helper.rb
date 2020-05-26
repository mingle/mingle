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


ENV["RAILS_ENV"] = "test"

require File.expand_path(File.dirname(__FILE__) + "/../unit/unit_test_data_loader")

$LOAD_PATH.unshift(File.dirname(__FILE__), '..')

require File.expand_path(File.dirname(__FILE__) + "/../../config/environment.rb")
MingleConfiguration.load_config(File.join(Rails.root, 'config', 'mingle.properties'))
MingleConfiguration.multitenancy_migrator = "true"
MingleConfiguration.multitenancy_mode = "true"
MingleConfiguration.skip_install_check = "true"

# Dummy cluster url for test
MingleConfiguration.aws_es_cluster = "http://localhost:8000"
MingleConfiguration.site_u_r_l = "https://mingle.thoughtworks.com"
Multitenancy.setup_schema_selector

require 'test_help'
require 'memcache_stub'
require File.join(Rails.root, 'test/stubs/http_stub')

Rails.logger.info "change CACHE and ActionController::Base.cache_store to memcached stub instance"
silence_warnings { Object.const_set "CACHE", MemcacheStub.new }
silence_warnings { ActionController::Base.cache_store = MemcacheStub.new, {} }

Renderable.disable_caching
LicenseDecrypt.enable_license_decrypt

class ElasticSearch
  class << self
    def find_one(index_name, type, id)
      (get "#{elastic_search_server_url}#{ElasticSearch.index_path(index_name, type, Namespace.id(id))}").parsed_response
    end
  end
end


module DisableFixtures
  def self.included(base)
    base.use_transactional_fixtures = false
  end

  def setup_fixtures
  end

  def teardown_fixtures
  end
end

module Helpers

  def only_oracle
    unless ActiveRecord::Base.connection.database_vendor == :oracle
      putc 'S'
      at_exit { puts "NOTICE: #{name} only runs on Oracle; skipped." }
    else
      yield
    end
  end

  def with_new_project(identifier="new".uniquify[0..29], &block)
    Project.create!(:name => identifier, :identifier => identifier).with_active_project do |project|
      User.first_admin.with_current do
        project.add_member(User.current)
        story = project.card_types.create!(:name => "Story")
        priority = UnitTestDataLoader.setup_managed_text_definition("priority", %w(Low Medium High))
        points = UnitTestDataLoader.setup_numeric_property_definition("points", %w(1 2 3 5 8 13))
        story.add_property_definition(priority)
        story.add_property_definition(points)

        block.call(project) if block_given?
      end
    end
  end

  def valid_license
    {:key => <<-KEY, :licensed_to => "ThoughtWorks Inc."}
NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
KEY
  end

  def swap_current_db_as_new_partition
    origin_default_config = ActiveRecordPartitioning.default_config.dup
    begin
      # change default to invalid db
      ActiveRecordPartitioning.default_config = origin_default_config.merge(:url => 'invalid partition2 url')

      # confirm you can't create a new tenant by default config
      assert_raises(RuntimeError, 'The driver encountered an error: no connection available') do
        TenantInstallation.create_tenant('test-site-123', nil)
      end

      # set new schema db url to valid db url,
      # so that it got pick up when creating new tenant and
      # we don't use default invalid db url to create tenant

      MingleConfiguration.with_new_schema_db_url_overridden_to(origin_default_config[:url]) do
        yield
      end
    ensure
      Multitenancy.clear_activerecord_connection_pools
      ActiveRecordPartitioning.default_config = origin_default_config
    end
  end

  def start_elastic_search
    java.lang.System.set_property("mingle.dataDir", File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "tmp")))
    java.lang.System.set_property("es.foreground", "yes")
    org.elasticsearch.bootstrap.Elasticsearch.main([])
  end

  def stop_elastic_search
    org.elasticsearch.bootstrap.Elasticsearch.close([])
  end
end

[ActiveSupport::TestCase, ActionController::TestCase].each do |c|
  c.send(:include, DisableFixtures)
  c.send(:include, Helpers)
end
