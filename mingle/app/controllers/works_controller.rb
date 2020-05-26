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

class WorksController < PlannerApplicationController
  helper_method :filter_cards_locals
  allow :get_access_for => [:index, :cards]
  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ['bulk_delete', 'bulk_create', "cards", "index"],
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index]
  before_filter :load_objective

  def index
    @title = "Work"
    @filters = Work::Filter.decode(params[:filters])
    @projects_in_sync = @objective.filters.map(&:project_id).uniq
    @works = paginate(@filters.apply(@objective.works),
        :order => "LOWER(#{Objective.table_name}.name), LOWER(#{Project.table_name}.name), card_number DESC",
        :include => [:objective, :project])
    respond_to do |format|
      format.html do
        render :action => 'index'
      end
      format.js do
        render :update do |page|
          page.replace "work_list", :partial => 'work_list'
        end
      end
    end
  end

  def cards
    @title = "Add Work"
    @sorted_projects = @program.projects.smart_sort_by(&:name)
    @project = params[:project_id] ? load_project : nil
    return unless @project

    if @autosync_filter = @objective.filters.find_by_project_id(@project.id)
      @filters_string = @autosync_filter.params[:filters]
    else
      @filters_string = params[:filters]
    end

    @project.with_active_project do |project|
      @filters = Filters.new(project, @filters_string)
      @filters_cards = find_cards_from_query(@filters, params[:filter_page], request.get?)
      @matching_card_count = @filters_cards.empty? ? 0 : @filters_cards.total_entries
    end

    if request.post?
      if params[:autosync] == 'on'
        @autosync_filter = @objective.filters.find_or_create_by_project_id(@project.id)
        @autosync_filter.update_attribute(:params, { :filters => @filters.to_params })
      else
        @autosync_filter.try(:destroy)
      end
      redirect_to @autosync_filter.url_params(:program_id => @program.to_param, :action => 'cards', :filter_page => params[:filter_page])
    else
      respond_to do |format|
        format.html
        format.js do
          render :update do |page|
            page.refresh_flash
            page.replace_html 'filters_result', :partial => 'cards', :locals => filter_cards_locals
            #page.replace 'filters_related_hidden_fields', :partial => 'filters_related_hidden_fields'
            page.replace 'autosync_form', :partial => 'autosync_form'
          end
        end
      end
    end
  end

  def bulk_create
    load_project
    result = @plan.assign_cards(@project, params[:card_numbers], @objective)
    flash[:notice] = "#{pluralize(result, 'card')} added to the feature #{@objective.name.escape_html.bold}."
    appended_params = params.slice(:filters, :project_id, :filter_page)
    redirect_to cards_program_plan_objective_works_url(@program, @objective, appended_params)
  end

  def bulk_delete
    number_of_works_deleted = @plan.works.find(params[:works]).each(&:destroy).size
    flash[:notice] = "#{pluralize(number_of_works_deleted, 'work item')} removed from the feature #{@objective.name.escape_html.bold}."
    redirect_to :action => 'index', :page => params[:page], :filters => params[:filters]
  end

  private
  def load_project
    @project = authorize_resource(@program.projects.find_by_identifier(params[:project_id]))
  end

  def load_objective
    @objective = verify_resource(@program.objectives.planned.find_by_url_identifier(params[:objective_id]))
  end

  def find_cards_from_query(query, page, flash_errors)
    if query.valid?
      paginate(query.as_card_query, :page => page)
    elsif flash_errors
      html_flash.now[:error] = query.errors.join(", ")
      []
    else
      []
    end
  end

  def filter_cards_locals
    {
      :cards => @filters_cards || [],
      :id_postfix => '_filter',
      :paginate_options => { :param_name => 'filter_page' }
    }
  end

end
