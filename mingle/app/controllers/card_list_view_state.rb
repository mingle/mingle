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

module CardListViewState

  def cards_result_setup
    @view = CardListView.find_or_construct(@project, params)
    if @view.nil?
      respond_to do |format|
        format.html do
          report_view_missing_and_redirect_to_last_card_view(params[:view])
        end
        format.xml do
          render :nothing => true, :status => :not_found
        end
      end
    end

    @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id]) if params[:format] != 'xml'
  end

  def refresh_list_page(options={}, &block)
    except = options[:except] || []
    after = options[:after] || proc {}
    render :update do |page|
      yield(page) if block_given?
      page.refresh_flash unless except.include?(:flash)
      page.refresh_tabs unless except.include?(:tabs)
      unless except.include?(:results)
        page.refresh_no_cards_found
        page.refresh_result_partial(@view)
      end
      page['page-specific-top'].replace_html link_to_restore_screen_furniture(@view)
      page.replace 'action_panel', :partial => @view.style.action_panel_partial

      page.replace 'add_card_with_defaults', :inline => link_to_add_card_with_defaults("Add Card", { :id  => "add_card_with_defaults", :without_href => true }, @view.to_params.merge(:controller => 'cards')) if authorized?(:controller => :cards, :action => :create)
      page << update_params_for_js(@view)
      page << "$j('#show_export_options_link').replaceWith(#{export_to_excel_link(@view.all_cards_size).inspect})"
      page << "MingleUI.events.reset(#{@project.last_event_id})"
      after.call(page)
    end
  end

  def current_tab
    return DisplayTabs::AllTab.new(@project, card_context) if @view && !@view.name.blank? && !@view.tab_view?
    card_context.tab_for(params[:tab], @card)
  end
end
