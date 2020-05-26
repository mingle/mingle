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

require 'mingle_configuration'
Rails.logger.info 'started initialising MingleConfiguration'
ENV_CONFIG = [
    :app_namespace,
    :app_context,
    :alert_topic_id,
    :messaging_adapter,
    :queue_name_prefix,
    :terms_of_service_url,
    :site_u_r_l,
    :secure_site_u_r_l,
    :api_u_r_l,
    :privacy_policy_url,
    :no_background_job,
    :system_user,
    :system_user_password,
    :multitenancy_mode,
    :multitenancy_migrator,
    :saas_sender_email,
    :tenant_config_dynamodb_table,
    :global_config_dynamodb_table,
    :missing_schemata_dynamodb_table,
    :disable_aws_logging,
    :attachment_size_limit,
    :asynch_request_tmp_file_size_limit,
    :public_icons,
    :icons_bucket_name,
    :tmp_file_bucket_name,
    :attachments_bucket_name,
    :import_files_bucket_name,
    :daily_history_cache_bucket_name,
    :landing_project,
    :landing_view_name,
    :profile_server_url,
    :profile_server_access_key_id,
    :profile_server_access_secret_key,
    :profile_server_skip_ssl_verification,
    :profile_server_namespace,
    :number_of_pooled_schemas,
    :skip_install_check,
    :need_to_accept_saas_tos,
    :cycle_time_server_url,
    :metrics_api_key,
    :request_timeout,
    :search_namespace,
    :search_index_name,
    :multitenant_messaging,
    :abtesting_experiments,
    :new_schema_db_url,
    :asset_host,
    :user_notification_heading,
    :user_notification_avatar,
    :user_notification_body,
    :user_notification_url,
    :tweet_message,
    :tweet_url,
    :ask_for_upgrade_email_recipient,
    :sso_config,
    :authentication_keys,
    :walkme_src,
    :walkme_enabled_for_non_trial_sites,
    :debug,
    :parse_application_id,
    :parse_rest_api_key,
    :trace_js,
    :message_delay_seconds_rate,
    :pingdom_rum_id,
    :corn_host,
    :corn_client_id,
    :corn_profiling,
    :slow_request_threshold,
    :slow_sql_threshold,
    :macro_records_limit,
    :ckeditor_version,
    :firebase_app_url,
    :firebase_secret,
    :honeybadger_api_key,
    :s3_upload_access_key_id,
    :s3_upload_secret_key,
    :support_email_address,
    :sales_team_email_address,
    :murmur_email_from_address,
    :mailgun_api_key,
    :mailgun_domain,
    :slack_client_id,
    :slack_app_aws_region,
    :slack_encryption_key,
    :slack_app_url,
    :failed_murmur_reply_retries,
    :slack_sns_notification_topic,
    :app_environment,
    :murmur_email_replies_firebase_threshold_in_days
]

FEATURE_TOGGLES = [
    :saas_env,
    :auto_explain_threshold_in_seconds,
    :enable_fb_murmur_notifications,
    :indexing_debug,
    :in_progress_templates,
    :maintenance_url,
    :my_work_menu,
    :show_footer_notification,
    :footer_notification_url,
    :footer_notification_text,
    :live_wall,
    :multipart_s3_import,
    :new_buy_process,
    :no_cleanup,
    :csp,
    :holiday_effects,
    :attachment_url_expiry_time_in_seconds,
    :cycle_time_last_completed_in,
    :holiday_name,
    :holiday_logo_link,
    :transition_to_channel_mapping_enabled,
    :easy_charts_edit_mql,
    :add_team_member_enabled,
    :program_settings_enabled,
    :readonly_mode
]

# Need to figure out saas mode without MingleConfiguration before initialising
saas_mode = MingleConfiguration.system_property('mingle', :multitenancy_mode)

if saas_mode
  Aws.config.update({region: java.lang.System.getProperty("AWS_REGION"), credentials: Aws::InstanceProfileCredentials.new})
end

MingleConfiguration.init('mingle',
                         ENV_CONFIG + FEATURE_TOGGLES,
                         KeyValueStore.create(MingleConfiguration.system_property('mingle', :global_config_dynamodb_table), :property_name, :value, saas_mode),
                         {
                             logger: Rails.logger,
                             context_path: CONTEXT_PATH,
                             smtp_config_yml_path: SMTP_CONFIG_YML,
                             dev_env: !Rails.env.production?
                         })
Rails.logger.info 'done initialising MingleConfiguration'
