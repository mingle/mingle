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

class SysadminController < ApplicationController

  include Messaging::Base
  include RunningExportsHelper

  before_filter :sysadmin_only
  skip_before_filter :sysadmin_only, :only => [:toggle_show_all_project_admins]
  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN  => [:toggle_show_all_project_admins]
  verify :method => [:put, :post, :options], :only => [:delete_global_user_notification, :delete_tenant_user_notification, :update_global_user_notification, :update_tenant_user_notification, :update_dual_routing, :trigger_reindex, :toggle_show_all_project_admins]

  def clear_license_cache
    CurrentLicense.clear_cache
    redirect_to :action => :index
  end

  def exports
    running_exports = MingleConfiguration.global_config['running_exports']
    @running_exports = running_exports.nil? ? {} : running_exports
  end

  def update_mingle_configuration
    modify_tenant_config(params[:name], params[:value])
    redirect_to :action => 'tenant_configuration'
  end

  def update_global_configuration
    modify_global_config(params[:name] => params[:value])
    redirect_to :action => 'global_configuration'
  end

  def toggle_show_all_project_admins
    modify_tenant_config('show_all_project_admins', params[:show_all_project_admins], true)
    render nothing: true
  end

  def delete_mingle_configuration
    modify_tenant_config(params[:name], nil)
    redirect_to :action => 'tenant_configuration'
  end

  def update_global_user_notification
    errors = []
    errors << "Heading is required." if params[:user_notification_heading].strip.blank?
    errors << "Content is required." if params[:user_notification_body].strip.blank?

    if errors.empty?
      modify_global_config('user_notification_heading' => params[:user_notification_heading],
                           'user_notification_avatar' => params[:user_notification_avatar],
                           'user_notification_body' => params[:user_notification_body],
                           'user_notification_url' => params[:user_notification_url],
                           'tweet_message' => params[:tweet_message],
                           'tweet_url' => params[:tweet_url])
    else
      flash[:error] = errors.join(" ")
    end

    redirect_to :action => (MingleConfiguration.saas? ? "global_configuration" : "user_notification")
  end

  def delete_global_user_notification
    modify_global_config('user_notification_heading' => "",
                         'user_notification_avatar' => "",
                         'user_notification_body' => "",
                         'user_notification_url' => "",
                         'tweet_message' => "",
                         'tweet_url' => "")
    redirect_to :action => (MingleConfiguration.saas? ? "global_configuration" : "user_notification")
  end

  def update_tenant_user_notification
    modify_tenant_config('user_notification_heading', params[:user_notification_heading], true)
    modify_tenant_config('user_notification_avatar', params[:user_notification_avatar], true)
    modify_tenant_config('user_notification_body', params[:user_notification_body], true)
    modify_tenant_config('user_notification_url', params[:user_notification_url], true)
    modify_tenant_config('tweet_message', params[:tweet_message], true)
    modify_tenant_config('tweet_url', params[:tweet_url], true)
    redirect_to :action => 'tenant_configuration'
  end

  def delete_tenant_user_notification
    modify_tenant_config('user_notification_heading', "")
    modify_tenant_config('user_notification_avatar', "")
    modify_tenant_config('user_notification_body', "")
    modify_tenant_config('user_notification_url', "")
    modify_tenant_config('tweet_message', "")
    modify_tenant_config('tweet_url', "")
    redirect_to :action => 'tenant_configuration'
  end

  def update_dual_routing
    params[:commit] == 'Enable' ? DualAppRoutingConfig.enable_routing : DualAppRoutingConfig.disable_routing
    redirect_to action: :dual_routing_toggle
  end

  def trigger_reindex
    FullTextSearch::IndexingSiteProcessor.enqueue
    flash[:info] = 'Triggered reindexing for tenant. DO NOT TRIGGER AGAIN, this can take some time to complete.'
    redirect_to action: :reindex_tenant
  end

  def delete_export
    export = Export.last
    if export && export.status != Export::COMPLETED
      export.destroy
      update_running_exports
      flash[:info] = 'Last export was deleted'
    else
      flash[:info] = 'Last export was not in progress and was not deleted'
    end
    redirect_to action: :export
  end

  def export_project_names_with_their_admins_in_csv
    @export_project_names_with_their_admins_in_csv = projects_and_their_admin_names_in_csv_format
    headers['Content-Disposition'] = "filename=\"project_admins.csv\""
    headers['Content-Type'] = 'text/csv'
    render :layout => false
  end

  def memcache_client_benchmarking
    mcb = MemcacheClientBenchmarking.new(CACHE)
    time = (params[:seconds] || 30).to_i
    bins = (params[:bins] || 10).to_i
    @bins, @freqs = mcb.benchmark(time).histogram(bins, :bin_boundary => :min)
  end

  def error
    raise "simulated runtime error"
  end

  private
  def modify_global_config(config)
    MingleConfiguration.global_config_merge(config)
  end

  def modify_tenant_config(key, value, allow_blank=false)
    tenant_name = Multitenancy.active_tenant.name
    # remove app namespace so that we can update cache when updating
    # tenant configuration
    MingleConfiguration.with_app_namespace_overridden_to(nil) do
      key = "mingle.config.#{key}"
      if !allow_blank && value.blank?
        Multitenancy.delete_tenant_config(tenant_name, key)
      else
        Multitenancy.merge_tenant_config(tenant_name, key => value)
      end
    end
  end

  def projects_and_their_admin_names_in_csv_format
    headers = 'Project name','Admin name', 'Email'
    result = ""
    CSV.generate(result) do |csv|
      csv << headers
      Project.admins_list.each do |admin|
        project_name = admin['project_name']
        admin_name = admin['admin_name']
        email = admin['email']
        csv << ["#{project_name}", "#{admin_name}", "#{email}"]
      end
    end
    result
  end

  def sysadmin_only
    head(:forbidden) unless (MingleConfiguration.saas? ? User.current.system? : User.current.admin?)
  end
end
