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

class PropertyDefinitionsController < ProjectAdminController

  skip_filter :wrap_in_transaction, :only => :delete  # model manages this transaction

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  allow :get_access_for => [:index, :show, :new, :edit, :confirm_hide, :confirm_delete, :values], :redirect_to => {:action => :index}

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN =>["new", "create", "reorder", "edit", "update", "confirm_hide", "hide", "unhide", "toggle_restricted", "confirm_delete", "delete", "toggle_transition_only", "confirm_update"]

  def index
    @property_definitions = @project.managable_property_definitions_with_hidden
    respond_to do |format|
      format.html
      format.xml do
        render_model_xml @project.property_definitions_in_smart_order(true), :root => (params[:api_version] == 'v1' ? 'records' : 'property_definitions'), :dasherize => false
      end
      format.json do
        @property_definitions = @project.property_definitions_in_smart_order(true)
        render layout: false
      end
    end
  end

  def show
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])
    respond_to do |format|
      format.html
      format.xml do
        render_model_xml @property_definition
      end
      format.json { render layout: false }
    end
  end

  def reorder
    prop_def = @project.property_definitions_with_hidden.find(params[:id])
    indicates = params["reorder_container_#{prop_def.id}"].collect(&:to_i)
    prop_def.reorder(indicates) {|enum| enum.id}
    render :nothing => true
  end

  def new
    @property_definition = @project.all_property_definitions.new
    @card_types = []
  end

  def create
    @property_definition = @project.all_property_definitions.send(create_property_definition_method, params[:property_definition])

    #do not call valid? here. That will run validations again, but since @property_definition is no longer new, it runs update validations instead.
    #These will fail without the subsequent lines running. So wait until the next line runs and saves the object again,
    #which will run through update validations at the correct point in time instead.
    no_error_while_creating_property_definition = @property_definition.errors.empty?

    @card_types = params_card_types
    if no_error_while_creating_property_definition
      # we did card_types update inside create_api_property_definition, because card types params name is different between
      # normal property definition creation and api
      @property_definition.card_types = @card_types if params[:format] != 'xml'

      if @property_definition.valid?
        @project.reload.update_card_schema
        @property_definition.update_all_cards if @property_definition.respond_to? :update_all_cards
        respond_to do |format|
          format.html do
            flash[:notice] = prop_success_msg('created')
            redirect_to :action => 'index'
          end
          format.xml do
            head :created, :location => rest_property_definition_show_url(:id => @property_definition.id, :format => 'xml')
          end
        end

        return # only return when everything is fine, need cleanup -- xli
      end
    end

    set_rollback_only
    respond_to do |format|
      format.html do
        render :action => 'new'
      end
      format.xml do
        render :xml => @property_definition.errors.to_xml, :status => 422
      end
    end
  end

  def edit
    @property_definition = @property_definition || @project.property_definitions_with_hidden.find(params[:id])

    if @property_definition.aggregated?
      redirect_to :controller => "card_trees",
                  :action => "edit_aggregate_properties",
                  :id => @property_definition.tree_configuration,
                  :popup_card_type_id => @property_definition.aggregate_card_type.id
    else
      if @property_definition.errors.empty?
        @card_types = @property_definition.card_types
      end
    end
  end

  def confirm_update
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])
    @card_types = params_card_types
    @deleted_card_types = (@property_definition.card_types - @card_types)
    @deleted_transitions = @project.transitions_dependent_upon_property_definitions_belonging_to_card_types(@deleted_card_types, [@property_definition]).collect(&:name).smart_sort

    formula_property_definitions_using_property = @project.formula_property_definitions_with_hidden.using(@property_definition.name)
    @card_types_affecting_formulas = @deleted_card_types.select { |card_type| formula_property_definitions_using_property.collect(&:card_types).flatten.include?(card_type) }
    @card_type_to_formulas = {}
    @card_types_affecting_formulas.each do |card_type|
      @card_type_to_formulas[card_type.name] = formula_property_definitions_using_property.select { |formula_prop_def| formula_prop_def.card_types.include?(card_type) }.collect(&:name).sort
    end
    blockings = @property_definition.blockings_when_dissociate_card_types(@property_definition.card_types - @card_types)
    if blockings.any?
      set_rollback_only
      @property_definition.attributes = params[:property_definition]
      flash.now[:info] = render_to_string(:partial => 'update_blockings', :locals => {:blockings => blockings, :model => @property_definition})
      render :action => 'edit'
      return
    end

    @deleted_card_types = @deleted_card_types.collect(&:name).smart_sort
    if @deleted_card_types.empty?
      update
    end
  end

  def update
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])

    # necessary to reload project after update in case a rename took place -- if a rename did
    # happen most other property def related functions would fail w/o this reload
    @card_types = params_card_types
    original_formula = @property_definition.attributes['formula']
    params[:property_definition][:null_is_zero] ||= false
    @property_definition.update_attributes(params[:property_definition])
    @project.reload
    @property_definition.update_attributes(:card_types => @card_types)
    property_definition_successfully_updated = @property_definition.valid?
    if @property_definition.is_a?(FormulaPropertyDefinition) && property_definition_successfully_updated
      new_formula = @property_definition.attributes['formula']
      @property_definition.formula = original_formula
      property_definition_successfully_updated &&= @property_definition.change_formula_to(new_formula)
    end

    if property_definition_successfully_updated
      flash[:notice] = prop_success_msg('updated')
      redirect_to :action => 'index'
    else
      set_rollback_only
      render :action => 'edit'
    end
  end

  def confirm_hide
    @property_definition = @project.find_property_definition(params[:name])
    render_in_lightbox 'confirm_hide'
  end

  def hide
    @property_definition = @project.find_property_definition(params[:name])
    views = @project.favorites_and_tabs.of_card_list_views.using(@property_definition).map { |pd| pd.favorited.destroy.name }.smart_sort.join(', ')
    @property_definition.update_attribute(:hidden, true)
    flash[:notice] = "Property #{@property_definition.name.bold} is now hidden. "
    if views.present?
      flash[:notice] << "The following favorites have been deleted: #{views}."
    end
    redirect_to :action => 'index'
  end

  def unhide
    @property_definition = @project.find_property_definition(params[:name], :with_hidden => true)
    @property_definition.update_attribute(:hidden, false)
    flash.now[:notice] = "Property #{@property_definition.name.bold} is now shown"

    render_update
  end

  def toggle_restricted
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])
    restricted = !@property_definition.restricted?
    @property_definition.update_attributes(:restricted => restricted)
    flash[:notice] = "Property #{@property_definition.name.bold} is now #{restricted ? 'locked' : 'unlocked'}"

    render_update
  end

  def toggle_transition_only
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])
    @property_definition.update_attribute(:transition_only, !@property_definition.transition_only)

    if @property_definition.errors.empty?
      if @property_definition.transition_only
        flash.now[:notice] = "Property #{@property_definition.name.bold} can now only be changed through a transition."
      else
        flash.now[:notice] = "Property #{@property_definition.name.bold} is no longer only available to be changed through a transition."
      end
    else
      set_rollback_only
      flash[:error] = @property_definition.errors.full_messages
    end

    render_update
  end

  def confirm_delete
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])
    @deletion = @property_definition.deletion
    render(@deletion.blocked? ? :deletion_blockings : :deletion_effects)
  end

  def delete
    @property_definition = @project.property_definitions_with_hidden.find(params[:id])
    @property_definition.destroy
    flash[:notice] = "Property #{@property_definition.name.bold} has been deleted."
    redirect_to :action => 'index'
  end

  def always_show_sidebar_actions_list
    ['index']
  end

  def values
    property_definition = @project.property_definitions_with_hidden.find(params[:id])
    @property_definition_values = property_definition.label_values_for_charting
    respond_to do |format|
      format.json { render layout: false}
    end
  end

  protected

  def wrap_in_transaction(&block)
    return super(&block) if action_name != 'create'
    begin
      super(&block)
    rescue
      ProjectCacheFacade.instance.clear_cache(@project.identifier) if @project
      raise
    end
  end

  private

  def create_property_definition_method
    if params[:format] == 'xml'
      definition_type = 'api'
    else
      definition_type = (params[:definition_type] || 'text list').gsub(/\s/, '_')
    end
    "create_#{definition_type}_property_definition"
  end

  def params_card_types
    params[:card_types] ? @project.card_types.find(params[:card_types].values) : []
  end

  def prop_success_msg(action)
    "Property was successfully #{action}."
  end

  def render_update
    render(:update) do |page|
      page.refresh_flash
      page.replace "prop_def_row_#{@property_definition.id}", :partial => 'property_definitions/property_definition', :object => @property_definition
    end
  end
end
