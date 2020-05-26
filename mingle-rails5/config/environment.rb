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

# Load the Rails application.
require_relative 'application'
require 'memoize'
require 'log4j'
require 'mingle'
require 'fileutils'
require 'java'
require 'connection_ext'
require 'migration_helper'
require 'memcached'
require 'alarms'
require 'acts_as_versioned_ext'

CONTEXT_PATH = '' unless defined?(CONTEXT_PATH)

if !defined?(MINGLE_DATA_DIR)
  MINGLE_DATA_DIR = ENV['MINGLE_DATA_DIR'] || Rails.root.to_s
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

MINGLE_VERSION = Mingle::Version::CURRENT || 'current'
MINGLE_REVISION = Mingle::Revision::CURRENT
SMTP_CONFIG_YML = File.join(MINGLE_CONFIG_DIR, 'smtp_config.yml')
AUTH_CONFIG_YML = File.join(MINGLE_CONFIG_DIR, 'auth_config.yml')

SWAP_DIR = File.expand_path(File.join(MINGLE_SWAP_DIR))
RAILS_TMP_DIR = File.join(SWAP_DIR, 'scratch')
FileUtils.mkdir_p(RAILS_TMP_DIR)

require 'load_mingle_configuration'
require 'ruby_ext'
require 'rails_ext'
require File.join(Rails.root,'app','lib','database_helper.rb')
$mingle_plugins = {}

Rails.application.paths['config/database'] = DatabaseHelper.new(MINGLE_CONFIG_DIR).db_config_file
# Initialize the Rails application. Cannot setup app config here. Do it in application.rb
Rails.application.initialize!

# Needs to be done after Rails has initialised its logger
Kernel.logger = Rails.logger
