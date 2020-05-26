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

module AutoTransition
  class View
    module Errors
      NO_TRANSITION_ON_PROPERTY_VALUE_ERROR = "Sorry, you cannot drag this card to lane %s. Please ensure there is a transition to allow this action and this card satisfies the requirements."

      def self.no_transition_on_property_value(lane_title)
        NO_TRANSITION_ON_PROPERTY_VALUE_ERROR % lane_title.bold
      end
    end

    def initialize(controller, card, property_value)
      @controller = controller
      @project = @controller.project
      @view = CardListView.find_or_construct(@project, params)
      @card = card
      @property_value = property_value
    end

    def card_error
      flash.now[:error] = @card.errors.full_messages
      render(:update) do |page|
        page.refresh_flash
        page << "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"force-revert\", true).trigger(\"grid:transition\");"
        page << "SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{@card.number}, false);"
      end
    end

    def multi_transitions_matched(transitions)
      prepend_script = "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"defer-to-lightbox\", true);"
      render_in_lightbox 'select_transition_to_automate', :lightbox_opts => {:prepend_script => prepend_script}, :locals => {:transitions => transitions, :card => @card, :view => @view, :on_cancel => "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"force-revert\", true).trigger(\"grid:transition\"); SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{@card.number}, false);"}
    end

    def no_transition_matched
      flash.now[:error] = Errors.no_transition_on_property_value(@property_value.display_value)
      render(:update) do |page|
        page.refresh_flash
        page << "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"force-revert\", true).trigger(\"grid:transition\");"
        page << "SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{@card.number}, false);"
      end
    end

    def update_successfully(old_lanes, old_rows)
      @card.rerank(params[:rerank])
      @view = CardListView.find_or_construct(@project, params)
      cards = @view.cards
      card = @card
      view = @view
      filtered_out_message = filter_excluding_card_message
      context = card_context
      add_monitoring_event('card_action', {'action' => 'card_moved_on_grid'})
      render(:update) do |page|
        if (cards.include?(card))
          page << "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).trigger(\"grid:transition\");"
          page << "SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{card.number}, true);"
          page["card_inner_wrapper_#{card.number}"].replace :partial => 'card_inner_wrapper', :locals => {:card => card, :view => view}
          page["card_assigned_users_#{card.number}"].replace :partial => 'card_assigned_users', :locals => {:card => card, :view => view}
          page << %Q{
            $j(".card-icon[data-card-number='#{card.number}']").
              mingleTeamList("Assignable").
              iconDroppable({
                accept: ".avatar",
                slotContainer: ".avatars",
                deletionTray: $j("#deletion-tray")
              });
          }
        else
          flash.now[:info] = filtered_out_message
          page << "MingleUI.grid.instance && MingleUI.grid.instance.removeCard(#{card.number});"
          page << "SwimmingPool.instance && SwimmingPool.instance.destroyCard(#{card.number});"
        end
        page.refresh_flash
        page["cta_frame_wrapper"].replace :partial => 'cta_frame', :locals => {:view => view}
        page["set_wip_limit_form"].replace :partial => 'cards/wip_limit_form', :locals => {:view => view}
        page.wip_police.enforce
        page << mark_live_event_js(card)
      end
    end

    def filter_excluding_card_message
      "card #{card_number_link(@card)} property was updated, but is not shown because it does not match the current filter.".html_safe
    end

    def transition_applied(transition_name)
      html_flash.now[:notice] = "#{transition_name.escape_html.bold} successfully applied to card #{card_number_link(@card)}"
      @card.rerank(params[:rerank])
      cards_result_setup
      display_tree_setup
      cards = @view.cards
      unless (cards.include?(@card))
        html_flash.now[:info] = filter_excluding_card_message
      end
      refresh_list_page(:except => [:tabs])
    end

    def execution_error(transition_name, errors)
      html_flash.now[:error] = "#{transition_name.escape_html.bold} could not be applied to card #{card_number_link(@card)} because: #{errors.full_messages.join.escape_html}"
      render(:update) do |page|
        page.refresh_flash
        page << "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"force-revert\", true).trigger(\"grid:transition\");"
        page << "SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{@card.number}, false);"
      end
    end

    def require_user_input(transition)
      prepend_script = "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"defer-to-lightbox\", true);"
      render_transition_popup(:partial => 'auto_transition_popup', :lightbox_opts => {:prepend_script => prepend_script}, :transition => transition, :card => @card, :view => @view, :on_cancel => "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).data(\"force-revert\", true).trigger(\"grid:transition\"); SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{@card.number}, false);", :project => @card.project)
    end

    def non_property_change
      render :update do |page|
        @view = CardListView.find_or_construct(@project, params)

        page.refresh_flash
        page["card_inner_wrapper_#{@card.number}"].replace :partial => "card_inner_wrapper", :locals => {:card => @card, :view => @view}

        page << "MingleUI.grid.instance && MingleUI.grid.instance.cardByNumber(#{@card.number}).trigger(\"grid:transition\");"
        page << "SwimmingPool.instance && SwimmingPool.instance.afterCardUpdated(#{@card.number}, true);"
        page << mark_live_event_js(@card)
      end
    end

    def method_missing(method, *args, &block)
      @controller.send(method, *args, &block)
    end
  end
end
