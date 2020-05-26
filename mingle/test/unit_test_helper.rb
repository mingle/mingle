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

require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/unit/mailbox_test_helper')

Messaging.disable
ElasticSearch.disable

module ActionController #:nodoc:
  module TestProcess
    # monkey patch follow_redirect to allow follow to string path in test
    def follow_redirect
      # monkey start
      if @response.redirected_to.is_a?(String) && @response.redirected_to =~ /(http:\/\/#{@request.host})*(.*)$/
        path, query_string = $2.split('?')
        @response.redirected_to = Routing::Routes.recognize_path(path.to_str, {:method => :get})
        @response.redirected_to.merge!(@request.class.parse_query_parameters(query_string))
      end
      # monkey end

      redirected_controller = @response.redirected_to[:controller]
      if redirected_controller && redirected_controller != @controller.controller_name
        raise "Can't follow redirects outside of current controller (from #{@controller.controller_name} to #{redirected_controller})"
      end

      get(@response.redirected_to.delete(:action), @response.redirected_to.stringify_keys)
    end

  end

  class TestResponse < Response
    def flash
      return {} unless session['flash']

      flash = ActionController::Flash::FlashHash.new
      flash.update(session['flash'][:flashes].with_indifferent_access)
      flash
    end

    def has_flash_object?(name=nil)
      !flash[name.to_s].nil?
    end

    def has_session_object?(name=nil)
      !session[name.to_s].nil?
    end
  end

  module Assertions
    module ResponseAssertions
      # monkey patch assert_redirect to allow assertion on redirect_to a string url
      def assert_redirected_to(options = {}, message=nil)
        redirected_to = @response.redirected_to.is_a?(Hash) ? @response.redirected_to.merge(@controller.default_url_options) : @response.redirected_to
        clean_backtrace do
          assert_response(:redirect, message)
          return true if options == redirected_to
          ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty?

          begin
            url  = {}
            original = { :expected => options, :actual => redirected_to.is_a?(Symbol) ? redirected_to : redirected_to.dup }
            original.each do |key, value|
              if value.is_a?(Symbol)
                value = @controller.respond_to?(value, true) ? @controller.send(value) : @controller.send("hash_for_#{value}_url")
              end

              unless value.is_a?(Hash)
                request = case value
                  when NilClass    then nil
                  when /^\w+:\/\// then recognized_request_for(%r{^(\w+://.*?(/|$|\?))(.*)$} =~ value ? $3 : nil)
                  else                  recognized_request_for(value)
                end
                value = request.path_parameters if request
              end

              if value.is_a?(Hash) # stringify 2 levels of hash keys
                if name = value.delete(:use_route)
                  route = ActionController::Routing::Routes.named_routes[name]
                  value.update(route.parameter_shell)
                end

                value.stringify_keys!
                value.values.select { |v| v.is_a?(Hash) }.collect { |v| v.stringify_keys! }
                if key == :expected && value['controller'] == @controller.controller_name && original[:actual].is_a?(Hash)
                  original[:actual].stringify_keys!
                  value.delete('controller') if original[:actual]['controller'].nil? || original[:actual]['controller'] == value['controller']
                end
              end

              if value.respond_to?(:[]) && value['controller']
                value['controller'] = value['controller'].to_s
                if key == :actual && value['controller'].first != '/' && !value['controller'].include?('/')
                  new_controller_path = ActionController::Routing.controller_relative_to(value['controller'], @controller.class.controller_path)
                  value['controller'] = new_controller_path if value['controller'] != new_controller_path && ActionController::Routing.possible_controllers.include?(new_controller_path)
                end
                value['controller'] = value['controller'][1..-1] if value['controller'].first == '/' # strip leading hash
              end
              url[key] = value
            end

            @response_diff = url[:actual].diff(url[:expected]) if url[:actual]
            msg = build_message(message, "expected a redirect to <?>, found one to <?>, a difference of <?> ", url[:expected], url[:actual], @response_diff)

            assert_block(msg) do
              url[:expected].keys.all? do |k|
                if k == :controller then url[:expected][k] == ActionController::Routing.controller_relative_to(url[:actual][k], @controller.class.controller_path)
                else parameterize(url[:expected][k]) == parameterize(url[:actual][k])
                end
              end
            end
          rescue ActionController::RoutingError # routing failed us, so match the strings only.
            msg = build_message(message, "expected a redirect to <?>, found one to <?>", options, @response.redirect_url)
            url_regexp = %r{^(\w+://.*?(/|$|\?))(.*)$}

            eurl, epath, url, path = [options, @response.redirect_url].collect do |url|
              # monkey start
              url = url_for(url) if url.is_a?(Hash)
              # monkey end
              u, p = (url_regexp =~ url) ? [$1, $3] : [nil, url]
              [u, (p.first == '/') ? p : '/' + p]
            end.flatten

            assert_equal(eurl, url, msg) if eurl && url
            assert_equal(epath, path, msg) if epath && path
          end
        end
      end
    end


    module MacroContentAssertionHelpers
      def assert_equal_ignoring_container_element(expected, actual, message = nil)
        dom = Nokogiri::HTML::DocumentFragment.parse(actual)
        macro_element = dom.css('.macro')
        macro_element.each do |macro|
          macro.replace macro.children
        end
        assert_equal_ignoring_spaces(expected, dom.text)
      end
    end
  end
end

module CachingTestHelper
  $incremental_seconds = 0

  def assert_key_changed_after(*models, &block)
    models.each(&:reload)
    ThreadLocalCache.clear!
    old_key = key(*models)

    at_time_after :hours => 1, :seconds => $incremental_seconds+=1 do
      yield
    end
    models.each(&:reload)
    assert_not_equal old_key, key(*models)
  end

  def assert_key_not_changed_after(*models, &block)
    models.each(&:reload)
    ThreadLocalCache.clear!
    old_key = key(*models)
    yield
    models.each(&:reload)
    assert_equal old_key, key(*models)
  end

  def assert_cache_path_changed_after(*models, &block)
    ThreadLocalCache.clear!
    original_path = self.send(:cache_path, *models)
    yield
    assert_not_equal original_path, self.send(:cache_path, *models)
  end

  def assert_cache_path_not_changed_after(*models, &block)
    ThreadLocalCache.clear!
    original_path = self.send(:cache_path, *models)
    yield
    assert_equal original_path, self.send(:cache_path, *models)
  end

  def assert_cache_path_has_changed_for_all_renderables(*projects, &block)
    ThreadLocalCache.clear!
    Caches::RenderableCache.assert_cache_path_has_changed_for_all_renderables(*projects) do
      Caches::RenderableWithMacrosCache.assert_cache_path_has_changed_for_all_renderables(*projects) do
        at_time_after :hours => 1, :seconds => $incremental_seconds+=1 do
          yield
        end
      end
    end
  end

  def assert_cache_path_changed_only_for_card_with_macro(project, &block)
    ThreadLocalCache.clear!
    card_without_macro = project.cards.create!(:name => 'card without macro', :card_type_name => 'card', :description => "no macro here")
    card_without_macro.update_attributes(name: 'a card without macro')

    card_with_macro = project.cards.create!(:name => 'card with macro', :card_type_name => 'card', :description => "{{ hello }}")
    card_with_macro.update_attributes(name: 'a card with macro')

    card_without_macro_version = card_without_macro.versions.first
    card_with_macro_version = card_with_macro.versions.first

    original_path_for_card_without_macro_version = cache_path(card_without_macro_version)
    original_path_for_card_with_macro_version = cache_path(card_with_macro_version)

    at_time_after :hours => 1, :seconds => $incremental_seconds+=1 do
      yield(card_without_macro, card_with_macro)
    end

    new_path_for_card_without_macro_version = cache_path(card_without_macro_version)
    new_path_for_card_with_macro_version = cache_path(card_with_macro_version)

    assert_equal original_path_for_card_without_macro_version, new_path_for_card_without_macro_version
    assert_not_equal original_path_for_card_with_macro_version, new_path_for_card_with_macro_version
  end
end

module Test
  module Caches
    module CachePathChangeAssertions
      def assert_cache_path_changed(renderables, &block)
        raise "You have no renderables in the projects passed in -- this assertion is meaningless." if renderables.empty?
        original_paths = renderables.collect { |renderable, project| project.with_active_project { |p| path_for(renderable) } }
        yield
        new_paths = renderables.collect do |renderable, project|
          project.with_active_project do |p|
           renderable.project.reload
           path_for(renderable)
          end
        end
        original_paths.each_with_index do |original_path, index|
          assert_not_equal original_path, new_paths[index]
        end
      end

      def renderables_with_projects(*projects)
        result = {}
        projects.each do |project|
          project.with_active_project do |p|
            (p.cards + p.card_versions + p.pages + p.page_versions).each { |r| result[r] = p }
          end
        end
        result
      end
    end

    module RenderableCache
      include Test::Unit::Assertions, Test::Caches::CachePathChangeAssertions

        def assert_cache_path_has_changed_for_all_renderables(*projects, &block)
          assert_cache_path_changed(renderables_with_projects(*projects), &block)
        end

    end

    module RenderableWithMacrosCache
      include Test::Unit::Assertions, Test::Caches::CachePathChangeAssertions

        def assert_cache_path_has_changed_for_all_renderables_with_macros(*projects, &block)
          renderables = renderables_with_projects(*projects)
          renderables.delete_if { |r, p| !r.has_macros }
          assert_cache_path_changed(renderables, &block)
        end
    end
  end
end

Caches::RenderableCache.send(:extend, Test::Caches::RenderableCache)
Caches::RenderableWithMacrosCache.send(:extend, Test::Caches::RenderableWithMacrosCache)

module CardImporterTestHelper

  def failed_import(import_content, options={})
    with_excel_content_file(import_content) do |raw_excel_content_file_path|
      import = create_card_importer!(Project.current, raw_excel_content_file_path, options[:mapping], options[:ignore] || [], options[:tree_configuration_id])
      import.import_cards
      assert import.error_details.size > 0
      import
    end
  end

  def import(import_content, options = {})
    with_excel_content_file(import_content) do |raw_excel_content_file_path|
      import = create_card_importer!(Project.current, raw_excel_content_file_path, options[:mapping], options[:ignore] || [], options[:tree_configuration_id])
      import.import_cards
      assert_equal [], import.error_details
      import
    end
  end

  def with_excel_content_file(content)
    raw_excel_content_file_path = write_content(content)
    yield(raw_excel_content_file_path)
  ensure
    if defined?(raw_excel_content_file_path) && File.exist?(raw_excel_content_file_path)
      FileUtils.rm_f(raw_excel_content_file_path)
    end
  end

  def write_content(import_content)
    mock_project = OpenStruct.new(:identifier => 'project_identifier')
    raw_excel_content_file = SwapDir::CardImportingPreview.file(mock_project)
    raw_excel_content_file.write(import_content)
    raw_excel_content_file.pathname
  end
end

module CardRankingTestHelper
  def project_card_names_sorted_by_ranking(project)
    project.cards.find(:all, :order => 'project_card_rank').collect(&:name)
  end
end

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true
  self.use_memcached_stub

  include Arts

  # Add more helper methods to be used by all tests here...

  %w( get post put delete head ).each do |method|
    class_eval <<-EOV, __FILE__, __LINE__
      def #{method}(action, parameters = nil, session = nil, flash = nil)
        @request.env['REQUEST_METHOD'] = "#{method.upcase}" if defined?(@request)
        if current_project
          parameters ||= {}
          parameters[:project] = current_project.identifier
        end
        process(action, parameters, session, flash)
      end
    EOV
  end

  def with_card_prop_def_test_project_and_card_type_and_pd(&block)
    with_card_prop_def_test_project do |project|
      login_as_member
      story_type = project.find_card_type('story')
      iteration_type = project.find_card_type('iteration')
      iteration_propdef = project.find_property_definition('iteration')
      yield(project, story_type, iteration_type, iteration_propdef)
    end
  end

  def create_next_version_at(versioned, year, month, day, hour, minute, second)
    versioned.update_attribute(:name, versioned.name.next)
    versioned.reload
    set_modified_time(versioned, versioned.versions.size, year, month, day, hour, minute, second)
  end

  def assert_shows_version(history, *versions)
    shown_versions = history.events.collect { |e| e.version if e.respond_to?(:version) }.compact
    versions.each do |version|
      assert shown_versions.include?(version), "Unexpected: version #{version} does not show in history which shows #{shown_versions}"
    end
  end

  def assert_does_not_show_versions(history, *versions)
    shown_versions = history.events.collect { |e| e.version if e.respond_to?(:version) }.compact
    versions.each do |version|
      assert !shown_versions.include?(version), "Unexpected: version #{version} shows in history which shows #{shown_versions}"
    end
  end

  def assert_raise_with_message(expected_exception, expected_message)
    begin
      error_raised = false
      yield
    rescue expected_exception => error
      error_raised = true
      actual_message = error.message
    end
    assert error_raised
    assert_equal expected_message, actual_message
  end


  def increase_user_numbers_to(number)
    (number-User.all.size).times { create_user! }
  end

  def using_controller(controller_class, &block)
    old_controller = @controller
    @controller = create_controller controller_class
    yield
    @controller = old_controller
  end

  module FunctionalTestAssertions
    def assert_error(error_message=nil)
      if error_message.nil?
        assert_select "div#error"
      else
        assert_select "div#error",{:html => error_message}
      end
    end

    def assert_notice(notice_message=nil)
      if notice_message.nil?
        assert_select 'div#notice', true, 'No notice message found'
      else
        assert_select 'div#notice', {:html => notice_message}
      end
    end

    def assert_info(info_message=nil)
      if info_message.nil?
        assert_select 'div#info', true, 'No info message found'
      else
        assert_select 'div#info', {:html => info_message}
      end
    end

    def assert_warning(message=nil)
      if message.nil?
        assert_select 'div#warning', true, 'No warning message found'
      else
        assert_select 'div#warning', {:html => message}
      end
    end

    def assert_no_error(error_message=nil)
      if error_message.nil?
        assert_no_tag 'p', :attributes => {:id => 'error'}
      else
        assert_no_tag 'p', :attributes => {:id => 'error'}, :content => error_message
      end
    end

    def assert_no_error_in_ajax_response
      assert(!(@response.body =~ /id=\\"error\\"\\u003E(.+?)\\u003C\/div/ ), "reponse has error message: #{$1}")
    end

    def assert_no_notice(notice_message=nil)
      if notice_message.nil?
        assert_no_tag 'p', :attributes => {:id => 'notice'}
      else
        assert_no_tag 'p', :attributes => {:id => 'notice'}, :content => notice_message
      end
    end

    def assert_selected_project_admin_menu(menu_name)
      assert_select '#admin-nav li[class=current-selection] a', :text => menu_name
    end

    def assert_rollback
      assert Thread.current['rollback_only']
    end

    def assert_selected_value(expected_value, select_tag_selector)
      assert_select "#{select_tag_selector} option[selected=selected]", :text => (expected_value.is_a?(Regexp) ? expected_value : expected_value.to_s)
    end

    def assert_tab_visible(tab_selector)
      assert_select "#{tab_selector}" do |elements|
        assert_nil elements.first.attributes['style'], "The #{tab_selector} tab should be visible"
      end
    end

    def assert_tab_invisible(tab_selector)
      assert_select "#{tab_selector}" do |elements|
        assert elements.first.attributes['style'], "The #{tab_selector} tab should be invisible"
      end
    end

    def assert_disabled(selector, options={})
      assert_select "#{selector}[disabled=disabled]", options
    end

    def assert_checked(selector, options={})
      assert_select "#{selector}[checked=checked]", options
    end
  end

  include FunctionalTestAssertions

  module FunctionalTestHelperMethods
    def create_controller(controller_class, options = {})
      options.reverse_merge!(:skip_project_caching => true)
      controller_class.skip_filter(ApplicationController::TransactionFilter)
      controller_instance = controller_class.new
      if options[:skip_project_caching]
        def controller_instance.update_project_cache
          if @project
            ProjectCacheFacade.instance.clear_cache(@project.identifier)
          end
        end
      end
      unless options[:own_rescue_action]
        def controller_instance.rescue_action(e) raise e end;
      end
      if controller_instance.respond_to?(:set_events_tracker)
        controller_instance.set_events_tracker(EventsTrackerStub.new)
      end
      controller_instance
    end

    # Arts calls prototype_helper, which uses this method in Rails 2.3, but Arts has not yet been updated for Rails 2.3.
    def with_output_buffer(buf = '', &block)
      yield
    end
  end

  include FunctionalTestHelperMethods

  module DebugOutputHelper
    def show_me_response
      show_me_html(@response.body)
    end

    def show_me_html(html)
      File.open('/tmp/response_body.html', 'w') { |file| file << html }
      `open /tmp/response_body.html`
    end
  end

  include DebugOutputHelper

  module MacroRegistration
    def with_built_in_macro_registered(name, macro)
      original_macro = Macro.get(name)
      Macro.register(name, macro)
      yield
    ensure
      Macro.unregister(name)
      Macro.register(name, original_macro) if original_macro
    end

    def with_custom_macro_registered(name, macro)
      MinglePlugins::Macros.register(macro, name)
      yield
    ensure
      MinglePlugins::Macros.unregister(name)
    end
  end
  include MacroRegistration
end

# this makes oracle not commit every changes when implicit commit happens
module OracleTransactionalCardSchema
  def self.included(base)
    base.class_eval do
      [:remove_column, :add_column, :update].each do |implicit_commit_action|
        safe_alias_method_chain implicit_commit_action, :create_new_transaction
      end
    end
  end

  def remove_column_with_create_new_transaction(*args)
    remove_column_without_create_new_transaction(*args).tap { create_new_transaction }
  end

  def add_column_with_create_new_transaction(*args)
    add_column_without_create_new_transaction(*args).tap { create_new_transaction }
  end

  def update_with_create_new_transaction(*args)
    update_without_create_new_transaction(*args).tap { create_new_transaction }
  end

  def create_new_transaction
    unless ActiveRecord::Base.connection.open_transactions.zero?
      ActiveRecord::Base.connection.commit_db_transaction
      ActiveRecord::Base.connection.begin_db_transaction
    end
  end
end
CardSchema.class_eval { include OracleTransactionalCardSchema } if ActiveSupport::TestCase.oracle?

module FreezePreloadedProjects
  def self.included(base)
    base.class_eval do
      [:remove_column, :add_column, :update].each do |implicit_commit_action|
        safe_alias_method_chain implicit_commit_action, :check_structure_change
      end
    end
  end

  def remove_column_with_check_structure_change(*args)
    check_structure_change
    remove_column_without_check_structure_change(*args)
  end

  def add_column_with_check_structure_change(*args)
    check_structure_change
    add_column_without_check_structure_change(*args)
  end

  def update_with_check_structure_change(*args)
    check_structure_change
    update_without_check_structure_change(*args)
  end

  def check_structure_change
    raise("Sorry, #{@project.identifier} is a preloaded project, you cannot change the structure of it!") if UnitTestDataLoader.preloaded_project?(@project)
  end
end
CardSchema.class_eval { include FreezePreloadedProjects }

module HistoryMailerTestHellper
  include HistoryHelper

  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  include ActionMailer::Quoting

  def setup_mailer_project
    @old_mingle_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'
    SmtpConfiguration.load
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    @expected.mime_version = '1.0'
    @member = User.find_by_login('member')
    @project = create_project(:users =>[@member])
    setup_property_definitions :old_type => ['card'], :status => ['done','open']
    setup_user_definition 'my_developer'
    @filter_params = history_filter_query_string({'involved_filter_properties' => {"old_type" => "card"},
                    'acquired_filter_properties'  =>  {"status" => "done"},
                    'involved_filter_tags' => ["apple"],
                    'acquired_filter_tags' => ["orange"],
                    'filter_user' => "#{@member.id}"
                    })

    @project.activate
    SubversionConfiguration.create!(:project => @project, :repository_path => "/") #project must have a repos configured to locate revision events in history
    login_as_member
    @subscription = HistorySubscription.create(:user => @member, :project_id => @project.id, :filter_params => @filter_params,
      :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
  end

  def teardown_mailer_project
    MingleConfiguration.site_url = @old_mingle_site_url
  end

  private
  def assert_email_contains_unsubscribe_link(content)
    assert_email_contains_url("http://test.host/projects/#{@project.identifier}/history/unsubscribe/#{@subscription.id}", content)
  end

  def assert_email_contains_manage_subscription_link(content)
    assert_email_contains_url("http://test.host/profile/show/#{@subscription.user.id}?tab=subscriptions", content)
  end

  def assert_email_contains_card_link(card_version, content)
    assert_email_contains_url("http://test.host/projects/#{@project.identifier}/cards/#{card_version.number}", content)
  end

  def assert_email_contains_page_link(page_version, content)
    assert_email_contains_url("http://test.host/projects/#{@project.identifier}/wiki/#{page_version.identifier}", content)
  end

  def assert_email_contains_url(url, content)
    assert content.include?(url), "Mail did not contain url <#{url}>: #{content.inspect}"
  end

  def read_fixture(action)
    IO.readlines("#{FIXTURES_PATH}/history_mailer/#{action}")
  end

  def encode(subject)
    quoted_printable(subject, CHARSET)
  end

end


module ProcessWithCleanProjectActivation
  def self.included(base)
    base.alias_method_chain :process, :clean_project_activation
  end

  def process_with_clean_project_activation(action, parameters = nil, session = nil, flash = nil, http_method = 'GET')
    activated_project = Project.current_or_nil
    process_without_clean_project_activation(action, parameters, session, flash, http_method).tap do |r|
      activated_project.activate if activated_project
    end
  end
end

def retry_until_condition(times, wait_time, &block)
  return unless block_given?
  i = 0
  until (block.call || i > times) do
    sleep(wait_time)
    i = i.next
  end
  raise 'Condition not met' if(i > times)
end

ActionController::TestCase.send(:include, ProcessWithCleanProjectActivation)

require 'mocha'

def start_webrick_server(port, &block)
  server = WEBrick::HTTPServer.new(:Port => port, :Logger => WEBrick::Log.new("/dev/null"), :AccessLog => [])

  server.mount_proc '/repos', &block
  Thread.start do
    server.start
  end
  server
end
