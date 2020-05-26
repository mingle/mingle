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

class DependenciesController < ProjectApplicationController
  allow :get_access_for => [:index, :link_cards_popup, :popup_show, :confirm_delete, :dependency_name, :popup_history],
        :put_access_for => [:create, :link_cards, :toggle_resolved, :update, :unlink_card_popup, :delete, :update_resolving_project],
        :delete_access_for => [:remove_attachment]

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["confirm_delete", 'delete'],
             UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => [ "create", "link_cards_popup", "link_cards", "toggle_resolved", "update", "unlink_card_popup", "update_resolving_project"]

  skip_before_filter :ensure_project, :only => [:popup_show]
  skip_before_filter :require_project_membership_or_admin, :only => [:dependency_name, :popup_show, :remove_attachment]
  before_filter :check_dependency_edit_access, :only => [:remove_attachment]
  before_filter :check_dependency_read_access, :only => [:popup_show, :dependency_name]

  include DependenciesHelper
  include DependencyActions

  def index
    @view = @project.dependency_views.current
    @view.update_params(params)
    if (params[:after_id] && params[:status])
      params[:limit] ||= 25
      dependencies = @view.dependencies_with_status(params[:status].upcase, {:limit => params[:limit], :after_id => params[:after_id]})
      return render :partial => 'dependencies/dependencies_cells', :locals => {:dependencies => dependencies, :show_load_more =>  (dependencies.size == params[:limit].to_i)}
    end
  end

  def dependency_name
    return render :text => @dependency.name
  end


  def create
    card = @project.cards.find_by_number(params[:dependency][:raising_card_number])
    @dependency = card.raise_dependency(params[:dependency].slice(:name, :description, :desired_end_date, :resolving_project_id))
    @dependency.editor_content_processing = true
    if @dependency.save
      render :json => {:dependency => @dependency,
                       :card_number => @dependency.raising_card_number,
                       :status => @dependency.raising_card.raised_dependencies_status.downcase,
                       :new_waiting_resolving_count => @project.new_waiting_resolving_count}
    else
      set_rollback_only
      render :text => @dependency.errors.full_messages, :status => 400
    end
  end

  def popup_history
    dependency = Dependency.find(params[:id])
    history = History.for_versioned(@project, dependency)
    render :partial => 'shared/events',
      :locals => {:include_object_name => false, :include_version_links => false, :show_initially => true, :history => history, :project => @project, :popup => true}
  end

  def confirm_delete
    @dependency = Dependency.find_by_number(params[:number])

    unless @dependency.present?
      render :json => {:error => "Could not find dependency #{params[:number]}"}.to_json, :status => 422
      return
    end

    unless on_raising_project?
      render :json => {:error => "This dependency can only be deleted from the project that raised created it"}.to_json, :status => 422
      return
    end

    render_in_lightbox "dependencies/confirm_delete"
  end

  def delete
    @dependency = Dependency.find_by_number(params[:number])

    unless @dependency.present?
      render :json => {:error => "Could not find dependency #{params[:number]}"}.to_json, :status => 422
      return
    end

    unless on_raising_project?
      render :json => {:error => "This dependency can only be deleted from the project that raised created it"}.to_json, :status => 403
      return
    end

    number = @dependency.number

    affected_cards = on_resolving_project? ? @dependency.dependency_resolving_cards.map(&:card_number) : []
    affected_cards << @dependency.raising_card_number

    if @dependency.destroy
      render :json => {:deleted => number, :prefixed_number => @dependency.prefixed_number, :relatedCards => affected_cards, :new_waiting_resolving_count => @project.new_waiting_resolving_count}.to_json, :status => :ok
    else
      set_rollback_only
      render :json => {:failed => true, :reason => @dependency.errors.full_messages}.to_json, :status => 422
    end

  end

  def link_cards_popup
    @dependency = Dependency.find_by_number(params[:number])
    render :json => { :lightbox_contents => render_to_string(:partial => "dependencies/link_cards_popup") }
  end

  def link_cards
    @dependency = Dependency.find_by_number(params[:dependency][:number])
    errors = []
    cards = params[:dependency][:cards].map do |card_number|
      @project.cards.find_by_number(card_number)
    end
    if @dependency.raising_project_id == @dependency.resolving_project_id && cards.any?{|card| @dependency.raising_card_number == card.number }
      errors << "Cannot link raising card as resolving card."
    else
      success = @dependency.link_resolving_cards(cards)
      errors << @dependency.errors.full_messages if !success
    end

    errors.flatten!

    if errors.empty?
      @dependency.reload
      update_popup(@dependency.resolving_cards)
    else
      set_rollback_only
      render :json => errors.to_json, :status => :unprocessable_entity
    end
  end

  def toggle_resolved
    @dependency = @project.dependencies.find_by_number(params[:dependency][:number])

    if @dependency.blank?
      set_rollback_only
      flash[:error] = "Could not find dependency #{params[:dependency][:number]}"
    else
      @dependency.toggle_resolved_status
      update_popup(@dependency.resolving_cards)
    end
  end

  def unlink_card_popup
    @dependency = Dependency.find_by_number(params[:dependency][:number])

    if @dependency.blank?
      set_rollback_only
      flash[:error] = "Could not find dependency #{params[:dependency][:number]}"
    else
      @dependency.unlink_resolving_card_by_number(params[:dependency][:card_number].to_i)
      update_popup([Card.find_by_number(params[:dependency][:card_number].to_i)])
    end
  end

  def update_resolving_project
    @dependency = Dependency.find_by_number(params[:number])

    return render :json => "Cannot find dependency D#{params[:number]}", :status => :not_found if @dependency.blank?
    return render :json => {:message => "Not authorized"}.to_json, :status => 401 unless allowed_to_edit(@dependency.raising_project)
    return render :json => {:message => "Project doesn't exist"}.to_json, :status => 400 unless Project.exists?(params[:resolving_project_id].to_i)

    @dependency.resolving_project_id = params[:resolving_project_id].to_i
    if @dependency.save
      @view = @project.dependency_views.current
      render :json => {
        :lightbox_contents => render_to_string(:partial => 'dependencies/dependency_lightbox_show',
                                               :locals => { :dependency => @dependency, :date_format_context => date_format_context, :allowed_to_edit_raising => allowed_to_edit(@dependency.raising_project), :allowed_to_edit_resolving => allowed_to_edit(@dependency.resolving_project)}),
        :card_number => @dependency.raising_card_number,
        :dependency_number => @dependency.number,
        :dependencies_table => render_to_string(:partial => 'dependencies/dependency_tab_table',
                                                :locals => { :view => @view, :project => @project })}
    else
      set_rollback_only
      render :json => @dependency.errors.full_messages
    end
  end

  def current_tab
    DisplayTabs::DependenciesTab.new(@project, self)
  end

  private

  def check_dependency_edit_access
    @dependency = Dependency.find(params[:id])
    return render :text => "You do not have access for this action", :status => 401 unless authorized_to_edit_dependency(@dependency)
  end

  def check_dependency_read_access
    @dependency = Dependency.find_by_number(params[:number])
    if @dependency.blank?
      return render :text => "Cannot find dependency D#{params[:number]}", :status => 404
    end

    return render :text => "You do not have access to this resource", :status => 401 unless authorized_to_access_dependency(@dependency)
  end

  def update_popup(resolving_cards)
    @view = @project.dependency_views.current
    resolving_statuses = resolving_cards.inject({}) do |memo, card|
      memo[card.number] = card.dependencies_resolving_status
      memo
    end

    render :json => {
      :lightbox_contents => render_to_string(:partial => 'dependencies/dependency_lightbox_show',
        :locals => { :dependency => @dependency, :date_format_context => date_format_context, :allowed_to_edit_raising => allowed_to_edit(@dependency.raising_project), :allowed_to_edit_resolving => allowed_to_edit(@dependency.resolving_project)}),
      :card_number => @dependency.raising_card_number,
      :icon_status => @dependency.raising_card.raised_dependencies_status.downcase,
      :resolving_cards_statuses => resolving_statuses,
      :dependency_number => @dependency.number,
      :status => @dependency.status.downcase,
      :new_waiting_resolving_count => @project.new_waiting_resolving_count,
      :dependencies_table => render_to_string(:partial => 'dependencies/dependency_tab_table',
        :locals => { :view => @view, :project => @project })}
  end

  def date_format_context
    @project
  end
end
