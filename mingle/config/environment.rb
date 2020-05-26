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

# DO NOT MODIFY THIS FILE!!!

# required to allow background jobs to build correct URLs when
# an alternate context has been specified.
CONTEXT_PATH = '' unless defined?(CONTEXT_PATH)
RAILS_GEM_VERSION = '2.3.5'

require "rubygems"
if defined? Gem::Deprecate
  Gem::Deprecate.skip = true
end

ENV['NLS_LANG'] = 'AMERICAN_AMERICA.UTF8'
EMAIL_FORMAT_REGEX = /^([^@\s]+)@((?:[-_a-z0-9]+\.)+[a-z]{2,})$/i

require File.expand_path(File.join(File.dirname(__FILE__), 'boot'))

require File.join(File.dirname(__FILE__), '../vendor/plugins/engines/boot')

if !defined?(MINGLE_DATA_DIR)
  MINGLE_DATA_DIR = ENV['MINGLE_DATA_DIR'] ? File.expand_path(ENV['MINGLE_DATA_DIR']) : File.expand_path(Rails.root)
end
if !defined?(MINGLE_CONFIG_DIR)
  MINGLE_CONFIG_DIR = ENV['MINGLE_CONFIG_DIR'] ? File.expand_path(ENV['MINGLE_CONFIG_DIR']) : File.expand_path(File.join(MINGLE_DATA_DIR, 'config'))
end
if !defined?(MINGLE_SWAP_DIR)
  MINGLE_SWAP_DIR = ENV['MINGLE_SWAP_DIR'] ? File.expand_path(ENV['MINGLE_SWAP_DIR']) : File.expand_path(File.join(Rails.root, 'tmp'))
end
if !defined?(MINGLE_LOG_DIR)
  MINGLE_LOG_DIR = ENV['MINGLE_LOG_DIR'] ? File.expand_path(ENV['MINGLE_LOG_DIR']) : File.expand_path(File.join(Rails.root,'log'))
end

if !defined?(MINGLE_SSL_PORT)
  MINGLE_SSL_PORT = ENV['MINGLE_SSL_PORT']
end

MINGLE_DATABASE_YML = File.join(MINGLE_CONFIG_DIR, 'database.yml')
SMTP_CONFIG_YML = File.join(MINGLE_CONFIG_DIR, 'smtp_config.yml')
AUTH_CONFIG_YML = File.join(MINGLE_CONFIG_DIR, 'auth_config.yml')
BROKER_CONFIG_YML = File.join(MINGLE_CONFIG_DIR, 'broker.yml')
SITE_URL_CONFIG_FILE = File.join(MINGLE_CONFIG_DIR, 'mingle.properties')
LOG_NAMESPACE = 'com.thoughtworks.mingle'

require 'fileutils'
#PS: ruby_ext need be loaded before active_record load, because named_scope
# of AR need to aware all methods extended to Array (FavoriteTest#test_named_scope_can_be_smart_sorted)
require 'ruby_ext'

if RUBY_PLATFORM =~ /java/
  require 'java'
  require 'jruby_patches'
  require 'jdbc_adapter'
  require 'jdbc_adapter_ext' #PS: this loads whole active_record

  # Support JRuby thread dumps
  require 'thread_dumper'

  $LOAD_PATH << Rails.root.join("vendor", "java").to_s

  if Rails.env.test?
    java_io_tmpdir = File.join(Rails.root.to_s, "tmp")
    FileUtils.mkdir_p(java_io_tmpdir)
    java.lang.System.setProperty("java.io.tmpdir", java_io_tmpdir)
  end
end

require 'mingle'

MINGLE_VERSION = Mingle::Version::CURRENT
MINGLE_REVISION = Mingle::Revision::CURRENT
SWAP_DIR = File.expand_path(File.join(MINGLE_SWAP_DIR))

RAILS_TMP_DIR = File.join(SWAP_DIR, "scratch")
FileUtils.mkdir_p(RAILS_TMP_DIR)

PAGINATION_PER_PAGE_SIZE = 25

$mingle_plugins = {}

require File.join(Rails.root, "lib/rails_patches/action_controller_benchmarking")
require File.join(Rails.root, "lib/rails_patches/connection_pool_patch")
require 'alarms'

class Rails::Initializer
  # overload database initialization to not do anything if database.yml is not present
  def initialize_database
    return unless File.exists?(configuration.database_configuration_file)
    ActiveRecord::Base.configurations = configuration.database_configuration
    return unless ActiveRecord::Base.configurations
    return unless ActiveRecord::Base.configurations[Rails.env]
    return unless configuration.frameworks.include?(:active_record)
    Install::DatabaseConfig.verify_pool_size!(ActiveRecord::Base.configurations[Rails.env])

    ActiveRecord::Base.establish_connection
  end

  alias_method :load_plugins_without_pre_load, :load_plugins
  def load_plugins
    require 'strip_on_write'
    require 'rails_ext'
    require 'threadsafe_support'
    require 'customized_validations'

    Dir[File.join(Rails.root, "lib/rails_patches/**")].each do |ruby_file|
      next if ruby_file =~ /action_controller_benchmarking|connection_pool_patch/# loaded this file before rails initializer
      require ruby_file
    end
    Dir[File.join(Rails.root, "lib/rack_patches/**")].each do |ruby_file|
      require ruby_file
    end
    Dir[File.join(Rails.root, "lib/gem_patches/**")].each do |ruby_file|
      require ruby_file
    end

    require 'acts_as_taggable'
    require 'acts_as_traceable'
    require 'acts_as_versioned_ext'
    require 'acts_as_attachable'
    require 'acts_as_attribute_changing_observable'
    require 'resource_linking'
    require 'xml_serializer'
    require 'xml_cache'
    require 'profile_server'

    require 'elastic_search'
    require 'multitenancy'
    require 'background_job'
    require 'key_value_store'
    require 'authentication_keys'
    require 'logger_io_adapter'
    require 'nokogiri'

    require 'ostruct'
    require 'zipper4jr'
    require 'zipper_cli'
    require 'license_decrypt_4jr'
    require 'pdf_flying_saucer4jr'
    require 'apache_hex_helper'

    require 'connection_ext'
    require 'multi_rows_insertion'
    require 'rabl_ext'

    load_plugins_without_pre_load

    Dir[File.join(Rails.root, "lib/plugin_patches/**")].each do |ruby_file|
      require ruby_file
    end
  rescue StandardError, Exception => e
    puts <<-EOS
      Error: Unable to start Mingle.
      Reason: #{e.message}
      #{e.backtrace.join("\n")}
    EOS
    raise e
  end

  alias_method :after_initialize_without_plugin_patches, :after_initialize
  def after_initialize
    after_initialize_without_plugin_patches
    Dir[File.join(Rails.root, "lib/engines_patches/**")].each do |ruby_file|
      require ruby_file
    end
  end
end

require 'tracing_helper'
require 'memoize'
require 'card_query.tab'
require 'formula_properties.tab'

require 'timeout'
require 'threadsafe_hash'
require 'velocity'
require 'http_cache'
require 'collection_fragment_cache'
require 'log4j'
require 'mingle_configuration'
require 'a_b_testing'
require 'histogram/array'
require 'memcache_client_benchmarking'
require 'mingle_cipher'
require 'aws_helper'
require 'attachment_uploader'
require 'dual_app_routing_config'

initializer = Rails::Initializer.run do |config|
  config.database_configuration_file = MINGLE_DATABASE_YML

  config.frameworks -= [ :action_web_service ]

  config.active_record.default_timezone = :utc
  config.action_controller.relative_url_root = CONTEXT_PATH

  FileUtils.mkpath(File.dirname(config.log_path))

  config.logger = Log4j::Logger.new(:namespace => LOG_NAMESPACE)

  config.autoload_paths << "#{Rails.root}/app/jobs"
  config.autoload_paths << "#{Rails.root}/app/controllers/caching"
  config.autoload_paths << "#{Rails.root}/app/publishers"
  config.autoload_paths << "#{Rails.root}/app/processors"
  config.autoload_paths << "#{Rails.root}/app/controllers/planner"
  config.autoload_paths << "#{Rails.root}/app/models/asynch_request"
  config.autoload_paths << "#{Rails.root}/app/models/plan"
  config.autoload_paths << "#{Rails.root}/app/models/content_processors"

  current_plugins = ["engines", :all]

  config.action_view.sanitized_bad_tags = %w(style)
  config.action_view.sanitized_allowed_tags = %w(escape notextile table tr td th u s strike caption div)
  config.action_view.sanitized_allowed_attributes = %w(id style lang rowspan colspan target accesskey raw_text contenteditable class)
  config.active_record.observers = ['CacheKey::ProjectObserver',
                                    'CacheKey::ProjectStructureObserver',
                                    'CacheKey::CorrectionEventObserver',
                                    'CacheKey::UserObserver',
                                    'CacheKey::TagObserver',
                                    'CacheKey::CardObserver',
                                    'CacheKey::BulkDestroyObserver',
                                    'CacheKey::ProjectStructureObserverForMember']
  # Enable serving of images, stylesheets, and javascripts from an
  # asset server
  # we need this for _double_print.rhtml, because we need change the
  # asset_host to local path when we print cards
  config.action_controller.asset_host = lambda do |source|
    MingleConfiguration.asset_host
  end
end

initializer.configuration.middleware.delete(ActiveRecord::QueryCache)

ActiveRecord::Base.store_full_sti_class = true

# Use ISO 8601 format for JSON serialized times and dates.
ActiveSupport.use_standard_json_time_format = true
ActiveSupport::Inflector::Inflections.instance.uncountable('login_access')

Rails.backtrace_cleaner.remove_silencers!
class ActionMailer::Base
  cattr_accessor :default_sender
  self.default_sender = {}
end

if MingleConfiguration.debug?
  Rails.logger.level = Logger::DEBUG
end

require 'migration_helper'
require 'acts_as_paranoid_ext'
require 'rails_plugin_ext'
require 'memoize'
Kernel.logger = Rails.logger
require 'redcloth_ext'
require 'csv'
require 'set'
require 'strscan'
require 'open3'
require 'rbconfig'
require 'card_version_id_sequence'
if MingleUpgradeHelper.ruby_1_9?
  require 'digest'
else
  require 'md5'
  require 'digest/md5'
end
require 'secure_random_helper'
require 'digest/sha1'
require 'digest/sha2'

require 'uuid'
require 'roundtrip_joinable_array'

require 'mingle_macro_models'
require "macro"

require 'thread_local_cache'
require 'authenticator'
require 'mingle_db_authentication'
require 'basic_authenticator'
require 'js_stripper'
require 'will_paginate_helper'

require 'tzinfo_threadsafe_fix'

require 'retry_on_network_error'
require 'mingle_keyvalue_store'
require 'profiling_utils'
require 'health_check'
require 'events_tracker'
require 'firebase_client'
require 'firebase_retention_policy'
require 'mailgun'
require 'murmur_data'
require 'cta'
require 'live_filters'
require 'content_parser'
require 'apache_hex_helper'
require 'slack_application_client'
require 'aws/request_signer'
require 'aws/credentials'
require 'aws/signed_http_response'
require 'aws/elastic_search_client'
require 'rack_utils_patch'
require 'data_exporters'

# put this at the last, so that the environment is ready to go
Project.send(:include, Card::ThreadSafe::ProjectExt)

srand(Time.now.to_i)

require 'erubis/helpers/rails_helper'
Erubis::Helpers::RailsHelper.show_src = false

ActiveRecord::Base.logger.info "Mingle #{MINGLE_VERSION} (#{MINGLE_REVISION})"
ActiveRecord::Base.logger.info "Namespace: #{MingleConfiguration.app_namespace}"
ActiveRecord::Base.logger.info "Data directory: #{MINGLE_DATA_DIR}"
ActiveRecord::Base.logger.info "Swap directory: #{SWAP_DIR}"
ActiveRecord::Base.logger.info "Config directory: #{MINGLE_CONFIG_DIR}"
ActiveRecord::Base.logger.info "Context path: #{CONTEXT_PATH}"
ActiveRecord::Base.logger.info "Start with attachments root directory: #{DataDir::Attachments.root_directory}"
# load and setup smtp configuration if it exists
ActiveRecord::Base.logger.info "SMTP configured: #{SmtpConfiguration.load}"
ActiveRecord::Base.logger.info "Setting java.io.tmpdir to #{java.lang.System.getProperty('java.io.tmpdir')}"
if $servlet_context
  ActiveRecord::Base.logger.info "jruby.min.runtimes: #{java.lang.System.getProperty('jruby.min.runtimes')}"
  ActiveRecord::Base.logger.info "jruby.max.runtimes: #{java.lang.System.getProperty('jruby.max.runtimes')}"
end
