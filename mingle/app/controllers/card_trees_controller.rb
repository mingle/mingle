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

# todo: rename to TreeConfigurationController
class CardTreesController < ProjectAdminController
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN =>["create", "new", "edit", "update", "edit_aggregate_properties", "create_aggregate_property_definition", "update_aggregate_property_definition", "delete", "show_edit_aggregate_form", "show_add_aggregate_form", "delete_aggregate_property_definition", "confirm_delete", 'manage_trees']

  allow :get_access_for => [:index, :list, :manage_trees, :new, :edit, :edit_aggregate_properties, :confirm_delete],
        :redirect_to => {:action => :list}

  def index
    list
    render :action => 'list'
  end

  def list
    @trees = @project.tree_configurations
  end

  def manage_trees
    list
    render :action => 'list'
  end

  def new
    @tree = TreeConfiguration.new
    if @project.card_types.size < 2
      flash.now[:info] = render_to_string :inline => %{
        Trees require at least two card types in a project. <%=link_to 'Return to the card type list', :controller => 'card_types', :action => 'list' %>.
      }
    end
  end

  def create
    @tree = TreeConfiguration.new(params[:tree].merge(:project => @project))
    if @tree.save && update_configuration
      flash[:notice] = "Card tree was successfully created"
      if params[:navigate_to_aggregates] == "true"
        redirect_to edit_aggregate_properties_path(:id => @tree.id)
      else
        redirect_to card_tree_path(:tree_name => @tree.name, :tab => DisplayTabs::AllTab::NAME)
      end
    else
      set_rollback_only
      flash.now[:error] = @tree.errors.full_messages
      render :action => 'new'
    end
  end

  def edit
    @tree = TreeConfiguration.find(params[:id])
  end

  def edit_aggregate_properties
    @tree = TreeConfiguration.find(params[:id])
  end

  def update
    @tree = TreeConfiguration.find(params[:id])

    deletion_for_update = @tree.deletion_for_update(card_types_from_params)

    if deletion_for_update.blocked?
      set_rollback_only
      flash.now[:info] = render_to_string(:partial => 'update_blockings', :locals => {:deletion => deletion_for_update, :model => @tree})
      render :action => 'edit'
      return
    end

    @tree.after_attribute_change(:name) do |old_value, new_value|
      card_context.change_tree_config_name(old_value, new_value)
      @project.card_list_views.map { |view| view.change_tree_config_name(old_value, new_value) }
    end

    if params[:update_permanently].blank?
      @warnings = @tree.update_warnings(card_types_from_params)
      unless @warnings.blank?
        set_rollback_only
        @submit_update_permanently = true
        @tree.name = params[:tree][:name] if params[:tree]
        @tree.description = params[:tree][:description] if params[:tree]
        render :action => 'edit'
        return
      end
    end

    if @tree.update_attributes(params[:tree]) && update_configuration
      flash.now[:notice] = 'Card tree was successfully updated.'
      render :action => 'edit'
    else
      set_rollback_only
      flash.now[:error] = @tree.errors.full_messages
      render :action => 'edit'
    end
  end

  def confirm_delete
    @tree_config = TreeConfiguration.find(params[:id])

    @deletion = @tree_config.deletion
    if @deletion.blocked?
      render 'delete_blockings'
    end
  end

  def delete
    @tree_config = TreeConfiguration.find(params[:id])
    @tree_config.destroy
    flash[:notice] = "Card tree #{@tree_config.name.bold} has been deleted."
    redirect_to :action => 'index'
  end

  def show_add_aggregate_form
    @tree = @project.tree_configurations.find(params[:tree_configuration_id])
    aggregate_card_type = @project.card_types.find(params['aggregate_card_type'])
    child_type, descendant_types = child_and_descendant_types(@tree, aggregate_card_type)

    aggregates = AggregatePropertyDefinition.aggregate_properties(@project, @tree, aggregate_card_type)
    @aggregate_property_definition = AggregatePropertyDefinition.new(:tree_configuration => @tree, :aggregate_card_type => aggregate_card_type)
    render :update do |page|
      page.replace_html 'edit-aggregate-popup', :partial => "add_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
    end
  end

  def show_edit_aggregate_form
    @aggregate_property_definition = @project.aggregate_property_definitions_with_hidden.detect{|pd|pd.id == params[:id].to_i}
    tree = @aggregate_property_definition.tree_configuration
    aggregate_card_type = @aggregate_property_definition.aggregate_card_type
    child_type, descendant_types = child_and_descendant_types(tree, aggregate_card_type)

    aggregates = AggregatePropertyDefinition.aggregate_properties(@project, tree, aggregate_card_type)

    render :update do |page|
      page.replace_html 'edit-aggregate-popup', :partial => "edit_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
    end
  end

  def create_aggregate_property_definition
    add_has_condition_to_params!
    aggregate_def = @project.property_definitions_with_hidden.create_aggregate_property_definition(aggregate_attributes_from_params(params[:aggregate_property_definition]))

    aggregates = AggregatePropertyDefinition.aggregate_properties(@project, aggregate_def.tree_configuration, aggregate_def.aggregate_card_type)
    child_type, descendant_types = child_and_descendant_types(aggregate_def.tree_configuration, aggregate_def.aggregate_card_type)
     if aggregate_def.errors.empty?
       flash.now[:notice] = "Aggregate property #{aggregate_def.name.bold} was successfully created"
       @project.reload.update_card_schema
       aggregate_def.update_cards
       @aggregate_property_definition = AggregatePropertyDefinition.new(:tree_configuration => aggregate_def.tree_configuration,
                                                                        :aggregate_card_type => aggregate_def.aggregate_card_type)
       params[:aggregate_property_definition] = nil
     else
       set_rollback_only
       @aggregate_property_definition = aggregate_def
       @choose_name_text = ""
       flash.now[:error] = aggregate_def.errors.full_messages
     end

     render(:update) do |page|
       page.refresh_flash
       page.replace_html 'edit-aggregate-popup', :partial => "add_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
     end
  end

  def update_aggregate_property_definition
    add_has_condition_to_params!
    aggregate_def = @project.aggregate_property_definitions_with_hidden.detect{|pd|pd.id == params[:id].to_i}
    aggregate_def.attributes = aggregate_attributes_from_params(params[:aggregate_property_definition])
    child_type, descendant_types = child_and_descendant_types(aggregate_def.tree_configuration, aggregate_def.aggregate_card_type)

    if aggregate_def.errors.empty? && aggregate_def.save
      flash.now[:notice] = "Aggregate property #{aggregate_def.name.bold} updated successfully"
      aggregate_def.update_cards
      aggregates = AggregatePropertyDefinition.aggregate_properties(@project, aggregate_def.tree_configuration, aggregate_def.aggregate_card_type)
      @aggregate_property_definition = AggregatePropertyDefinition.new(:tree_configuration => aggregate_def.tree_configuration,
                                                                       :aggregate_card_type => aggregate_def.aggregate_card_type)
      params[:aggregate_property_definition] = nil
      render(:update) do |page|
        page.refresh_flash
        page.replace_html 'edit-aggregate-popup', :partial => "add_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
      end
    else
      set_rollback_only
      aggregates = AggregatePropertyDefinition.aggregate_properties(@project, aggregate_def.tree_configuration, aggregate_def.aggregate_card_type)
      @aggregate_property_definition = aggregate_def
      @choose_name_text = ""
      flash.now[:error] = @aggregate_property_definition.errors.full_messages
      render(:update) do |page|
        page.refresh_flash
        page.replace_html 'edit-aggregate-popup', :partial => "edit_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
      end
    end
  end

  def delete_aggregate_property_definition
    aggregate = @project.aggregate_property_definitions_with_hidden.detect{|pd|pd.id == params[:id].to_i}

    tree_configuration = aggregate.tree_configuration
    aggregate_card_type = aggregate.aggregate_card_type
    aggregates = AggregatePropertyDefinition.aggregate_properties(@project, tree_configuration, aggregate_card_type)
    @aggregate_property_definition = AggregatePropertyDefinition.new(:tree_configuration => tree_configuration, :aggregate_card_type => aggregate_card_type)
    child_type, descendant_types = child_and_descendant_types(tree_configuration, aggregate_card_type)
    deletion = aggregate.deletion

    if deletion.can_delete?
      aggregate.destroy
      aggregates.delete(aggregate)
      flash.now[:notice] = "Aggregate property #{aggregate.name.bold} deleted successfully."
      render(:update) do |page|
        page.refresh_flash
        page.replace_html 'edit-aggregate-popup', :partial => "add_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
      end
    else
      set_rollback_only
      flash.now[:info] = render_to_string :partial => deletion, :locals => { :display_effects => true }
      render(:update) do |page|
        page.refresh_flash
        page.replace_html 'edit-aggregate-popup', :partial => "add_aggregate_form", :locals => {:child_type => child_type, :descendant_types => descendant_types, :aggregates => aggregates}
        page.call "$('no-name-text').show"
      end
    end
  end

  def always_show_sidebar_actions_list
    ['list', 'new']
  end

  protected

  def wrap_in_transaction(&block)
    return super(&block) unless ['create', 'update', 'create_aggregate_property_definition'].include?(action_name)
    begin
      super(&block)
    rescue Exception
      ProjectCacheFacade.instance.clear_cache(@project.identifier)
      raise
    end
  end

  private

  def add_has_condition_to_params!
    params[:aggregate_property_definition][:has_condition] = params[:aggregate_property_definition][:aggregate_scope_card_type_id] == AggregateScope::DEFINE_CONDITION
  end

  def update_configuration
    @tree.update_card_types card_types_from_params
  end

  def aggregate_attributes_from_params(property_definition_params)
    attributes = property_definition_params.dup
    attributes[:aggregate_scope_card_type_id] = nil if attributes[:aggregate_scope_card_type_id] == AggregateScope::DEFINE_CONDITION
    attributes
  end

  def card_types_from_params
    return {} if params[:card_types].blank?
    params[:card_types].inject({}) do |result, card_type_details|
      card_type_position = card_type_details.first
      card_type_details_hash = card_type_details.last.dup
      card_type_name = card_type_details_hash.delete(:card_type_name)
      next result if card_type_name.blank?
      card_type = @project.card_types.find_by_name(card_type_name)
      result[card_type] = card_type_details_hash.merge(:position => card_type_position.to_i)
      result
    end
  end

  def child_and_descendant_types(tree, card_type)
    card_types_after = tree.card_types_after(card_type)
    child_type = card_types_after.first
    descendant_types = card_types_after
    [child_type, descendant_types]
  end

end
