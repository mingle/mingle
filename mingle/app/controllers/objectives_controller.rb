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

class ObjectivesController < PlannerApplicationController
  allow :put_access_for => [:update, :restful_update],
        :get_access_for => [:index, :timeline_objective, :confirm_delete, :edit, :popup_details, :work, :work_progress, :view_value_statement, :restful_show, :restful_list],
        :delete_access_for => [:destroy, :restful_create, :restful_delete]

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => %w(update create edit destroy confirm_delete popup_details work load_objective index view_value_statement),
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index, :restful_show, :restful_list, :popup_details]

  before_filter :load_objective, :except => [:create, :work_progress, :index, :restful_list, :restful_create]

  def restful_create
    @objective = Objective.new

    validate_create_parameters(params[:objective])

    unless @objective.errors.empty?
      render_validation_errors
      return
    end

    start_date = Date.parse(params[:objective][:start_at])
    end_date = Date.parse(params[:objective][:end_at])

    next_available_pos = @program.plan.next_available_position_between(start_date, end_date)
    params[:objective] = {:vertical_position => next_available_pos}.merge(params[:objective])
    params[:objective] = {:program_id => @program.id}.merge(params[:objective])

    if @objective.update_attributes(params[:objective])
      respond_to do |format|
        format.xml do
          render :xml => @objective.to_xml
        end
      end
    else
      render_validation_errors
    end
  end

  def restful_update
    validate_update_parameters(params[:objective])

    if @objective.errors.empty? && @objective.update_attributes(params[:objective])
      respond_to do |format|
        format.xml do
          render :xml => @objective.reload.to_xml
        end
      end
    else
      render_validation_errors
    end
  end

  def restful_delete
    response  = @objective.destroy
    respond_to do |format|
      format.xml do
        render :xml => :ok
      end
    end
  end

  def create
    @objective = @program.objectives.planned.build(params[:objective])

    timeline_objective = TimelineObjective.new(@objective)
    if @objective.save
      render :js => "window.timeline.objectiveCreated(#{timeline_objective.to_json}, #{@plan.reload.to_json});"
    else
      set_rollback_only
      render :js => "window.timeline.objectiveCreationFailed(#{timeline_objective.to_json}, #{filter_identifier(@objective.errors).to_json});"
    end
  end

  def restful_show
    respond_to do |format|
      format.xml { render_model_xml(@objective) }
    end
  end

  def work
    redirect_to program_plan_objective_works_path(@plan.program, @objective)
  end

  def update
    if @objective.update_attributes(params[:objective])
      respond_to do |format|
        format.html do
          flash[:notice] = "Feature #{@objective.name.bold} was successfully updated."
          redirect_to program_plan_path(@plan.program)
        end

        format.js { render :js => "window.timeline.mainViewContent.updatePlan(#{@plan.reload.to_json});
                                   window.timeline.mainViewContent.updateObjective(#{TimelineObjective.from(@objective, @plan).to_json});" }
      end
    else
      flash.now[:error] = filter_identifier(@objective.errors).full_messages
      respond_to do |format|
        format.html do
          render :action => :edit
        end
        format.js { render :nothing => true, :status => 422 }
      end
    end
  end

  def timeline_objective
    respond_to do |format|
      format.json { render :json => TimelineObjective.from(@objective, @plan).to_json }
    end
  end

  def restful_list
    respond_to do |format|
      format.xml do
        render_model_xml(@program.objectives, :compact => true)
      end
    end
  end

  def index
    respond_to do |format|
      format.json do
        display_preference = User.current.display_preference(session).read_preference(:timeline_granularity)
        render :json => { :objectives => @plan.timeline_objectives, :displayPreference => display_preference }.to_json
      end
      format.html do
        redirect_to :controller => :plans, :action => :show
      end
    end
  end

  def confirm_delete
    @objective_projects = @program.projects_with_work_in(@objective)
  end

  def view_value_statement
    render_in_lightbox 'value_statement'
  end

  def work_progress
    @objective = @program.objectives.planned.find(params[:id])
    project = Project.find_by_identifier(params[:project_id])
    snapshots = ObjectiveSnapshot.snapshots_till_date(@objective, project)

    progress = []
    snapshots.each do |snapshot|
      snapshot_date = format_date(snapshot.dated)

      progress << { :date => snapshot_date, :actual_scope => snapshot.total, :completed_scope => snapshot.completed }
    end

    respond_to do |format|
      format.json { render :json  => { :progress => progress }.to_json}
    end
  end

  def format_date(date)
    date.strftime("%Y-%m-%d")
  end

  def popup_details
    @objective.projects.each do |project|
      required_snapshots = (Clock.today.to_date - @objective.start_at.to_date).to_i
      snapshots_count = @objective.objective_snapshots.count(:conditions => ["project_id = ?", project.id])

      if snapshots_count < required_snapshots
        ObjectiveSnapshotProcessor.enqueue(@objective.id, project.id)
      end
    end

    render :update do |page|
      page.replace_html 'objective_details_contents', :partial => "objective_details_popup"
    end
  end

  def destroy
    if params[:move_to_backlog]
      action_taken = 'moved to the backlog'
      @objective.move_to_backlog
    else
      action_taken = 'deleted'
      @objective.destroy
    end
    flash[:notice] = "Feature #{@objective.name.bold} has been #{action_taken}."
    redirect_to program_plan_path(@plan.program)
  end

  protected

  def load_objective
    @objective = verify_resource(@program.objectives.planned.find_by_url_identifier(params[:id]))
  end

  def filter_identifier(errors)
    errors.instance_variable_get(:@errors).reject!{ |attribute, message| attribute == 'identifier' }
    errors
  end

  private

  def render_validation_errors
    respond_to do |format|
      format.xml do
        render :xml => @objective.errors.to_xml, :status => 422
      end
    end
  end

  def validate_create_parameters(objective_params)
    validate_missing_parameters objective_params
    validate_update_parameters objective_params
  end

  def validate_update_parameters(objective_params)
    validate_parameter_names objective_params
    validate_date_formats({:start_at => objective_params[:start_at], :end_at => objective_params[:end_at]})
  end

  def validate_missing_parameters(objective_params)
    missing_parameters = Objective.required_parameters.map(&:to_s) - objective_params.keys
    @objective.errors.add(:base, "The parameter(s) '#{missing_parameters.join('\', \'')}' were not provided.") unless missing_parameters.empty?
  end

  def validate_parameter_names(objective_params)
    invalid_params = []
    invalid_params = objective_params.reject do |name, value|
      @objective.respond_to?("#{name}=")
    end
    @objective.errors.add(:base, "Invalid parameter(s) provided: #{invalid_params.map(&:first).join(", ")}") unless invalid_params.empty?
  end

  def validate_date_formats(date_params)
    date_params.each do |param_name, value|
      begin
        Date.parse(value) unless value.nil?
      rescue ArgumentError
        @objective.errors.add(:base, "The parameter '#{param_name}' was in an incorrect format. Please use 'yyyy-mm-dd'.")
      end
    end
  end

end
