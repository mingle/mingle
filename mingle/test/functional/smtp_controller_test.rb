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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class SmtpControllerTest < ActionController::TestCase

  module ControllerMixin
    def config_file_name=(name)
      @config_file_name = name
    end

    def config_file_name
      @config_file_name
    end
  end

  def setup
    @controller = create_controller(SmtpController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @defaults = Configuration::Default.new("settings", 'domain', 'port', 'user_name', 'password', 'address')
    @old_site_uri = MingleConfiguration.site_url
    login_as_admin
  end

  def teardown
    MingleConfiguration.site_url = @old_site_uri
    File.delete(@stub_smtp_config) if @stub_smtp_config
  end

  def test_should_update_existing_smtp_configuration
    generate_stub_smtp_config
    post :update, :smtp_settings => {'domain' => 'booya.com', 'port' => '25'}

    assert_equal 'booya.com', ActionMailer::Base.smtp_settings[:domain]
    assert_equal 25, ActionMailer::Base.smtp_settings[:port]
  end

  def test_should_convert_string_false_to_boolean_false_when_update_existing_smtp_configuration
    generate_stub_smtp_config

    post :update, :smtp_settings => {'domain' => 'booya.com', 'port' => '25', 'tls' => 'true'}
    assert_equal true, ActionMailer::Base.smtp_settings[:tls]

    post :update, :smtp_settings => {'domain' => 'booya.com', 'port' => '25', 'tls' => 'false'}
    assert_nil ActionMailer::Base.smtp_settings[:tls]
  end

  def test_should_update_existing_smtp_configuration_correctly_if_fields_are_left_blank_after_saving_valid_values
    generate_stub_smtp_config

    MingleConfiguration.site_url = 'http://example.com:8080'
    post :update, :smtp_settings => {'address' => 'localhost', 'domain' => 'localhost.localdomain', 'port' => '25'},
                  :sender => {'name' => 'Mingle', 'address' => 'a@b.com'}

    assert_equal({:host => 'example.com', :port => 8080, :protocol => 'http', :only_path=>false}, MingleConfiguration.site_url_as_url_options)

    post :update, :smtp_settings => {'address' => '', 'domain' => '', 'port' => '', 'user_name' => '', 'password' => ''},
                  :sender => {'name' => '', 'address' => ''}

    follow_redirect
    assert_select "input[id=smtp_settings_address]:not([value])"
    assert_select "input[id=smtp_settings_port]:not([value])"
    assert_select "input[id=smtp_settings_domain]:not([value])"
    assert_select "input[id=smtp_settings_user_name]:not([value])"
    assert_select "input[id=smtp_settings_password]:not([value])"
    assert_select "input[id=sender_name]:not([value])"
    assert_select "input[id=sender_address]:not([value])"
  end

  def test_should_set_authentication_to_plain_if_either_user_or_password_are_provided
    generate_stub_smtp_config
    post :update, :smtp_settings => {'domain' => 'booya.com', 'port' => '25', 'user' => 'smtp_admin', 'password' => 'pass123.'}

    assert_equal 'booya.com', ActionMailer::Base.smtp_settings[:domain]
    assert_equal 25, ActionMailer::Base.smtp_settings[:port]
    assert_equal 'plain', ActionMailer::Base.smtp_settings[:authentication]
  end

  def test_should_get_success_when_testing_valid_settings
    get :test, '__verify_delivery' => true, 'smtp_settings' => {'address' => 'localhost', 'domain' => 'localhost.localdomain', 'port' => '25'}, 'sender' => {'name' => 'Mingle', 'address' => 'a@b.com'}

    assert_notice "<ul><li>Successfully delivered mail.</li><li>Check your email to confirm that the mail was received. (This may take a minute or two to arrive).</li><li><b>Note</b>: You must save these settings to make them permanent.</li></ul>"
  end

  def test_should_get_useful_error_message_when_smtp_settings_are_invalid
    get :test, 'smtp_settings' => {'address' => nil, 'domain' => 'localhost.localdomain', 'port' => '25'}, 'sender' => {'name' => 'Mingle', 'address' => 'a@b.com'}

    assert_error "<b>SMTP server address</b> must be provided to test SMTP settings."
  end

  private

  def generated_stub_config_file_name
    RailsTmpDir.file_name('test', "#{Time.now.to_i.to_s}_#{Process.pid.to_s}_test_smtp_config.yml")
  end

  def generate_stub_smtp_config
    @stub_smtp_config = generated_stub_config_file_name
    @controller.extend(ControllerMixin)
    @controller.config_file_name = @stub_smtp_config
    FileUtils.mkpath(File.dirname(@stub_smtp_config))
  end
end
