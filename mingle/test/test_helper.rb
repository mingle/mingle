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


java.util.logging.LogManager.getLogManager().reset();

ENV["RAILS_ENV"] = "test"
if defined? Rails
  ::RAILS_ENV = "test"
  Rails.instance_variable_set(:@_env, nil)
end

puts "*********Running test in RUBY_VERSION: #{RUBY_VERSION}***********"

if defined? $TEST_HELPER_LOADED
  puts "test_helper was loaded by: "
  puts '--------------------- 1 -------------------------'
  puts $TEST_HELPER_LOADED.join("\n")
  puts '--------------------- 2 -------------------------'
  puts caller.join("\n")
  puts '--------------------- 3 -------------------------'
  raise 'some how you load your test helper twice, this potentially can causing problems, please revise your require statement'
else
  $TEST_HELPER_LOADED = caller
end
$LOAD_PATH.unshift(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + "/../lib/build/process_ids")
Mingle::ProcessIds.register('mingle_test')

require File.expand_path(File.dirname(__FILE__) + "/../config/environment.rb") unless defined?(RAILS_GEM_VERSION)
require 'test_help'
require 'tlb_patches'
require File.expand_path(File.dirname(__FILE__) + "/paralleled_test_database")
require File.expand_path(File.dirname(__FILE__) + "/drivers/repository_driver")
require File.expand_path(File.dirname(__FILE__) + "/drivers/repository_hg_driver")
require File.expand_path(File.dirname(__FILE__) + "/drivers/renderable_tester")
require File.expand_path(File.dirname(__FILE__) + '/xml_builder_test_helper')
require File.expand_path(File.dirname(__FILE__) + "/unit/unit_test_data_loader")
require File.expand_path(File.dirname(__FILE__) + "/unit/tree_fixtures")
require 'memcache_stub'
require 'racc_version_check'
require 'macro/builder'
require 'test_helpers/planner_test_helper'
require 'test_helpers/cruise_dashboard_helper'
require 'setup_and_teardown'
require 'test_unit/with_timings'
require 'test_unit/pending_tests'
require 'test_unit/test_suite_runner'
require 'webmock/test_unit'
require 'stubs/slack_client_stubs'
require 'dual_app_server'

WebMock.allow_net_connect!

require File.expand_path(File.dirname(__FILE__) + "/unit/swap_dir_test_helper")

Dir[File.expand_path(File.dirname(__FILE__) + "/stubs/*.rb")].each do |f|
  require f
end

Renderable.disable_caching

unless Rails.env.acceptance_test?
  MingleConfiguration.load_config(File.join(Rails.root, 'config', 'mingle.properties'))
end
MingleConfiguration.site_url = "http://#{Socket.gethostname}:4001" if MingleConfiguration.site_url.blank?
MingleConfiguration.secure_site_url = "https://#{Socket.gethostname}:8443" if MingleConfiguration.secure_site_url.blank?
MingleConfiguration.no_cleanup = true

#load configuration here, so that the setting wouldn``'t be overwritten when you setup one global variable but the test reload the configuration because of missing another setting.
AuthConfiguration.load

ActionView::Base.debug_rjs = false

License.class_eval do
  class << self
    def reconnect
    end
  end
end

ElasticSearch
class ElasticSearch
  class << self
    def refresh_indexes
      ElasticSearch.request :post, "/_refresh"
    end

    def clear_cache
      ElasticSearch.request :post, "/_cache/clear"
    end

    def delete_index(index_key=index_name)
      ElasticSearch.request(:delete, "/#{index_key}") unless index_missing?(index_key) # either this, or catch and unwrap exception
    end
  end
end

module ModelTestHelper

  def create_program_exporter!(program, user)
    message = ProgramExportPublisher.new(program, user).publish_message
    ProgramExporter.fromActiveMQMessage(message)
  end

  def create_dependencies_exporter!(projects, user)
    message = DependenciesExportPublisher.new(projects, user).publish_message
    DependenciesExporter.fromActiveMQMessage(message)
  end

  def create_dependencies_importer!(user, export_file)
    preview = create_dependencies_importing_preview!(user, uploaded_file(export_file))
    preview.process!
    message = DependenciesImportPublisher.new(user, preview.progress.reload.id).publish_message
    DependenciesImporter.fromActiveMQMessage(message)
  end

  def create_dependencies_importing_preview!(user, export_file)
    message = DependenciesImportPreviewPublisher.new(user, export_file).publish_message
    DependenciesImportingPreview.fromActiveMQMessage(message)
  end

  def dependencies_export_file(name)
    File.join(Rails.root, "test", "data", "dependencies_exports", name)
  end

  def create_project_exporter!(project, user, project_export_params = {})
    updated_project_export_params = {:template => false}.merge(project_export_params)
    project_export_message = ProjectExportPublisher.new(project, user, updated_project_export_params[:template]).publish_message
    DeliverableImportExport::ProjectExporter.fromActiveMQMessage(project_export_message)
  end

  def create_project_importer!(*args)
    UnitTestDataLoader.create_project_importer!(*args)
  end

  def icon_file_path(file_name)
    File.join(Rails.root, 'test', 'data', 'icons', file_name)
  end

  def with_asset_host(host, &block)
    original_asset_host = ActionController::Base.asset_host
    ActionController::Base.asset_host = host
    MingleConfiguration.with_asset_host_overridden_to(host, &block)
  ensure
    ActionController::Base.asset_host = original_asset_host
  end

  def create_template(options = {})
    return User.with_current(User.find_by_login('admin')) do
      project_name = unique_project_name(options[:prefix])
      Project.create! :template => true, :name => project_name, :identifier => options[:identifier] || project_name.downcase.gsub(/[^a-z0-9_]/, '_'), :corruption_checked => true
    end
  end

  def with_first_admin(&block)
    User.first_admin.with_current(&block)
  end

  def create_project(options = {})
    with_first_admin do
      options = HashWithIndifferentAccess.new(options)
      options[:name] ||= unique_project_name(options[:prefix])
      optional_project_params = { :identifier => options[:name].downcase.gsub(/[^a-z0-9_]/, '_'), :corruption_checked => true }
      project_params = options.slice(*Project.column_names).reverse_merge(optional_project_params)
      project = Project.create!(project_params).with_active_project do |p|
        for_oracle do
          @@warning_displayed ||= "Adding card table for new project. Committing the changes in transaction so far!!!".tap { |message| Rails.logger.info(message) }
        end
        Array(options[:users]).each do |user|
          p.add_member(user)
        end
        Array(options[:admins]).each do |proj_admin|
          p.add_member(proj_admin, :project_admin)
        end
        Array(options[:read_only_users]).each do |read_only_user|
          p.add_member(read_only_user, :readonly_member)
        end

        configure_subversion_for(p, :repository_path => options[:repository_path]) if options[:repository_path]
        p.save!
        p
      end

      project.activate unless options[:skip_activation]
      if block_given?
        project.with_active_project do |p|
          yield p
        end
      end
      project
    end
  end

  def autoenroll_all_users(auto_enroll_user_type='full', project=@project, &block)
    original_members = project.users.to_a
    project.update_attribute(:auto_enroll_user_type, auto_enroll_user_type)
    yield original_members, (project.users.to_a - original_members) if block_given?
  end

  def turn_off_autoenroll(project=@project, &block)
    autoenroll_all_users(nil, project, &block)
  end

end

class FakeViewHelper
  include ActionView::Helpers
  include ApplicationHelper
  include FileColumnHelper
  extend ActionView::Helpers::ClassMethods


  def initialize
    @url_writer_class = Class.new
    @url_writer_class.send(:include, ActionController::UrlWriter)
    @controller = @url_writer_class.new
  end

  def default_url_options=(opts)
    @url_writer_class.default_url_options = opts
  end

  def default_url_options
    @url_writer_class.default_url_options
  end

  def url_for(options)
    options = {:controller => 'controller', :action => 'action'}.merge(options) if options.is_a?(Hash)
    super(options)
  end

  def chart_image_url(options)
    "http://test.host/project_without_cards/wiki/Dashboard/chart/#{options[:position]}/#{options[:type]}.png"
  end

  def content_tag(*args, &block)
    content_tag_without_user_access(*args, &block)
  end

  def image_tag(url)
    "<img src=\"#{url}\" alt=\"Dummy\" />"
  end

  def auto_link(text, *args)
    text
  end
  alias :original_auto_link :auto_link

  def prepend_protocol_with_host_and_port(url)
    return url if url =~ /^https?:\/\//
    "http://test.host#{url}"
  end

  def truncate(text, *args)
    options = args.extract_options!
    unless args.empty?
      ActiveSupport::Deprecation.warn('truncate takes an option hash instead of separate ' +
        'length and omission arguments', caller)

      options[:length] = args[0] || 30
      options[:omission] = args[1] || "..."
    end
    options.reverse_merge!(:length => 30, :omission => "...")

    if text
      l = options[:length] - options[:omission].mb_chars.length
      chars = text.mb_chars
      (chars.length > options[:length] ? chars[0...l] + options[:omission] : text).to_s
    end
  end

  def controller_name
    'projects'
  end
end

if Gem::Version.new(Timecop::VERSION) < Gem::Version.new("0.8.0")
  # backport this useful nugget
  def Timecop.frozen?
    !instance.instance_variable_get(:@_stack).empty?
  end
end

Event
class Event < ActiveRecord::Base
  after_save :use_mocked_timestamp

  def self.set_event_timestamp(event, time)
    connection.execute(SqlHelper.sanitize_sql("UPDATE #{Event.quoted_table_name} SET mingle_timestamp = ? where id = ?", time, event.id))
  end

  def use_mocked_timestamp
    Event.set_event_timestamp(self, Time.now) if Timecop.frozen?
  end
end


class ActiveSupport::TestCase
  include ::SwapDirTestHelper, SqlHelper, ModelTestHelper, SetupHelper, ::XMLBuilderTestHelper, PlannerTestHelper
  include SetupAndTeardown

  self.use_instantiated_fixtures  = false

  attr_reader :current_project

  class Finder
    def initialize(project)
      @project = project
    end

    def card(card_name)
      @project.cards.find_by_name(card_name)
    end

    def pd(prop_def_name)
      @project.find_property_definition(prop_def_name)
    end

    def type(card_type_name)
      @project.find_card_type(card_type_name)
    end
  end

  def self.use_memcached_stub
    MemcacheStub.load
  end

  def with_page_size(number, &block)
    old_value = PAGINATION_PER_PAGE_SIZE
    silence_warnings { Object.const_set("PAGINATION_PER_PAGE_SIZE", number) }
    yield
  ensure
    silence_warnings { Object.const_set("PAGINATION_PER_PAGE_SIZE", old_value) }
  end

  def mingle_users(login)
    User.find_by_login(login.to_s)
  end

  def set_anonymous_access_for(proj, flag)
    by_first_admin_within(proj) do
      proj.update_attribute(:anonymous_accessible, flag)
    end
  end

  def by_first_admin_within(project, &block)
    User.first_admin.with_current do
      project.with_active_project(&block)
    end
  end

  def find_prepared_project(identifier)
    project = Project.find_by_identifier(identifier)
    unless project
      load_predefined_project(identifier)
      project = Project.find_by_identifier(identifier)
    end
    project
  end

  def load_predefined_project(identifier)
    script = File.expand_path("data/load_project", File.dirname(__FILE__))
    system("ruby #{script} #{identifier} 2>&1")
  end

  def unescape_unicode(s)
    s.gsub(/\\u([\da-fA-F]{4})/) {|m| [$1].pack("H*").unpack("n*").pack("U*")}
  end

  def method_missing(method_id, *args, &block)
    method_name = method_id.to_s
    identifier = nil
    if method_name =~ /^(with_)([a-z_]+)(_project)$/
      identifier = "#{$2}_project"
    elsif method_name =~ /^(with_project_)([a-z_]+)$/
      identifier = "project_#{$2}"
    end

    if identifier
      project = find_prepared_project(identifier)
      if project
        return project.with_active_project(&block)
      else
        return super
      end
    end

    if method_name =~ /^([a-z_]+)(_project)$/ || method_name =~ /^(project_)([a-z_]+)$/
      if project = find_prepared_project(method_name)
        raise "#{method_name} is used to look up project, maybe you mean 'with_#{method_name}'?" if block_given?
        return project
      else
        return super
      end
    end

    if method_name =~ /^assert_(.*)_not_equal$/
      equal_by = $1
      failed_msg = args[2] ? "#{args[2]}: " : ""
      failed_msg += "#{equal_by} is equal"
      return assert_not_equal(args[0].send(equal_by), args[1].send(equal_by), failed_msg)
    end

    if method_name =~ /^assert_(.*)_equal$/
      equal_by = $1
      failed_msg = args[2] ? "#{args[2]}: " : ""
      failed_msg += "#{equal_by} is different"
      return assert_equal(args[0].send(equal_by), args[1].send(equal_by), failed_msg)
    end

    return super
  end

  def with_new_project(options = {}, &block)
    project = create_project(options.merge(:skip_activation => true))
    project.with_active_project(&block)
    project
  end

  def with_temp_file(file_name=['test', '.unknown'], &block)
    tmp_file = Tempfile.new(file_name)
    yield(tmp_file) if block_given?
  ensure
    tmp_file.delete
  end

  def select_current_project(project)
    assert_not_nil project
    @current_project = project
  end

  def view_helper
    return @view_helper if @view_helper
    ActionController::Routing::Routes.install_helpers(FakeViewHelper)
    @view_helper = FakeViewHelper.new
  end

  def card_context
    return unless defined?(session)
    CardContext.new(Project.current, session["project-#{Project.current.id}"] ||= {})
  end

  def with_max_grid_view_size_of(max_size, &block)
    with_constant_set('CardViewLimits::MAX_GRID_VIEW_SIZE', max_size, &block)
  end

  def with_constant_set(constant, value, &block)
    ConstantResetter.set_constant :name => constant, :value => value
    block.call
  ensure
    ConstantResetter.reset_constant :name => constant
  end

  def setup_card_context(context, view)
    context.store_tab_state(view, 'cards', nil)
    context.current_list_navigation_card_numbers = view.card_numbers
  end

  def perform_as(email, &block)
    User.with_current(user_named(email)) { yield }
  end

  def login(user_or_identifier, &block)
    user = user_or_identifier.respond_to?(:email) ? user_or_identifier : user_named(user_or_identifier)
    User.current = user
    @request.session[:login] = user.login if defined?(@request) # for controller tests
    user.update_last_login
    user
  end

  def user_named(identifier)
    user = User.find_by_email(identifier) || User.find_by_name(identifier) || User.find_by_login(identifier)
    assert_not_nil user, "user doesn't exist, you might have forgotten to load fixtures for login [#{identifier}]"
    user
  end

  def login_as_admin
    login('admin@email.com')
  end

  def login_as_proj_admin
    login('proj_admin@email.com')
  end

  def login_as_member
    login('member@email.com')
  end

  def login_as_bob
    login('bob@email.com')
  end

  def login_as_longbob
    login('longbob@email.com')
  end

  def logout_as_nil
    User.current = nil
    @request.session[:login] = nil if defined?(@request) # for controller tests
    cookies.delete('login') if defined?(@response) # for controller tests
  end

  def cache_revisions_content_for(project)
    project.revisions.each do |revision|
      RevisionsViewCache.new(project).cache_content_for(revision.number)
    end
  end

  def make_as_project_first_card_type(project, card_type_name)
    card_type = project.find_card_type(card_type_name)
    card_type.nature_reorder_disabled = true
    card_type.move_to_top
    assert_equal card_type, project.card_types.reload.first
  end

  def change_license_to_not_allow_anonymous_access
    register_license(:allow_anonymous => false)
  end

  def change_license_to_allow_anonymous_access
    register_license(:allow_anonymous => true)
  end

  def register_license_for(licensed_to)
    register_license(:licensee => licensed_to)
  end


  def register_expiration_license_with_allow_anonymous
    Clock.fake_now(:year => 2008, :month => 7, :day => 12)
    register_license(:expiration_date => '2008-07-13', :allow_anonymous => true)
  ensure
    Clock.reset_fake
  end

  def clear_user_display_preferences
    ActiveRecord::Base.connection.execute("DELETE FROM #{UserDisplayPreference.table_name}")
  end

  def with_reset_secure_site_url(&block)
    old_secure_site_url = MingleConfiguration.secure_site_url
    yield
  ensure
    MingleConfiguration.secure_site_url = old_secure_site_url
  end

  def with_reset_site_url(&block)
    old_site_url = MingleConfiguration.site_url
    yield
  ensure
    MingleConfiguration.site_url = old_site_url
  end

  def at_time_after(advance_by, &block)
    Clock.now_is(Clock.now.advance(advance_by)) {yield }
  end

  def group_assert(&block)
    $group_assertion = []
    yield
    unless $group_assertion.empty?
      message = %Q{#{$group_assertion.size} assertions failed:
#{$group_assertion.collect {|f| "  Failure: #{f.message}"}.join("\n")}}
      raise message
    end
  ensure
    $group_assertion = nil
  end

  def assert_with_group(*args, &block)
    assert_without_group(*args, &block)
  rescue Exception => e
    if $group_assertion
      $group_assertion << e
    else
      raise
    end
  end
  alias_method_chain :assert, :group

  def hash_from_xml(xml)
    Hash.from_xml(xml).values.first.symbolize_keys
  end

  def assert_equal_ignoring_mingle_formatting(expected, actual)
    assert_equal MingleFormatting.remove_mingle_formatting(expected), MingleFormatting.remove_mingle_formatting(actual)
  end

  def assert_equal_ignoring_order(expected, actual, message = nil)
    assert_equal(expected.downcase.strip_all.split('').sort.join, actual.downcase.strip_all.split('').sort.join, (message || "Expected #{expected}, was #{actual}"))
  end

  def assert_equal_ignoring_spaces(expected, actual, message = nil)
    assert_equal_ignoring_case(expected.strip_all, actual.strip_all, (message || "Expected #{expected}, was #{actual}"))
  end

  def assert_equal_ignoring_spaces_and_return(expected, actual, message = nil)
    expected = expected.strip_all.gsub(/\r|\n/, '')
    actual = actual.strip_all.gsub(/\r|\n/, '')
    assert_equal(expected, actual, (message || "Expected #{expected}, was #{actual}"))
  end

  def assert_equal_ignoring_case(expected, actual, message = nil)
    assert_equal(expected.downcase, actual.downcase, (message || "Expected #{expected}, was #{actual}"))
  end

  def assert_include_ignoring_spaces(expected_included, actual)
    assert actual.strip_all.include?(expected_included.strip_all), "#{actual} \n\nshould contain #{expected_included}, but doesn't"
  end

  def assert_include(included, content, message = '')
    assert content.include?(included), "#{content.inspect} \n\nshould contain #{included.inspect}, but not. #{message}"
  end

  def assert_not_include(included, content)
    assert !content.include?(included), "#{content.inspect} \n\nshould not contain #{included.inspect}, but it does"
  end

  def assert_unordered_equal(expected, actual)
    assert_equal expected.size, actual.size, "#{expected.size} elements expected, but got: #{actual.size}"
    expected.all? { |obj| assert(actual.include?(obj), "#{obj.inspect} was expected to be part of #{actual.inspect}") }
  end

  def assert_false(expression)
    assert_equal false, expression
  end

  def assert_not(expression, msg=nil)
    assert !expression, msg
  end

  def assert_blank(obj)
    assert obj.blank?, "obj should be blank, but is #{obj.inspect}"
  end

  def assert_not_blank(obj)
    assert !obj.blank?, "obj should not be blank, but is"
  end

  def assert_record_deleted(record, messsage=nil)
    assert !record.class.find_by_id(record.id), messsage || "#{record.class.name}##{record.id} should not in database but it dose"
  end

  def assert_equivalent(expected, actual)
    assert expected.equivalent?(actual), "Expected: #{expected.join(",")} value was not equivalent to #{actual.join(",")}"
  end

  def assert_png(png)
    assert_match(/IHDR/, png) # check for the PNG IHDR block
  end

  def assert_record_not_deleted(record, message=nil)
    assert record.class.find_by_id(record.id), message || "#{record.class.name}##{record.id} is not deleted"
  end

  def assert_count_same_after(records, &block)
    count = records.count
    yield
    assert_equal count, records.count
  end

  def card_list_view_params
    {:action => 'list', :style => 'list', :tab => DisplayTabs::AllTab::NAME}
  end

  def assert_card_list_view_params(expected, actual)
    assert_equal(card_list_view_params.merge(expected), actual)
  end

  def assert_card_has_column(column)
    assert Card.columns.collect(&:name).include?(column), "Card table should contain column #{column}, but does not"
    assert Card::Version.columns.collect(&:name).include?(column), "Card version table should contain column #{column}, but does not"
  end

  def assert_card_not_has_column(column)
    assert !Card.columns.collect(&:name).include?(column), "Card table should not contain column #{column}, but it does"
    assert !Card::Version.columns.collect(&:name).include?(column), "Card version table should not contain column #{column}, but it does"
  end

  def assert_card_not_in_tree_and_relationships_are_nil(tree_configuration, card)
    assert !tree_configuration.include_card?(card)
    tree_configuration.relationships.each do |relationship|
      assert_nil relationship.value(card)
    end
  end

  def assert_card_directly_under_root(tree_configuration, card)
    assert tree_configuration.include_card?(card)
    tree_configuration.relationships.each do |relationship|
      assert_nil relationship.value(card)
    end
  end

  def assert_raise_message(types, matcher, message = nil, &block)
    # Original source: http://www.oreillynet.com/onlamp/blog/2007/07/assert_raise_on_ruby_dont_just.html
    args = [types].flatten + [message]
    exception = assert_raise(*args, &block)
    assert_match matcher, exception.message, message
  end

  def assert_dom_content(expected, markup)
    doc = Nokogiri::HTML::DocumentFragment.parse(markup)
    actual = doc.text

    assert_equal expected.normalize_whitespace, actual.normalize_whitespace
  end

  # get us an object that represents an uploaded file
  def uploaded_file(path, filename=nil, content_type="application/octet-stream")
    UnitTestDataLoader.uploaded_file(path, filename, content_type)
  end

  def sample_attachment(filename=nil)
    UnitTestDataLoader.sample_attachment(filename)
  end

  def another_sample_attachment(filename=nil)
    UnitTestDataLoader.another_sample_attachment(filename)
  end

  def self.does_not_work_without_jruby
    unless RUBY_PLATFORM =~ /java/
      class_eval do
        def run(*args)
          putc 'S'
          at_exit {puts "WARNING: #{name} does not work without Jruby platform, skipped..."}
        end
      end
    end
  end

  def self.does_not_work_with_jruby
    if RUBY_PLATFORM =~ /java/
      class_eval do
        def run(*args)
          putc 'S'
          at_exit {puts "WARNING: #{name} does not work with Jruby platform, skipped..."}
        end
      end
    end
  end

  def self.for_manual_test
    class_eval do
      def run(*args)
        putc 'S'
        at_exit {puts "INFO: #{name} is only for manual test, skipped..."}
      end
    end
  end

  def self.does_not_work_without_subversion_bindings
    unless Repository.available?
      class_eval do
        def run(*args)
          putc 'S'
          at_exit { puts "WARNING: #{name} does not work without Subversion bindings, skipped..." }
        end
      end
    end
  end

  def does_not_work_without_jruby(&block)
    if RUBY_PLATFORM =~ /java/
      yield
    else
      putc 'S'
      at_exit { puts "WARNING: #{name} does not work without jruby, skipped..." }
    end
  end

  def does_not_work_without_subversion_bindings
    if Repository.available?
      yield
    else
      putc 'S'
      at_exit { puts "WARNING: #{name} does not work without Subversion bindings, skipped..." }
    end
  end

  def does_not_work_with_jruby
    if RUBY_PLATFORM =~ /java/
      putc 'S'
      at_exit { puts "WARNING: #{name} does not work with jruby, skipped..." }
    else
      yield
    end
  end

  def is_jruby?
    RUBY_PLATFORM =~ /java/
  end

  def requires_jruby
    unless is_jruby?
      putc 'S'
      at_exit { puts "WARNING: #{name} does not work without jruby, skipped..." }
    else
      yield
    end
  end

  def self.postgresql?
    configs = ActiveRecord::Base.configurations[Rails.env]
    configs['adapter'] =~ /postgresql/ || (configs['adapter'] =~ /jruby|jdbc/ && configs['driver'] =~ /postgresql/)
  end

  def self.oracle?
    !self.postgresql?
  end

  def for_postgresql
    yield if self.class.postgresql?
  end

  def for_oracle
    yield if self.class.oracle?
  end

  def requires_update_full_text_index
    yield
  end

  def requires_perforce_available(&block)
    run_if P4.available?, 'does not work without perforce', &block
  end

  def requires_perforce_unavailable(&block)
    run_if !P4.available?, 'does not work with perforce', &block
  end

  def run_if(condition, description)
    unless condition
      putc 'S'
      at_exit { puts "WARNING: #{name} #{description}, skipped..." }
    else
      yield
    end
  end

  def json_escape(str)
    str.gsub(/[&"><]/) { |special| "\\#{ERB::Util::JSON_ESCAPE[special]}" }
  end

  def json_unescape(str)
    str.gsub!(/\\u0026/, '&')
    str.gsub!(/\\u003E/, '>')
    str.gsub!(/\\u003C/, '<')
    str
  end

  def delete_all_templates
    Project.find_all_by_template(true).each(&:destroy)
  end

  def destroy_all_tags
    Tag.find_by_sql("select * from tags").each {|tag| tag.destroy!}
  end

  def recreate_revisions_for(project)
    project = (project.respond_to? :identifier) ? project : Project.find_by_identifier(project)
    project.reload.re_initialize_revisions_cache
    project.cache_revisions
    project.reload
  end

  def create_tabbed_view(name, project, params = {})
    view = create_named_view(name, project, params)
    view.tab_view = true
    view.save!
    view
  end

  def create_named_view(name, project, params = {})
    view = CardListView.construct_from_params(project, params)
    view.name = name
    view.save!
    project.reload
    view
  end

  def today_in_project_format(project = Project.current)
    project.today.strftime(project.date_format)
  end

  def utc_today_in_project_format(project = Project.current)
    Clock.now.strftime(project.date_format)
  end

  def set_modified_time(versioned, version, year, month, day, hour, min, sec)
    time = Time.utc(year, month, day, hour, min, sec)
    set_modified_time_with_time(versioned, version, time)
  end

  def set_event_timestamp(event, time)
    Event.set_event_timestamp(event, time)
  end

  def set_modified_time_with_time(versioned, version, time)
    raise "no id for #{versioned}" unless versioned.id
    time = time.utc
    restriction_column_id = 'project_id'
    sql = "UPDATE #{versioned.class.versioned_class.quoted_table_name} SET updated_at = ? where #{versioned.class.versioned_foreign_key} = #{versioned.id} and version = #{version} and #{restriction_column_id} = #{Project.current.id}"
    ActiveRecord::Base.connection.execute(sanitize_sql(sql, time))
    sql = "UPDATE events SET created_at = ? where events.origin_type = '#{versioned.class.versioned_class.name}' and events.origin_id = #{versioned.find_version(version).id} and deliverable_id = #{Project.current.id}"
    ActiveRecord::Base.connection.execute(sanitize_sql(sql, time))
  end


  def set_created_time(has_timestamp, year, month, day, hour, min, sec)
    time = Time.utc(year, month, day, hour, min, sec)
    sql = "UPDATE #{has_timestamp.class.quoted_table_name} SET created_at = ? where id = ?"
    ActiveRecord::Base.connection.execute(sanitize_sql(sql, time, has_timestamp.id))
  end

  def set_current_user(user)
    old_user = User.current
    login(user.email)
    yield
    login(old_user.email) if old_user
  end

  # only use this when you're not testing anything about card creation via the UI
  def create_cards(project, count, options = {})
    project.activate
    card_type = options[:card_type] || project.card_types.first
    card_name = 'card'
    card_name = options[:card_name] if options[:card_name]
    card_description = options[:card_description] if options[:card_description]
    cards = []
    (1..count).each do |index|
      cards << project.cards.create!(:name => "#{card_name} #{index}", :card_type => card_type, :description => card_description)
      cards[index-1].tag_with(options[:tag]).save! if options[:tag]
    end
    cards
  end


  def setup_user_definition(name)
    UnitTestDataLoader.setup_user_definition(name)
  end

  # to be careful, this card prop def should only be used in unit test
  # it's not a real prop def that user can define.
  def setup_card_property_definition(name, valid_card_type)
    UnitTestDataLoader.setup_card_property_definition(name, valid_card_type)
  end

  #method for creating allow any text property with a better name
  def setup_allow_any_text_property_definition(name, options={})
    UnitTestDataLoader.setup_text_property_definition(name, options)
  end
  #method for creating allow any text property, but its name is confusing, please use setup_allow_any_text_property_definition instead
  alias_method :setup_text_property_definition, :setup_allow_any_text_property_definition

  #method for creating allow any number property with a better name
  def setup_allow_any_number_property_definition(name)
    UnitTestDataLoader.setup_numeric_text_property_definition(name)
  end
  #method for creating allow any number property, but its name is confusing, please use setup_allow_any_number_property_definition instead
  alias_method :setup_numeric_text_property_definition, :setup_allow_any_number_property_definition

  def setup_allow_any_number_property_definitions(*names)
    names.map { |name| setup_allow_any_number_property_definition(name) }
  end

  def setup_date_property_definition(name)
    UnitTestDataLoader.setup_date_property_definition(name)
  end

  def setup_date_property_definitions(*names)
    names.map { |name| setup_date_property_definition(name) }
  end

  def setup_formula_property_definition(name, formula)
    UnitTestDataLoader.setup_formula_property_definition(name, formula)
  end

  #this method is for creating card type property, both relationship and any card, but its name is confusing, please use next method
  def setup_card_relationship_property_definition(name)
    UnitTestDataLoader.setup_card_relationship_property_definition(name)
  end

  #this method is for creating card type property, both relationship and any card, and has a better name
  def setup_card_type_property_definition(name)
    UnitTestDataLoader.setup_card_relationship_property_definition(name)
  end

  def setup_aggregate_property_definition(name, aggregate_type, target_property_definition, tree_id, aggregate_card_type_id, aggregate_scope)
    UnitTestDataLoader.setup_aggregate_property_definition(name, aggregate_type, target_property_definition, tree_id, aggregate_card_type_id, aggregate_scope)
  end

  def setup_property_definitions(properties_with_values = {}, options={})
    UnitTestDataLoader.setup_property_definitions(properties_with_values, options)
  end

  def setup_managed_number_list_definition(property_definition_name, values, options = {})
    UnitTestDataLoader.setup_numeric_property_definition(property_definition_name, values, options)
  end

  alias_method :setup_numeric_property_definition, :setup_managed_number_list_definition

  def setup_managed_number_list_definitions(property_definition_names_and_values, options={})
    property_definition_names_and_values.each { |(name, values)| setup_managed_number_list_definition(name, values, options) }
  end

  def setup_managed_text_definition(property_definition_name, values, options={})
    UnitTestDataLoader.setup_managed_text_definition(property_definition_name, values, options)
  end

  def setup_card_type(project, card_type_name, options = {})
    new_card_type = nil
    project.with_active_project do |active_project|
      new_card_type = active_project.card_types.create!(:name => card_type_name.to_s)

      (options[:properties] ||= []).each do |property_name|
        new_card_type.add_property_definition active_project.find_property_definition(property_name, :with_hidden => true)
      end
    end
    project.reload
    new_card_type
  end

  def setup_card_types(project, options={})
    options[:names].map { |card_type_name| setup_card_type(project, card_type_name, options) }
  end

  def create_plv(project, attributes)
    project.project_variables.create(attributes).tap { |plv| project.reload }
  end

  def create_plv!(project, attributes)
    project.project_variables.create!(attributes).tap { |plv| project.reload }
  end

  def setup_project_variable(project, options)
    project = Project.find_by_identifier(project) unless project.respond_to? :identifier
    name = options[:name]
    data_type = options[:data_type]
    card_type = options[:card_type]
    value = if (data_type == ProjectVariable::USER_DATA_TYPE || data_type == ProjectVariable::CARD_DATA_TYPE)
        options[:value].blank? ? options[:value] : options[:value].id
      else
        options[:value]
      end
    properties = options[:properties] || []
    property_definitions = properties.collect{|property_name| project.find_property_definition(property_name)} unless properties.first.respond_to?(:name)
    property_ids = property_definitions.collect(&:id)
    project_variable = project.project_variables.create!(:name => name, :data_type => data_type, :card_type => card_type, :value => value, :property_definition_ids => property_ids)
    project.reload
    project_variable
  end

  def create_transition(project, name, options = {})
    transition = create_transition_without_save(project, name, options)
    transition.save!
    project.reload
    transition
  end

  def create_transition_without_save(project, name, options = {})
    transition = project.transitions.new(:name => name, :project_id => project.id, :require_comment => options[:require_comment])
    transition.card_type = options[:card_type]

    transition.add_value_prerequisites(options[:required_properties])
    transition.add_set_value_actions(options[:set_properties])
    transition.add_user_prerequisites(options[:user_prerequisites])
    transition.add_group_prerequisites(options[:group_prerequisites])

    (options[:remove_from_trees] || []).each do |tree_configuration|
      transition.add_remove_card_from_tree_action(tree_configuration, TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE)
    end

    (options[:remove_from_trees_with_children] || []).each do |tree_configuration|
      transition.add_remove_card_from_tree_action(tree_configuration, TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE)
    end

    transition
  end

  def property_value_from_db(project, property_name, db_identifier)
    prop_def = project.find_property_definition(property_name, :with_hidden => true)
    prop_value = PropertyValue.create_from_db_identifier(prop_def, db_identifier)
  end


  def configure_subversion_for(project, options)
    existing_configuration = SubversionConfiguration.find_by_project_id(project.id)
    existing_configuration.update_attribute(:marked_for_deletion, true) if existing_configuration
    config = SubversionConfiguration.create!(:project => project, :initialized => true, :repository_path => options[:repository_path])
    project.reload
    config
  end


  def create_user!(options = {})
    login = unique_name
    user_properties = {:login => login, :email => "#{login}@email.com", :name => "name of #{login}",
      :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}.merge(options)
    User.create!(user_properties)
  end

  def find_or_create_user!(options={})
    login = unique_name
    user_properties = {:login => login, :email => "#{login}@email.com", :name => "name of #{login}",
                       :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}.merge(options)
    if user = User.find_by_login(user_properties[:login])
      user.update_attributes!(user_properties.except(:login))
      user.reload
    else
      User.create!(user_properties)
    end
  end

  def create_user_without_validation(options = {})
    login = unique_name
    user_properties = {:login => login, :email => "#{login}@email.com", :name => "name of #{login}",
      :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}.merge(options)
    user = User.new(user_properties)
    user.save(false)
    user
  end

  def clear_all_existing_user_memberships_for(project)
    User.with_first_admin do
      project.team.users.clear
    end
    project.team.reload
  end

  def create_card_in_future( time=2.seconds, attrs={})
    Timecop.travel(DateTime.now + time) do
      create_card!(attrs)
    end
  end

  def create_cards_in_future(count, time=2.seconds, attrs={})
    cards = []
    count.times do |i|
      Timecop.travel(DateTime.now + time + i.seconds) do
        cards << create_card!(attrs.merge(name: unique_name))
      end
    end
    cards
  end

  def create_card!(attrs={})
    attrs = attrs.clone
    card_attributes = {}
    card_attributes[:name] = attrs.delete(:name)
    card_attributes[:number] = attrs.delete(:number)
    card_attributes[:description] = attrs.delete(:description)
    card_attributes[:tags] = attrs.delete(:tags)
    card_attributes[:attachments] = attrs.delete(:attachments)
    card_attributes[:completed_checklist_items] = attrs.delete(:completed_checklist_items)
    card_attributes[:incomplete_checklist_items] = attrs.delete(:incomplete_checklist_items)
    UnitTestDataLoader.create_card_with_property_name(Project.current.reload, card_attributes, attrs)
  end

  def new_murmur(options={})
    common_options = { :packet_id => '12345abc'.uniquify, :project_id => Project.current.id, :murmur => 'this is a piece of message', :type => DefaultMurmur.name}
    unless (options[:author] || options[:jabber_user_name])
      common_options.merge!(:author => User.current)
    end
    DefaultMurmur.new(common_options.merge(options))
  end

  def create_murmur(options={})
    murmur = new_murmur(options)
    murmur.save!
    murmur
  end

  def create_group(name, members=[])
    perform_as('admin@email.com') do
      group = Project.current.groups.create!(:name => name)
      members.each { |member| group.add_member(member) }
      group
    end
  end

  def find_murmur_from(card)
    Murmur.find_by_origin_type_and_origin_id('Card', card.id)
  end

  def create_card_importer!(project, tab_separated_import_path, mappings=nil, ignores=nil, tree_configuration_id=nil, user=User.current)
    preview_request = File.open(tab_separated_import_path) do |f|
       user.asynch_requests.create_card_import_preview_asynch_request(project.identifier, f)
    end
    CardImporter.fromActiveMQMessage(
      CardImportPublisher.new(project, user, preview_request.id, mappings, ignores, tree_configuration_id).publish_message
    )
  end

  def create_card_import_preview!(project, tab_separated_import_path, mappings=nil, user=User.current)
    raise "Cannot find the import file by the path #{tab_separated_import_path}" unless File.exists?(tab_separated_import_path)
    CardImportingPreview.fromActiveMQMessage(
      CardImportPreviewPublisher.new(project, user, tab_separated_import_path).publish_message
    )
  end

  def setup_tree(project, name, options={})
    raise "You must pass an array of types into setup_tree (e.g. :types => [type1, type2, type3])" unless options[:types]
    types = options[:types]
    relationship_names = options[:relationship_names]
    types_hash = {}
    types.each_with_index do |type, index|
      types_hash[type] = relationship_names ? {:position => index, :relationship_name => relationship_names[index]} : {:position => index}
    end

    tree_config = project.tree_configurations.create!(:name => name)
    tree_config.update_card_types(types_hash)
    tree_config
  end

  def add_card_to_tree(tree_configuration, child_card_or_cards, parent_card = :root)
    child_card_or_cards = [child_card_or_cards] unless child_card_or_cards.is_a?(Array)
    tree_configuration.add_children_to(child_card_or_cards.collect(&:reload), parent_card)
  end

  def add_cards_to_tree(tree_configuration, parent_card, *cards)
    add_card_to_tree(tree_configuration, parent_card, :root) unless tree_configuration.include_card?(parent_card)
    last_card = parent_card
    cards.each do |card|
      if card.is_a?(Array)
        add_cards_to_tree(tree_configuration, last_card, *card)
      else
        add_card_to_tree(tree_configuration, card, parent_card)
        last_card = card
      end
    end
  end

  def remove_card_from_tree(tree_configuration, card)
    tree_configuration.remove_card(card)
  end

  def remove_card_and_its_children_from_tree(tree_configuration, card)
    tree_configuration.remove_card_and_its_children(card)
  end

  def position_of_property_value(project, property_name, value_to_find)
    project.find_property_definition(property_name).enumeration_values.detect {|property| property.value == value_to_find }.position
  end

  def unique_project_name(prefix = nil)
    UnitTestDataLoader.unique_project_name(prefix)
  end

  def unique_name(prefix = '')
    UnitTestDataLoader.unique_name(prefix)
  end

  def standardize_cast(original, position)
    # MySql and Postgres handle casting differently.
    # Postgresql: "CAST(\"card_type_name\".position AS DECIMAL(65,10)) = 1.0"
    # MySql: "CAST(`card_type_name`.position AS DECIMAL(65,10)) = '1.0'"
    original.gsub(/"/, "`").gsub(/'#{position}'/, "#{position}")
  end

  def cleanup_repository_drivers_on_failure
    if @__repository_drivers
      @__repository_drivers.compact.each do |driver|
        driver.stop_service
        FileUtils.rm_rf(driver.repos_dir) if passed?
        FileUtils.rm_rf(driver.wc_dir) if passed?
      end
    end
  end

  def with_cached_repository_driver(name)
    driver = RepositoryDriver.new(name.uniquify, true)
    (@__repository_drivers ||= []) << driver
    yield driver if block_given? && driver.not_initialized_from_cache
    driver
  end

  def export_all_deliverables
    to_dir = Rails.root.join('test', 'reports', Time.now.to_i.to_s)
    FileUtils.mkdir_p to_dir
    Rails.logger.info "[TEST] exporting all deliverables to #{to_dir}..."
    Project.all.each do |project|
      Rails.logger.info "[TEST]......exporting #{project.identifier}"
      file = create_project_exporter!(project, User.first_admin).export
      FileUtils.mv(file, to_dir)
    end
    Program.all.each do |program|
      Rails.logger.info "[TEST].....exporting #{program.name}"
      file = create_program_exporter!(program, User.first_admin).process!
      FileUtils.mv(file, to_dir)
    end
  end

  def create_export_file(is_template=false, &block)
    with_new_project do |project|
      yield(project) if block_given?
      export_file = create_project_exporter!(project, @user, :template => is_template).export
      project.destroy
      return export_file
    end
  end

  def assert_relative_file_path_in_directory(file_path, dir)
    files = Dir[File.join(dir, "**", "*")]
    file_path = File.join(dir, file_path)
    assert files.include?(file_path), "#{files.inspect} should include #{file_path} but not"
  end

  def file_in_directory?(file_name, dir)
    Dir.foreach(dir) do |entry|
      next if entry == "." || entry == ".."
      return true if entry == file_name
      if File.directory?("#{dir}/#{entry}")
        found_file = file_in_directory?(file_name, "#{dir}/#{entry}")
        return true if found_file
      end
    end
    return false
  end

  # this method generate a tenant configuration that test can use to
  # pointing to the current database running tests.
  def current_db_tenant_config
    ActiveRecord::Base.configurations['test'].inject({}) do |memo, pair|
      key, value = pair
      memo["database_#{key}"] = value
      memo
    end
  end

  def generate_random_string(char_count)
    (0...char_count).map { ('a'..'z').to_a[rand(26)] }.join
  end



  def current_db_time_utc
    sql = case ActiveRecord::Base.connection.database_vendor
          when :postgresql
            "select clock_timestamp() at time zone 'utc' as dbtime"
          when :oracle
            "select sys_extract_utc(current_timestamp) as dbtime from dual"
          end
    db_time = ActiveRecord::Base.connection.select_one(sql)['dbtime']
    Time.parse(db_time + " UTC")
  end

  def with_unziped_plan_export(export_file, &block)
    unzipped_export(export_file, '.plan', &block)
  end

  def with_unziped_mingle_export(export_file, &block)
    unzipped_export(export_file, '.mingle', &block)
  end

  def with_unziped_dependencies_export(export_file, &block)
    unzipped_export(export_file, '.dependencies', &block)
  end

  def unzipped_export(export_file, extension)
    with_temp_dir do |dir|
      unzip(export_file, dir)
      yield dir
    end
  end

  def with_temp_dir
    temp_dir_name = "test_helper_tmp".uniquify
    full_path = File.expand_path(File.join(RAILS_TMP_DIR, temp_dir_name))
    FileUtils.mkdir_p(full_path)
    yield full_path
  ensure
    FileUtils.rm_rf(full_path)
  end

  def assert_file_not_exists_in_exported_file(export_file, *unexpected_files)
    with_unziped_mingle_export(export_file) do |dir|
      unexpected_files.each do |unexpected_file|
        assert !file_in_directory?(unexpected_file, dir)
      end
    end
  end


  def assert_file_exists_in_exported_file(export_file, *expected_files)
    with_unziped_mingle_export(export_file) do |dir|
      expected_files.each do |expected_file|
        assert file_in_directory?(expected_file, dir)
      end
    end
  end

  def numbers_of(*card_names)
    card_names.collect do |card_name|
      Project.current.cards.find_by_name(card_name).number
    end
  end

  def update_fulltext_index_for(project)
    project.cards.reload.each(&:update_full_text_index)
    project.pages.reload.each(&:update_full_text_index)
    project.revisions.reload.each(&:update_full_text_index)
    project.murmurs.reload.each(&:update_full_text_index)
  end

  def generate_card_changes_for(*cards)
    cards.each do |card|
      card.generate_changes
      card.versions.each {|v|v.event.send :generate_changes}
    end
  end

  def compute_aggregate_for_single_card(card, property_name)
    project = card.project
    AggregateComputation::CardsProcessor.new.send(:compute_aggregate, {:project_id => project.id, :card_id => card.id, :aggregate_property_definition_id => project.find_property_definition(property_name).id})
  end

  def attachment_url(attachment)
    "http://test.host/projects/#{attachment.project.identifier}/attachments/#{attachment.id}"
  end


  def filtered_events(filters={})
    sql = HistoryFilters.new(Project.current, filters).to_sql
    ActiveRecord::Base.connection.select_all(sql)
  end

  def with_messaging_enable(&block)
    Messaging.enable
    Messaging::Mailbox.transaction do
      begin
        yield
      ensure
        Messaging::Mailbox.instance.reset
      end
    end
  ensure
    Messaging.disable
  end

  def with_profile_server_configured(url="https://profile-server", app_namespace="parsley", &block)
    MingleConfiguration.app_namespace = app_namespace
    http_stub = HttpStub.new
    ProfileServer.configure({:url => url}, http_stub)
    yield(http_stub)
  ensure
    ProfileServer.reset
    MingleConfiguration.app_namespace = nil
  end

  def stub_env(new_env, &block)
    original_env = Rails.env
    Rails.instance_variable_set('@_env', ActiveSupport::StringInquirer.new(new_env))
    block.call
  ensure
    Rails.instance_variable_set('@_env', ActiveSupport::StringInquirer.new(original_env))
  end

  def random_color
    '#%06x' % (rand * 0xffffff)
  end

  def create_tags(project, count, options = {})
    project.activate
    tag_name = options[:tag_name] || 'tag'
    count.times.map do |index|
      project.tags.create!(:name => "#{tag_name} #{index+1}", :project_id => project.identifier, :color => random_color)
    end
  end

end

module Untab
  def untab
    indentation_levels = Hash.new(0)
    each_line_with_index do |line, index|
      line.scan(/  /) { indentation_levels[index] += 1 }
    end

    result = ""
    base_indentation_level = indentation_levels.values.min
    indentation_levels = Hash[indentation_levels.map { |key, value| [key, value - base_indentation_level] }]

    each_line_with_index do |line, index|
      rewrite = line.gsub(/^(  )*/, '  ' * (indentation_levels[index] || 0))
      result << rewrite
    end
    result
  end

  def each_line_with_index(&block)
    index = 0
    each_line do |line|
      yield(line, index)
      index += 1
    end
  end

  # Don't wanna check-in a test for Untab...
  #   def test_it_sorta_works
  #     actual = <<-YAML
  #     {{
  #       table
  #         view: THIS CARD.text_field
  #     }}
  #     YAML
  #     expected = <<-YAML
  # {{
  #   table
  #     view: THIS CARD.text_field
  # }}
  #     YAML
  #     assert_equal expected, actual.untab
  #   end

end
String.send :include, Untab

# call IRB.start_session(binding) to open an IRB session.
require 'irb'
module IRB # :nodoc:
  def self.start_session(binding)
    unless @__initialized
      args = ARGV
      ARGV.replace(ARGV.dup)
      IRB.setup(nil)
      ARGV.replace(args)
      @__initialized = true
    end

    workspace = WorkSpace.new(binding)

    irb = Irb.new(workspace)

    @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = irb.context

    catch(:IRB_EXIT) do
      irb.eval_input
    end
  end
end

class Object
  def mock_methods(method_call_hash)
    method_call_hash.each do |method_name, return_value|
      class_eval { send(:define_method, method_name.to_sym) {|*_| return_value } }
    end
    self
  end
end
