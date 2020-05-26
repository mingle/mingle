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

# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = true

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

config.active_record.schema_format = :sql

config.logger.level = Logger::DEBUG
SCRIPT_LINES__ = {}

RENDER_CHARTS_AS_TEXT = true

::Messaging
module ::Messaging
  def bypass_messaging_process
    $bypass_messaging_process = true
  end
  
  def enable_messaging_process
    $bypass_messaging_process = false
  end
  
  module_function :bypass_messaging_process, :enable_messaging_process
  
  module DeliverMessages
    def self.included(base)
      base.class_eval do
        class <<self
          def run_once_with_pre_deliver_messaging(options={})
            options[:batch_size] ||= 20000
            run_once_without_pre_deliver_messaging(options)
          end
          alias_method_chain :run_once, :pre_deliver_messaging
        end
      end
    end
  end
end

unless ActionController::Base.method_defined?(:process_messages_created_by_model)
  Messaging::Processor.send(:include, ::Messaging::DeliverMessages)
end
