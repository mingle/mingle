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

class RepositoryController < ProjectAdminController
  allow :get_access_for => [:index, :configure, :show, :cancel], :post_access_for => [:save, :create, :delete], :put_access_for => [:update, :save]

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ['index', 'save', 'update', 'show', 'create', 'delete', 'configure']

  def admin_action_name
    super.merge(:controller => 'repository')
  end

  def index
    repository_type = params[:repository_type]
    if repository_type.nil?
      list_all
    else
      return unless available?(repository_type.constantize)
      if api_request?
        list_all
      else
        render :template => "#{concrete_controller_for(repository_type)}/index"
      end
    end
  end

  def show
    list_all(false)
  end

  def save
    config_model = params[:repository_type].constantize
    extracted_params = params[:repository_config] || params[params[:repository_type].try(:underscore)]

    if extracted_params.blank?
      respond_to do |format|
        format.html do
          flash.now[:error] = "Unknown repository type."
          render :index and return
        end
        format.xml { head :unprocessable_entity and return }
      end
    end

    @repository_config = config_model.create_or_update(@project.id, params[:id], extracted_params)

    if @repository_config.errors.empty?
      respond_to do |format|
        format.html do
          flash.clear
          flash[:notice] = 'Repository settings were successfully saved.'
          redirect_to :action => :index
        end
        response_code = params[:id].blank? ? :created : :ok
        restful_index_url = "rest_#{concrete_controller_for(@repository_config.class)}_index_url"
        format.xml { render :xml => model_xml(@repository_config, {:dasherize => false}), :status => response_code, :location => send(restful_index_url.to_sym, :project_id => @project.identifier) }
      end
    else
      set_rollback_only
      respond_to do |format|
        format.html do
          flash.now[:error] = @repository_config.errors.full_messages.join(', ')
          render :template => "#{concrete_controller_for(@repository_config.class)}/index"
        end
        format.xml { render :xml => @repository_config.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end

  alias_method :update, :save
  alias_method :create, :save

  def delete
    @project.delete_repository_configuration
    if @project.errors.empty?
      flash.clear
      flash[:notice] = 'Repository settings successfully deleted.'
    else
      flash[:error] = @project.errors.full_messages
    end
    redirect_to :action => 'index'
  end

  def cancel
    redirect_to :action => :index
  end

  def always_show_sidebar_actions_list
    ['index']
  end

  private

  def available?(model)
    if model.respond_to?(:client_installed?) && !model.client_installed?
      error_message = model.client_unavailable_message
      respond_to do |format|
        format.html do
          flash.now[:error] = error_message
          return false
        end
        format.xml do
          xml = "".tap do |result|
            builder = Builder::XmlMarkup.new(:target => result, :indent => 2)
            builder.errors do
              builder.error error_message
            end
          end
          render :xml => xml, :status => 422 and return false
        end
      end
    end
    true
  end

  def list_all(all=true)
    @repository_config = MinglePlugins::Source.find_for(@project)
    if @repository_config && (params[:repository_type].blank? || params[:repository_type] == @repository_config.class.name)
      return unless available?(@repository_config.class)
      respond_to do |format|
        format.html { render :template => "#{concrete_controller_for(@repository_config.class)}/index" }
        models = all ? [@repository_config] : @repository_config
        format.xml { render_model_xml models, :dasherize => false }
      end
    else
      respond_to do |format|
        format.html { render :index }
        format.xml { render :xml => "No repository configuration found in project #{@project.identifier}.", :status => :not_found }
      end
    end
  end

  def concrete_controller_for(type_or_name)
    type_or_name.to_s.tableize.singularize.pluralize
  end
end
