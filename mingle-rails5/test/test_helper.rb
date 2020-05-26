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

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
Dir[File.expand_path(File.dirname(__FILE__) + '/test_helpers/*')].each do |file|
  require file.gsub(/.rb\z/, '')
end
require 'mocha/mini_test'
require 'webmock/minitest'
require 'minitest/reporters'
require 'shoulda'
REPORTS_DIR = File.join(Rails.root, 'reports')
reporters = [Minitest::Reporters::ProgressReporter.new]
if ENV['GO_ENVIRONMENT_NAME']
  spec_reporter = Minitest::Reporters::SpecReporter.new
  html_reporter = Minitest::Reporters::HtmlReporter.new(reports_dir: File.join(REPORTS_DIR, 'html'))
  junit_reporter = Minitest::Reporters::JUnitReporter.new(File.join(REPORTS_DIR, 'xml'))
  reporters = [spec_reporter, html_reporter, junit_reporter]
end

Minitest::Reporters.use! reporters


WebMock.allow_net_connect!
Dir[File.expand_path(File.dirname(__FILE__) + '/test_helpers/*.rb')].each {|f| require f}
Dir[File.expand_path(File.dirname(__FILE__) + '/stubs/*.rb')].each {|f| require f}

MingleConfiguration.site_url = "http://#{Socket.gethostname}:4001" if MingleConfiguration.site_url.blank?
MingleConfiguration.secure_site_url = "https://#{Socket.gethostname}:8443" if MingleConfiguration.secure_site_url.blank?
MingleConfiguration.no_cleanup = true

class ActiveSupport::TestCase
  include SetupHelper
  include AttachmentsHelper
  include FactoryGirl::Syntax::Methods
  MINGLE_SESSION_ID = "mingle_#{MINGLE_VERSION}_session_id"
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  setup do
    unless skip_global_context_setup?
      register_license
      License.eula_accepted
    end

  end

  teardown do
    clear_license unless skip_global_context_setup?
  end

  def skip_global_context_setup?
    self.class.respond_to?(:skip_global_setup) && self.class.skip_global_setup
  end

  def register_expiration_license_with_allow_anonymous
    travel_to(Date.new(2008, 7, 12)) do
      register_license(:expiration_date => '2008-07-13', :allow_anonymous => true)
    end
  end

  def unique_name(prefix = '')
    "#{prefix}#{''.uniquify[0..8]}"
  end

  def assert_false(condition)
    refute condition
  end

  def login(user_or_identifier, &block)
    user = user_or_identifier.respond_to?(:email) ? user_or_identifier : user_named(user_or_identifier)
    User.current = user
    session = set_session({login: user.login})
    user.update_last_login
    if block_given?
      yield(user, session)
      logout_as_nil
    end
    user
  end

  def set_session(data)
    session = nil
    if defined?(cookies)
      session = MingleSession.create(:session_id => SecureRandom.hex(16).encode!('UTF-8').uniquify, :data => data)
      cookies[MINGLE_SESSION_ID] = session.session_id
    end
    session
  end

  def logout_as_nil
    User.current = nil
    cookies[:mingle_current_session_id] = nil if defined?(cookies)
  end

  def login_as_admin
    login('admin@email.com')
  end

  def setup_session(data)
    if defined?(cookies)
      session = MingleSession.find_by_session_id(cookies[MINGLE_SESSION_ID])
      raise 'User not logged in. No session to setup!!' unless session
      session.data.merge!(data)
      session.save
    end
  end

  def user_named(identifier)
    user = User.find_by_email(identifier) || User.find_by_name(identifier) || User.find_by_login(identifier)
    assert_not_nil user, "user doesn't exist, you might have forgotten to load fixtures for login [#{identifier}]"
    user
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

  def for_postgresql
    yield if self.class.postgresql?
  end

  def self.postgresql?
    configs = ActiveRecord::Base.configurations[Rails.env]
    configs['adapter'] =~ /postgresql/ || (configs['adapter'] =~ /jruby|jdbc/ && configs['driver'] =~ /postgresql/)
  end

  def assert_include(included, content, message = '')
    assert content.include?(included), "#{content.inspect} \n\nshould contain #{included.inspect}, but not. #{message}"
  end

  def freeze_time(&block)
    travel_to(Time.now, &block)
  end

  def icon_file_path(file_name)
    File.join(Rails.root, 'test', 'data', 'icons', file_name)
  end
end
