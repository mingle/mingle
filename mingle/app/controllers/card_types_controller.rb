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

class CardTypesController < ProjectAdminController
  allow :get_access_for => [:list, :new, :show, :edit, :edit_defaults, :confirm_delete, :chart], :redirect_to => { :action => :list }
  helper :cards
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["new", "create", "update", "edit", "confirm_delete", "delete", "update_color", "reorder", "edit_defaults", "update_defaults", "preview", "chart", "confirm_update", "create_restfully"]

  def list
    @card_types = @project.card_types
    respond_to do |format|
      format.html do
        render :action => 'list'
      end
      format.xml do
        render_model_xml @card_types, :dasherize => false
      end
      format.json do
        @include_property_values = params[:include_property_values]
        render layout: false
      end
    end
  end

  def show
    @card_type = @project.card_types.find_by_id(params[:id])
    respond_to do |format|
      format.xml do
        render_model_xml @card_type
      end
      format.json do
        @include_property_values = params[:include_property_values]
        render layout: false
      end
    end
  end

  def new
    @card_type = CardType.new
    @prop_defs = @project.managable_property_definitions_with_hidden
    @checked_property_definitions = @prop_defs
  end

  def reorder
    indicates = params["card_types_reorder_container"].collect(&:to_i)
    @project.card_type_definition.reorder(indicates) {|card_type| card_type.id}
    render :nothing => true
  end

  def update_color
    card_type = @project.card_types.find(params[:id])
    card_type.update_attribute(:color, params[:color_provider_color])
    render(:update) do |page|
      page.replace "color_panel_#{card_type.id}", color_panel_for(card_type)
    end
  end

  def create
    @card_type = CardType.new(params[:card_type].merge({:project_id => @project.id}))
    @checked_property_definitions = property_definitions_from(params)

    if @card_type.save_and_set_property_definitions(@checked_property_definitions)
      flash[:notice] = "Card Type #{@card_type.name.bold} was successfully created"
      redirect_to :action => 'list'
    else
      set_rollback_only
      @prop_defs = @project.managable_property_definitions_with_hidden
      html_flash.now[:error] = @card_type.errors.full_messages
      render :action => 'new'
    end
  end

  def create_restfully
    params[:card_type] ||= {}
    prop_def_names = (params[:card_type].delete(:property_definitions) || []).map { |prop_def_parameter| prop_def_parameter[:name].downcase }
    prop_defs = @project.all_property_definitions.find(:all, :conditions => ["LOWER(name) IN (?)", prop_def_names])
    @card_type = CardType.new(params[:card_type].merge({:project_id => @project.id}))

    prop_def_names.each do |prop_def_name|
      unless prop_defs.map { |pd| pd.name.downcase }.include?(prop_def_name.downcase)
        @card_type.errors.add_to_base("There is no such property: #{prop_def_name}")
      end
    end

    if @card_type.errors.empty? && @card_type.save_and_set_property_definitions(prop_defs)
      head :created, :location => rest_card_type_show_url(:id => @card_type.id, :format => 'xml')
    else
      set_rollback_only
      render :xml => @card_type.errors.to_xml, :status => 422
    end
  end

  def edit
    @card_type = @project.card_types.find(params[:id])
    @checked_property_definitions = @card_type.property_definitions_with_hidden_without_order
    @prop_defs = prop_defs_for_editing_card_type(@project, @card_type)
  end

  def edit_defaults
    @card_type = @project.card_types.find(params[:id])
    @card_type.create_card_defaults_if_missing

    @card_type.card_defaults.convert_redcloth_to_html! if @card_type.card_defaults.redcloth

    @card_defaults = @card_type.card_defaults
    @disallow_inline_image = true
  end

  def update_defaults
    @card_defaults = CardDefaults.find_by_id(params[:id])
    @card_type = @card_defaults.card_type

    if params[:properties]
      @card_defaults.update_properties(params[:properties])
      PropertyDefinition.create_new_enumeration_values_from(params[:properties], @project)
    end

    if params[:card_defaults]
      @card_defaults.set_checklist_items(params[:card_defaults][:checklist_items] || [])
      if params[:card_defaults][:description]
        @card_defaults.description = process_content_from_ui(params[:card_defaults][:description])
        @card_defaults.editor_content_processing = !api_request?
      end
    end

    if @card_defaults.errors.empty? && @card_defaults.save!
      flash[:notice] = "Defaults for card type #{@card_type.name.bold} were successfully updated"
      redirect_to :action => 'list'
    else
      set_rollback_only
      flash.now[:error] = @card_defaults.errors.full_messages
      render :action => 'edit_defaults'
    end
  end

  def preview
    set_rollback_only

    @card_defaults = CardDefaults.find(params[:id])
    @card_defaults.attributes = params[:card_defaults]

    # also store it in the session so that charts can fetch content from the session
    session[:renderable_preview_content] = @card_defaults.description
    render :partial => 'preview'
  end

  def confirm_update
    @card_type = @project.card_types.find(params[:id])
    @property_definitions = property_definitions_from(params)
    @checked_property_definitions = @property_definitions
    @deleted_property_definitions = (@card_type.managable_property_definitions_with_hidden - @property_definitions)

    formula_property_definitions = @card_type.property_definitions_with_hidden.select { |pd| pd.is_a?(FormulaPropertyDefinition) }
    @formula_property_definitions_that_will_be_removed_by_force = formula_property_definitions.select do |pd|
      pd.uses_one_of?(@deleted_property_definitions) && !@deleted_property_definitions.include?(pd)
    end.collect(&:name)

    @blockings = @deleted_property_definitions.collect{|pd| pd.blockings_when_dissociate_card_types([@card_type]) }.flatten
    if @blockings.any?
      set_rollback_only
      @card_type.attributes = params[:card_type]
      @prop_defs = prop_defs_for_editing_card_type(@project, @card_type)
      render :action => 'edit' and return
    end

    @deleted_transitions = project.transitions_dependent_upon_property_definitions_belonging_to_card_types([@card_type],  @deleted_property_definitions).collect(&:name).smart_sort
    @deleted_property_definitions = @deleted_property_definitions.collect(&:name).smart_sort
    @property_definitions_order = params['property_definitions_order']
    if @deleted_property_definitions.empty?
      update
    end
  end

  def update
    @card_type = @project.card_types.find(params[:id])
    @checked_property_definitions = property_definitions_from(params)
    card_type_params = params[:card_type].merge({:managable_property_definitions => property_definitions_from(params)})
    if (@card_type.update_attributes(card_type_params))
      flash[:notice] = "Card Type #{@card_type.name.bold} was successfully updated"
      redirect_to :action => 'list'
    else
      set_rollback_only
      @prop_defs = prop_defs_for_editing_card_type(@project, @card_type)
      html_flash.now[:error] = @card_type.errors.full_messages
      render :action => 'edit'
    end
  end

  def confirm_delete
    @card_type = @project.card_types.find(params[:id])
  end

  def delete
    @card_type = @project.card_types.find(params[:id])
    @card_type.destroy_with_validate
    if(@card_type.errors.empty?)
      flash[:notice] = "Card Type #{@card_type.name.bold} was successfully deleted"
      redirect_to :action => 'list'
    else
      set_rollback_only
      html_flash[:error] = @card_type.errors.full_messages
      redirect_to :action => 'list'
    end
  end

  def chart
    @card_defaults = CardDefaults.find_by_id(params[:id])
    content = params[:preview] ? session[:renderable_preview_content] : content = @card_defaults.description
    chart = Chart.extract(content, params[:type], params[:position].to_i, :content_provider => @card_defaults)
    send_data(chart.generate, :type => "image/png",:disposition => "inline")
  end

  def always_show_sidebar_actions_list
    ['list']
  end

  private
  def prop_defs_for_editing_card_type(project, card_type)
    project_prop_defs = project.managable_property_definitions_with_hidden
    card_type_prop_defs = card_type.managable_property_definitions_with_hidden
    card_type_prop_defs + project_prop_defs.delete_if {|prop_def| card_type_prop_defs.include?(prop_def)}
  end

  def property_definitions_from(params)
    return [] unless params['property_definitions']
    property_definition_ids = params['property_definitions'].values
    ordered_property_definition_ids = property_definitions_order_from(params)
    valid_property_definition_ids = @project.property_definitions_with_hidden.collect(&:id)
    raise 'Attempt to use non-existent property' unless (property_definition_ids + ordered_property_definition_ids).all? { |pd_id| valid_property_definition_ids.include?(pd_id.to_i) }
    property_definitions_by_id(ordered_property_definition_ids & property_definition_ids)
  end

  def property_definitions_by_id(ids)
    @project.property_definitions_with_hidden.select_in_order(ids)
  end

  def property_definitions_order_from(params)
    reorder_container = params['property_definitions_order']
    reorder_container = reorder_container[0] unless reorder_container.class == String
    reorder_container.split('&').collect{|order_item| order_item.split('=')[1] }
  end
end
