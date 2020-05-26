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

class InstallController < ApplicationController
  layout 'install'
  skip_filter :check_user
  skip_filter :check_need_install
  skip_filter :check_license
  skip_filter :check_license_expiration
  skip_filter :authenticated?, :except => ['register_license']
  skip_filter :wrap_in_transaction

  skip_filter :need_to_accept_saas_tos

  before_filter :skip_install_when_ready, :except => ['do_register_license', 'ensure_system_user', 'set_tenant_config']

  skip_before_filter :verify_authenticity_token # until we have a mingle install/setup API, we need to drive these forms manually

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  allow :get_access_for => [:index, :connect, :migrate, :configure_smtp, :skip_configure_smtp, :eula, :signup, :register_license, :configure_site_url]

  def index
  end

  def connect
    begin
      redirect_to :action => 'migrate' if ActiveRecord::Base.connection.active?
    rescue
    end
    @configs = Install::DatabaseConfig::CONFIGS
    @config = Install::DatabaseConfig.find_database_type(params[:database_type]).new
  end

  def do_connect
    @configs = Install::DatabaseConfig::CONFIGS
    @config = Install::DatabaseConfig.find_database_type(params[:database_type]).new(params[:config])

    if !@config.valid?
      render :action => 'connect'
      return
    end
    @config.set_rails_configuration
    @config.write_database_yml
    @config.establish_connection
    if Database.newer_than_installer?
      html_flash.now[:error] = render_to_string :file => File.join(Rails.public_path,'startup_messages', 'SCHEMA_VERSION_INCOMPATIBLE_WITH_INSTALLER.html')
      render :action => 'connect'
    else
      redirect_to :action => 'migrate'
    end
  rescue => e
    log_error(e)
    html_flash.now[:error] = render_to_string(:partial => 'database_error', :locals => {:error => e})
    render :action => 'connect'
  end

  def migrate
    redirect_to :action => 'configure_site_url' unless Database.need_migration?
  end

  def do_migrate
    begin
      Database.migrate
      redirect_to :action => :configure_site_url
    rescue => e
      html_flash.now[:error] = render_to_string(:partial => 'database_error', :locals => {:error => e})
      render :action => 'migrate'
    end
  end

  def configure_site_url
    redirect_to :action => 'configure_smtp' unless MingleConfiguration.need_configure_site_url?
    @site_url_errors ||= []
    @secure_site_url_errors ||= []
    @site_url = MingleConfiguration.legacy_smtp_site_url || MingleConfiguration.suggested_site_url(request)
    @secure_site_url = MingleConfiguration.secure_site_url
  end

  def do_configure_site_url
    @site_url = params[:site_url]
    @secure_site_url = params[:secure_site_url]
    @site_url_errors = MingleConfiguration.validate_site_url(@site_url)
    @secure_site_url_errors = @secure_site_url.present? ? MingleConfiguration.validate_secure_site_url(@secure_site_url) : []
    if @site_url_errors.any? || @secure_site_url_errors.any?
      render :action => :configure_site_url
      return
    end
    MingleConfiguration.site_url = @site_url
    MingleConfiguration.secure_site_url = @secure_site_url if @secure_site_url.present?
    MingleConfiguration.save_to_file SITE_URL_CONFIG_FILE
    redirect_to :action => :configure_smtp
  end

  def configure_smtp
    unless File.exists?(AUTH_CONFIG_YML)
      AuthConfiguration.create(params) #putting this now, as there is no place in the installer for the user to configure this now.
    end
    if File.exists?(SMTP_CONFIG_YML)
      redirect_to :action => 'eula'
    else
      @smtp_settings, @site, @sender = OpenStruct.new, OpenStruct.new, OpenStruct.new
    end
  end

  def do_configure_smtp
    SmtpConfiguration.create(params)
    redirect_to :action => 'eula'
  end

  def skip_configure_smtp
    SmtpConfiguration.create({})
    redirect_to :action => 'eula'
  end

  def eula
    redirect_to :action => 'signup' if License.eula_accepted?
  end

  def eula_accepted
    License.eula_accepted
    redirect_to :action => 'signup'
  end

  def signup
    redirect_to :action => 'register_license' unless User.no_users?
    @user = params[:user] ? User.new(:login => params[:user][:login]) : User.new
  end

  def do_signup
    unless User.no_users?
      redirect_to :action => 'register_license'
      return
    end

    params[:user][:login].strip!
    @user = User.new(params[:user])

    if @user.save
      session[:login] = @user.login
      @user.update_last_login
      redirect_to :action => 'register_license'
    else
      render :action => 'signup'
    end
  end

  def register_license
    redirect_to root_url unless CurrentLicense.blank?
  end

  def do_register_license
    status = CurrentLicense.register!(params[:license_key], params[:licensed_to])
    if status.valid?
      recheck_license_on_next_request
      redirect_to root_url
    else
      flash.now[:error] = 'License data is invalid'
      render :action => 'register_license'
    end
  end

  def ensure_system_user
    SystemUser.ensure_exists
    head :ok
  end

  private

  def skip_install_when_ready
    if !Install::InitialSetup.need_install? && !CurrentLicense.blank?
      redirect_to root_url
    end
  end
end
