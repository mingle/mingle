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

class CardsImportController < ProjectApplicationController

  allow :get_access_for => [:repreview, :import, :display_preview]

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["accept", "display_preview", "preview", "import", "repreview"]

  def current_tab
    DisplayTabs::AllTab.new(@project)
  end

  def import
    @view = CardListView.find_or_construct(@project, params)
  end

  def accept
    tree_configuration_id = params[:tree_configuration_id].blank? ? nil : params[:tree_configuration_id]
    view = CardListView.find_or_construct(@project, params)
    mapping_overrides = params[:mapping].keys.collect(&:to_i).sort.collect { |key| params[:mapping][key.to_s] } if params[:mapping]

    publisher = CardImportPublisher.new(@project, User.current, params[:tab_separated_import_preview_id], params[:mapping], params[:ignore], tree_configuration_id)
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_message
    add_monitoring_event('import_cards')
    render_in_lightbox 'asynch_requests/progress', :locals => {:deliverable => @project}
  end

  def repreview
    @view = CardListView.find_or_construct(@project, params)
    @asynch_request = User.current.asynch_requests.find(params[:import_id])
    @preview_request_id = @asynch_request.message[:tab_separated_import_preview_id]
    @card_reader = @asynch_request.reconstruct_card_reader
    @mappings = @card_reader.headers.mappings.sort_by_index
    flash.now[:warning] = @card_reader.warnings unless @card_reader.warnings.empty?
    render :action => 'preview'
  end

  def preview
    @view = CardListView.find_or_construct(@project, params)

    import_file = SwapDir::CardImportingPreview.file(@project)
    import_file.write(params[:tab_separated_import].tr_s("\r", ""))
    publisher = CardImportPreviewPublisher.new(@project, User.current, import_file.pathname)
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg
    render_in_lightbox 'asynch_requests/progress', :locals => {:deliverable => @project}
  end

  def display_preview
    @view = CardListView.find_or_construct(@project, params)
    @asynch_request = AsynchRequest.find(params[:id])
    @preview_request_id = @asynch_request.id
    unless @asynch_request.completed?
      redirect_to @view.to_params.merge(:controller => 'asynch_requests', :action => 'progress', :id => @asynch_request.id)
      return
    end

    if @asynch_request.failed?
      set_rollback_only
      flash.now[:tab_separated_import] = @asynch_request.content
      flash.now[:error] = @asynch_request.error_details
      render :action => 'import'
    else
      @card_reader = CardImport::CardReader.new(@project, CardImport::ExcelContent.new(@asynch_request.content), @asynch_request.mapping)
      @mappings = @card_reader.headers.mappings.sort_by_index
      flash.now[:warning] = @card_reader.warnings if @card_reader.warnings.present?
      render :template => 'cards_import/preview'
    end
  end
end
