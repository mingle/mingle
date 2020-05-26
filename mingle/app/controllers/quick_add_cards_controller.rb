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

class QuickAddCardsController < ProjectApplicationController
  include CardSupport, CardListSupport, QuickAddCardsHelper
  helper :cards, :trees, :lanes, :card_list_view_tab_name

  allow :get_access_for => [:add_card_popup]
  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["add_card_popup", "create_by_quick_add", "quick_add_with_details"]

  def create_by_quick_add
    @card = create_card_from_params
    if @card.errors.empty? && @card.save
      add_monitoring_event("create_by_quick_add", {'description_length' => @card.description_length })
      add_monitoring_event("create_card", {'project_name' => @project.name})
      add_card_successfully
    else
      set_rollback_only
      flash.now[:error] = @card.errors.full_messages
      lightbox_content = render_to_string(:partial => 'layouts/flash')
      render(:update) do |page|
        page << "$j('#add_card_popup .save-content').trigger('save:error', #{escape_and_format(@card.errors.full_messages.join("\n")).to_json});"
      end
    end
  end

  def quick_add_with_details
    @card = create_card_from_params
    params[:card].delete(:tree) # handle this later, for now just fix build
    add_another_card(params[:card], params[:properties])
  end

  def add_card_popup
    view = CardListView.find_or_construct(@project, params[:from_url].dup)
    quick_add_card = QuickAddCard.new(view, params.merge({:card_type_from_session => session[:quick_add_card_type], :use_filters => params[:use_filters]}))
    override_with_properties_from_drag_drop(quick_add_card)
    @card = quick_add_card.card
    save_quick_add_card_type_in_session(@card.card_type_name)
    if params[:card] && params[:card][:card_type_name]
      render(:update) do |page|
        page.replace("add-card-properties", render(:partial => "cards/add_card_properties", :locals => { :card => @card, :quick_add_card => quick_add_card }))
        page.replace('card-type-editor', render(:partial => 'cards/card_type_selector', :locals => { :card => @card }))
        page << "$j('#add_card_popup input[name=\"properties[Type]\"]').trigger('property_value_changed');"
        page << "$j('#add_card_popup .ckeditor-inline-editable').trigger('update_card_defaults', #{@card.formatted_content_editor(self).to_json});"
      end
    else
      lightbox_content = render_to_string(:partial => 'cards/card_lightbox_add', :locals => {:view => view, :quick_add_card => quick_add_card}  )
      render(:update) { |page| page.inputing_contexts.update(lightbox_content) }
    end
  end

  def current_tab
    if tab = (params[:from_url] && params[:from_url][:tab])
      {:name => tab, :type => CardListView.name}
    else
      DisplayTabs::AllTab.new(@project, card_context)
    end
  end

  def default_url_options(options = {})
    options.reverse_merge(:controller => 'cards')
  end

  private

  def add_card_successfully
    @view = CardListView.find_or_construct(@project, params[:from_url].dup)
    add_card_to_tree
    refresh_results
  end

  def refresh_results
    message = card_successly_created_message_with_included_in_view_check(@card, @view)
    from_url = params[:from_url]
    view_name = params[:from_url][:style] || 'elsewhere'
    if card_list_action?(from_url[:controller], from_url[:action])
      html_flash.now[:notice] = message
      @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])

      display_tree_setup if from_url[:tree_name]

      render :update do |page|
        page.inputing_contexts.pop
        page << mark_live_event_js(@card)
        page.refresh_flash
        page.refresh_no_cards_found
        page.replace 'show_export_options_link', :inline => export_to_excel_link(@view.all_cards_size)
        page.replace 'action_panel', :partial => @view.style.action_panel_partial
        page.refresh_result_partial(@view)
        page << update_params_for_js(@view) << "new Effect.SafeHighlight(#{@card.html_id.to_json});"
      end
    else
      render(:update) do |page|
        page.inputing_contexts.pop
        page << mark_live_event_js(@card)
        if card_creation_could_change_content?
          html_flash[:notice] = message
          page.redirect_to(from_url)
        else
          html_flash.now[:notice] = message
          page.refresh_flash
        end
      end
    end
  end

  def add_card_to_tree
    if tree_config = @project.tree_configurations.find_by_id(params[:tree_config_id])
      @card.editor_content_processing = false # don't double process the content, or else macros will be corrupted
      AddChildrenAction.new(@project, tree_config, params, card_context).execute(:root, [@card]) if tree_config.include_card_type?(@card.card_type) && !tree_config.include_card?(@card)
    end
  end

  def save_quick_add_card_type_in_session(card_type_name)
    session[:quick_add_card_type] = card_type_name
  end

  def override_with_properties_from_drag_drop(quick_add_card)
    quick_add_card.update_card_properties(params[:card_properties])
  end

end
