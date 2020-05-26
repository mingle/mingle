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

MESSAGE_PUBLISHING_BATCH_SIZE=25000

require 'messaging'
require 'card_event_publisher'
require 'page_event_publisher'
require 'user_event_publisher'
require 'mingle_event_publisher'
require 'card_import_publisher'
require 'murmurs_publisher'
require 'dependency_event_publisher'
require 'dependency_resolving_card_publisher'
require 'card_import_preview_publisher'
require 'project_export_publisher'
require 'program_export_publisher'
require 'dependencies_export_publisher'
require 'dependencies_import_preview_publisher'
require 'dependencies_import_publisher'
require 'project_import_publisher'
require 'program_import_publisher'
require 'aggregate_publisher'
require 'tag_event_publisher'
require 'objective_filter_observer'
require 'tenant_creation_publisher'
require 'work_observer'
require 'license_alert_publisher'
require 'merge_export_data_processor'
require 'merge_export_data_publisher'
require 'data_export_processor'
require 'instance_data_export_processor'
require 'instance_data_export_publisher'
require 'project_data_export_processor'
require 'project_data_export_publisher'
require 'project_history_data_export_processor'
require 'project_history_data_export_publisher'
require 'dependency_data_export_processor'
require 'dependency_data_export_publisher'
require 'program_data_export_publisher'
require 'program_data_export_processor'
require 'integrations_export_publisher'
require 'integrations_export_processor'

require 'full_text_search'

require 'history_generation_processor'
require 'aggregate_computation_processor'

require 'card_import_preview_processor'
require 'card_import_processor'
require 'project_export_processor'
require 'program_export_processor'
require 'dependencies_export_processor'
require 'dependencies_import_preview_processor'
require 'dependencies_import_processor'
require 'program_import_processor'
require 'project_import_processor'
require 'card_murmur_link_processor'
require 'feeds_cache_populating_processor'
require 'daily_history_chart_processor'
require 'sync_objective_work_processor'
require 'objective_snapshot_processor'
require 'tenant_creation_processor'
require 'tenant_destruction_processor'
require 'history_notification_processor'
require 'murmur_notification_processor'
require 'live_events_notification_processor'
require 'data_fixes_processor'
require 'license_alert_processor'
require 'murmur_reply_processor'
require 'reindex_tenants_processor'

require 'migrate/load'

if MingleConfiguration.messaging_adapter
  Messaging::Adapters.adapter_name = MingleConfiguration.messaging_adapter
end
Rails.logger.info("messaging adapter: #{Messaging::Adapters.adapter_name}")
Messaging.enable unless Rails.env.test?
Messaging.middleware << Messaging::MigrationGuard
if Messaging::Adapters.adapter_name == 'sqs'
  Messaging.middleware << Messaging::RetryOnError.new(:match => /UnknownOperationException/, :tries => 5)
end

Messaging.middleware << [Messaging::ErrorHandling, Alarms, [ElasticSearch::NetworkError]]
Messaging.middleware << Messaging::Benchmarking
Messaging.middleware << Messaging::CleanEnvMiddleware
Messaging.middleware << Messaging::GlobalConfigMiddleware
Messaging.middleware << Multitenancy::MessagingMiddleware
