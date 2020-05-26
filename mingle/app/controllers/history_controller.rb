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

class HistoryController < ProjectApplicationController
  skip_before_filter :authenticated?, :only => :feed
  skip_before_filter :require_project_membership_or_admin, :only => :feed

  allow :get_access_for => [:feed, :plain_feed, :index, :unsubscribe]

  privileges UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => ['subscribe']

  def current_tab
    DisplayTabs::HistoryTab.new(@project)
  end

  def feed
    begin
      process_feed(@project.decrypt(params[:encrypted_history_spec]))
    rescue Exception => exception
      Rails.logger.error(exception)
      handle_invalid_feed
    end
  end

  def plain_feed
    process_feed(params)
  end

  def history_atom_limit
    25
  end

  def index
    @period = (params[:period] || :today).to_sym
    @period = :today unless History::NAMED_PERIODS.include?(@period)
    @title = "#{@project.name} Activity #{@period.to_s.humanize}"
    @page = params[:page]
    @filter_user_id = history_filter_params.filter_user
    card_context.store_tab_params(params, current_tab[:name], CardContext::NO_TREE)
    @history = History.new(@project, history_filter, {:page => @page, :paged_results => true})
    link_to_this_page = "<%= link_to('<i class=\"fa fa-link\"></i> Update URL'.html_safe, url_for_current_history_page, :style => 'float:right') %>"
    help_link = %Q{<%= render "shared/contextual_help_or_normal_help_link", :contextual_help_class => 'page-help-at-action-bar', :position => "top", :help_link => render_help_link("History Tab", :class => 'page-help-at-action-bar', :style => "line-height:1.8em;margin-left:10px;margin-top:-0.3em;padding:0 0 0 20px;") %>}
    flash.now[:info] = if @history.empty?
      render_to_string(:inline => "#{help_link} #{link_to_this_page}There are no events in the current period that match the current filter. <%= link_to 'Reset filter', { :action => 'index' } %>")
    else
      render_to_string(:inline => (help_link + link_to_this_page + @history.describe_current_page))
    end
    @request_params = history_filter_params.to_hash
    respond_to do |format|
      format.html { }
      format.js do
        involved_filter_tags = history_filter_params.involved_filter_tags
        acquired_filter_tags = history_filter_params.acquired_filter_tags
        history = @history
        render(:update) do |page|
          page['history-results'].replace_html :partial => 'shared/events',
            :locals => {:history => history, :show_initially => true,
                        :include_object_name => true, :include_version_links => true, :page => @page, :project => @project, :popup => false }
          page['periods'].replace :partial => 'periods'
          page['feed'].replace_html :partial => 'feed', :locals => {:request_params => @request_params}
          page.refresh_flash
          page['page_links'].replace :partial => 'shared/page_links', :locals => {:paged_object => history}
          page['involved_filter_widget'].replace :partial => 'shared/filter_widget', :locals => {:filters => params[:involved_filter_properties] || {}, :field_name => 'involved_filter_properties', :html_id => 'involved_filter_widget', :onchange => "$('filter_form').onsubmit()"}
          page['acquired_filter_widget'].replace :partial => 'shared/filter_widget', :locals => {:filters => params[:acquired_filter_properties] || {}, :field_name => 'acquired_filter_properties', :html_id_prefix => 'acquired', :html_id => 'acquired_filter_widget', :onchange => "$('filter_form').onsubmit()"}
        end
      end
    end
  end

  def subscribe
    begin
      raise unless smtp.configured?
      @request_params = history_filter_params(params[:filter_params]).to_hash
      unless User.current.has_subscribed_history?(@project, @request_params)
        add_monitoring_event(:card_or_history_subscription_created, 'project_name' => @project.name)
        subscription = @project.create_history_subscription(User.current, @request_params)
        HistoryMailer.deliver_subscribe(subscription)
      end
    rescue Exception => e
      set_rollback_only
      flash.now[:smtp_error] = 'This feature is not configured. Contact your Mingle administrator for details.'
    end

    if request.xhr?
      render(:update) do |page|
        page.replace('feed', :partial => 'feed', :locals => {:request_params => @request_params})
      end
    else
      render :text => "You have subscribed to this via email."
    end
  end

  # I had to allow this GET action to modify state as a fix for bug #10294.
  # This link is sent in an email so need to allow get to work.
  # We may play a story to add a confirm unsubsubscribe screen which would allow
  # us to make this action post
  def unsubscribe
    unsubscribe_subscription
  end

  # This one is the post action
  def delete
    unsubscribe_subscription
  end

  private

  def unsubscribe_subscription
    history_subscription = @project.history_subscriptions.find_by_id_and_user_id(params[:id].to_i, params[:user_id] || User.current.id)
    if history_subscription
      history_subscription.destroy
      flash[:notice] = render_to_string(:inline => "You have successfully unsubscribed from #{link_history_subscription_description(history_subscription.description.escape_html)}.")
      respond_to do |format|
        format.html { redirect_to :action => 'index' }
        format.js do
          render :update do |page|
            page.remove dom_id(history_subscription)
            page.refresh_flash
            page.subscriptions_counter.no_subscriptions_check
          end
        end
      end
    else
      set_rollback_only
      flash[:error] = "The Mingle history notification from which you are trying to unsubscribe is no longer valid or no longer exists."
      respond_to do |format|
        format.html { redirect_to :controller => 'projects', :action => 'show', :project_id => @project.identifier }
        format.js do
          render :update do |page|
            page.refresh_flash
          end
        end
      end
    end
  end

  def smtp
    SmtpConfiguration
  end

  def link_history_subscription_description(description)
    description =~ /#(\d+)/
    card_number = $1
    description.gsub /#(\d+)/, "<%= link_to '##{card_number}', card_show_url(:number => #{card_number}) %>"
  end

  def history_filter(filter_params=params)
    history_filter_params(filter_params).generate_history_filter(@project)
  end

  def history_filter_params(filter_params=params)
    HistoryFilterParams.new(filter_params, @period)
  end

  def handle_invalid_feed
    set_rollback_only
    flash[:error] = "The feed URL is no longer valid."
    redirect_to :controller => 'projects', :action => 'show', :project_id => @project.identifier
  end

  # require 'profile'
  def process_feed(history_spec)
    # profile do
      @period = :all_history
      respond_to do |format|
        format.atom do
          @history = if history_filter_params(history_spec).global?
            History.new(@project, history_filter(history_spec), {:paged_results => true, :page => 1, :page_size => history_atom_limit})
          else
            history_filter_params(history_spec).generate_history_filter(@project)
          end
          render :template => "history/index.atom.rxml", :layout => false
        end
      end
    # end
  end

end
