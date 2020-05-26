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

class TenantsController < ActionController::Base

  include FeatureToggleFilter
  before_filter :check_feature_toggle
  before_filter :check_configuration
  before_filter :check_tenant_exists, :except => [:index, :create, :validate, :derive_tenant_name, :reindex_all_tenants, :stats]
  before_filter :check_valid_name, :check_duplicate_tenant, :only => [:create, :validate]

  def index
    @tenants = Multitenancy.tenants
    respond_to do |format|
      format.xml { render :template => "tenants/index.rxml", :layout => false }
    end
  end

  def stats
    @stats = Multitenancy.stats
    respond_to do |format|
      format.xml { render :template => "tenants/stats.rxml", :layout => false }
    end
  end

  def show
    @tenant = Multitenancy.find_tenant(params[:name])
    respond_to do |format|
      format.xml { render :template => "tenants/show.rxml", :layout => false }
    end
  end

  def create
    TenantCreationPublisher.new(params).publish_message
    head :ok
  end

  def destroy
    TenantDestructionPublisher.new(params).publish_message
    head :ok
  end

  def upgrade
    TenantInstallation.upgrade_tenant(params[:name], params[:force] == 'true')
    head :ok
  end

  def license_registration
    Multitenancy.activate_tenant(params[:name]) do
      begin
        @registration = CurrentLicense.registration
        respond_to do |format|
          format.xml { render :template => "license/show.rxml", :layout => false }
        end
      ensure
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end

  def register_license
    Multitenancy.activate_tenant(params[:name]) do
      begin
        key = params[:license][:license_key]
        licensed_to = params[:license][:licensed_to]

        status = CurrentLicense.register!(key, licensed_to)
        if status.valid?
          head :ok
        else
          render :text => status.detail, :status => :bad_request
        end
      ensure
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end

  def validate
    head :ok
  end

  def derive_tenant_name
    tenant_name = Multitenancy.derive_tenant_name(params[:company_name])
    render :text => tenant_name
  end

  protected

  def check_valid_name
    render :text => "Site name must start with a letter or digit, end with a letter or digit, and have as interior characters only letters, digits, and hyphens(-).", :status => :bad_request unless Multitenancy.valid_name?(params[:name])
  end

  def check_duplicate_tenant
    render :text=> "Site name has already been taken.", :status => :conflict if Multitenancy.tenant_exists?(params[:name])
  end

  def check_tenant_exists
    if params[:name].blank? || !Multitenancy.tenant_exists?(params[:name])
      head(:not_found)
    end
  end

  def check_configuration
    head(:not_found) unless MingleConfiguration.multitenancy_migrator?
  end
end
