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

class SmtpConfigurationTest < ActiveSupport::TestCase

  def setup
    ActionMailer::Base.smtp_settings = {}
    @defaults = Configuration::Default.new("settings", 'domain', 'port', 'user_name', 'password', 'address')
    @smtp_config_file = RailsTmpDir.file_path('test') << unique_name('smtp_config') << ".yml"
    SmtpConfiguration.create valid_settings_params, @smtp_config_file
    @member = login_as_member
    @old_site_uri = MingleConfiguration.site_url
  end

  def teardown
    MingleConfiguration.site_url = @old_site_uri
    File.delete(@smtp_config_file) if File.exist?(@smtp_config_file)
  end

  def test_evaluates_erb
    java.lang.System.setProperty('SMTP_ADDRESS', 'SMTP_ADDRESS')
    config = File.join(Rails.root, 'test', 'data', 'test_config', 'smtp_config.yml.erb')
    SmtpConfiguration.load(config)
    assert_equal 'SMTP_ADDRESS', ActionMailer::Base.smtp_settings[:address]
  ensure
    java.lang.System.clearProperty('SMTP_ADDRESS')
  end

  def test_can_read_values_of_commented_properties
    assert_equal '', @defaults['domain']
    assert_equal '', @defaults[:domain]
  end

  def test_should_merge_new_values_into_existing_values_without_losing_defaults
    @defaults['domain'] = 'thoughtworks.com'
    assert_equal({"domain" => 'thoughtworks.com', "#port" => '', "#user_name" => '', "#password" => '', "#address" => ""}, @defaults.settings)
  end

  def test_should_merge_new_values_without_treating_ip_address_strings_as_integers
    @defaults['address'] = '192.168.0.125'
    assert_equal({"address" => '192.168.0.125', "#domain" => "", "#port" => '', "#user_name" => '', "#password" => ''}, @defaults.settings)
  end

  def test_should_be_able_to_merge_uncommented_values_into_settings
    @defaults['domain'] = 'thoughtworks.com'
    @defaults['domain'] = 'mingle.com'
    assert_equal({"domain" => 'mingle.com', "#port" => '', "#user_name" => '', "#password" => '', "#address" => ""}, @defaults.settings)
  end

  def test_automatically_converts_numeric_values_into_numbers
    @defaults['port'] = '587'
    assert_equal 587, @defaults["port"]
  end

  def test_can_merge_multiple_values_into_defaults
    @defaults.merge('domain' => 'google.com', 'port' => '587')
    assert_equal({"domain" => 'google.com', "port" => 587, "#user_name" => '', "#password" => '', "#address" => ""}, @defaults.settings)
  end

  def test_to_yaml_returns_same_values_as_to_hash
    @defaults.merge('domain' => 'google.com', 'port' => '587')
    assert_equal({"settings" => {"domain" => 'google.com', "port" => 587, "#user_name" => '', "#password" => '', "#address" => ""}}, @defaults.to_hash)
  end

  def test_smtp_configuration_after_setting_selected_values
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    SmtpConfiguration.create({'smtp_settings' => {'address' => '192.168.1.2', 'domain' => 'boo.com', 'port' => '52'}}, @smtp_config_file)
    expected_settings = {:address => '192.168.1.2', :domain => 'boo.com', :port => 52}
    expected_settings.each do |key, value|
      assert_equal value, ActionMailer::Base.smtp_settings[key]
    end
  end

  def test_should_allow_for_setting_of_protocol_host_and_port_options
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    MingleConfiguration.site_url = 'https://mingle.yourcompany.com:557'
    SmtpConfiguration.create({}, @smtp_config_file)
    assert_equal({:only_path => false, :protocol=>"https", :port=>557, :host=>"mingle.yourcompany.com"}, MingleConfiguration.site_url_as_url_options)
  end

  def test_should_ignore_default_port_value
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))

    MingleConfiguration.site_url = 'http://mingle.yourcompany.com'
    SmtpConfiguration.create({}, @smtp_config_file)
    assert !MingleConfiguration.site_url_as_url_options.has_key?(:port)

    MingleConfiguration.site_url = 'https://mingle.yourcompany.com'
    SmtpConfiguration.create({}, @smtp_config_file)
    assert !MingleConfiguration.site_url_as_url_options.has_key?(:port)

    MingleConfiguration.site_url = 'http://mingle.yourcompany.com:443'
    SmtpConfiguration.create({}, @smtp_config_file)
    assert 443, MingleConfiguration.site_url_as_url_options[:port]
  end

  def test_should_clear_out_port_option_when_have_a_ignore_port_value
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    MingleConfiguration.site_url = 'https://mingle.yourcompany.com'
    SmtpConfiguration.create({}, @smtp_config_file)
    assert !MingleConfiguration.site_url_as_url_options.has_key?(:port)
  end

  def test_load_smtp_configuration
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))

    assert SmtpConfiguration.configured?
  end

  def test_smtp_configuration_should_be_resilient_to_bad_yaml_content
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    File.open(@smtp_config_file, 'w') do |io|
      io << "cl: as: s F:oo :< A:ctiv:eRecord::Base\n"
      io << "  #de: f bar\n   p 'b: ar'\n  end\n"
      io << "en: d"
    end

    assert !SmtpConfiguration::load(@smtp_config_file)
  end

  def test_should_convert_nested_yaml_hash_to_flattened_ui_hash
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    SmtpConfiguration.create({'smtp_settings' => {'domain' => 'booya.com', 'port' => '25'}}, @smtp_config_file)
    configuration = SmtpConfiguration.new(@smtp_config_file)
    assert_equal 'booya.com', configuration.smtp_settings.domain
    assert_equal 25, configuration.smtp_settings.port
  end

  def test_sender_name_can_contain_yaml_invalid_chars_but_quoted
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    SmtpConfiguration.create valid_settings_params.merge({ 'sender' => { 'name' => 'Mingle: MingleUser', 'address' => 'a@b.com' } }), @smtp_config_file, true
    assert_equal true, SmtpConfiguration.load(@smtp_config_file)
    assert_equal 'Mingle: MingleUser', YAML.load_file(@smtp_config_file)['sender']['name']
  end

  def test_yaml_entries_should_not_contain_unnecessary_new_line_chars
    yaml_entry = Configuration::Default::Sender.send(:convert_setting_to_yaml_entry, 'name', "Mingle: MingleUser")
    assert yaml_entry =~ /name: ["']Mingle: MingleUser["']/
  end

  def test_should_test_false_if_minimal_smtp_settings_not_present
    assert_equal [], SmtpConfiguration.test(valid_settings_params)
    assert_equal ["#{'SMTP server address'.bold} and #{'SMTP server port'.bold} must be provided to test SMTP settings."],
                 SmtpConfiguration.test(valid_settings_params.merge('smtp_settings' => nil))
    assert_equal ["#{'SMTP server address'.bold} must be provided to test SMTP settings."],
                 SmtpConfiguration.test(valid_settings_params.merge('smtp_settings' => {'domain' => 'booya.com', 'port' => '25'}))
    assert_equal ["#{'SMTP server port'.bold} must be provided to test SMTP settings."],
                 SmtpConfiguration.test(valid_settings_params.merge('smtp_settings' => {'address' => '192.168.1.2', 'domain' => 'booya.com'}))
  end

  # bug 6621
  def test_should_give_proper_error_message_when_logged_in_user_does_not_have_email_address
    @member.update_attribute :email, nil
    assert_equal ['Unable to test email settings. Please go to your profile page to specify an email address and try again.'], SmtpConfiguration.test(valid_settings_params)
  end

  def test_should_not_change_smtp_settings_when_sending_test_email
    old_smtp_settings = ActionMailer::Base.smtp_settings
    SmtpConfiguration.test(valid_settings_params.merge('smtp_settings' => {'domain' => 'booya.com', 'port' => '25'}))
    assert_equal old_smtp_settings, ActionMailer::Base.smtp_settings
  end

  def test_smtp_is_not_configured_when_config_file_is_not_found
    assert !SmtpConfiguration.configured?("no_exist_file")
  end

  def test_smtp_is_configured_when_site_url_is_set
    FileUtils.mkpath(File.dirname(File.join(@smtp_config_file)))
    ActionMailer::Base.default_url_options = {}

    MingleConfiguration.site_url = 'http://example.com'
    SmtpConfiguration.create({'smtp_settings' => {'domain' => 'booya.com', 'port' => '25'}}, @smtp_config_file)

    assert SmtpConfiguration.configured?(@smtp_config_file)
  end

  protected

  def valid_settings_params
    {'smtp_settings' => {'address' => '192.168.1.2', 'domain' => 'booya.com', 'port' => '25'}, 'sender' => {'name' => 'mingle', 'address' => 'a@b.com'}}
  end
end
