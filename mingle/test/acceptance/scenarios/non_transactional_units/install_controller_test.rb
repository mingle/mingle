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

require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')
require 'install_controller'
# move this test to acceptance, because this test need to destroy all users and projects and install controller will reconnect database,
# which would be hard for running this test in multi-processes
# Tags: non-transactional-units, project, install
class InstallControllerTest < ActionController::TestCase
  def setup
    @controller = InstallController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    FileUtils.touch(SITE_URL_CONFIG_FILE)
    logout_as_nil
    destroy_all_records(:destroy_users => true, :destroy_projects => true)
    License.destroy_all
  end

  def teardown
    FileUtils.rm_f(SITE_URL_CONFIG_FILE)
    register_license
    License.eula_accepted
  end

  def test_turn_off_install_controller
    FEATURES.deactivate('install')
    get :index
    assert_response :not_found
  ensure
    FEATURES.activate('install')
  end

  def test_show_welcome_page_when_smtp_not_configured
    old_smtp_config_file = SMTP_CONFIG_YML

    Constant.set('const' => "SMTP_CONFIG_YML", 'value' => "unknown_file.yml")
    License.eula_accepted
    User.create! :login => "first_user", :email => "first_user@email.com", :name => "first_user@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1.", :admin => true
    change_license_to_allow_anonymous_access
    get :index
    assert_response :success
    assert_select 'h1', :text => 'Welcome to Mingle!'
  ensure
    Constant.set('const' => "SMTP_CONFIG_YML", 'value' => old_smtp_config_file)
  end

  def test_signup_should_not_redirect_to_saas_tos
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      get :signup
      assert_response :success
    end
  end

  def test_show_register_license_when_license_is_blank
    License.eula_accepted
    User.create! :login => "first_user", :email => "first_user@email.com", :name => "first_user@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1.", :admin => true
    get :index
    assert_response :success
    assert_select 'h1', :text => 'Welcome to Mingle!'
  end

  def test_redirect_to_root_url_when_license_is_valid
    License.eula_accepted
    User.create! :login => "first_user", :email => "first_user@email.com", :name => "first_user@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1.", :admin => true
    change_license_to_allow_anonymous_access
    get :index
    assert_redirected_to root_url
  end

  def test_signup_only_for_the_first_user_who_register
    License.eula_accepted

    get :signup
    assert_select 'input', :type => 'submit', :value => /Set up this account/
    assert_select 'form', :action => '/install/do_signup'

    post :do_signup, :user => { :login => "first_user", :email => "first_user@email.com", :name => "first_user@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1." }
    assert(@response.has_session_object?(:login))
    assert_nil flash[:notice]

    get :signup
    assert_response :redirect
    assert_redirected_to :action => "register_license"
  end

  def test_register_license_should_redirect_to_registration_when_license_is_blank
    License.eula_accepted
    post :do_signup, :user => { :login => "admin", :email => "admin@email.com", :name => "admin@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1." }

    get :register_license
    assert_response :success
    assert_select 'form', :action => '/install/do_register_license'
    assert_select "a", :text => /Register later/, :href => '/projects'
  end

  def test_register_license_should_redirect_to_root_url_when_license_is_valid
    License.eula_accepted
    post :do_signup, :user => { :login => "admin", :email => "admin@email.com", :name => "admin@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1." }

    license_key = {:licensee => 'bobo', :expiration_date => '2100-12-30', :max_active_users => 1000, :max_light_users => 1000}.to_query
    post :do_register_license, :licensed_to  => 'bobo', :license_key => license_key

    assert_redirected_to root_url
    assert CurrentLicense.present?

    get :register_license
    assert_response :redirect
    assert_redirected_to root_url
  end

  def test_do_signup_should_create_last_login_at_for_user
    License.eula_accepted
    post :do_signup, :user => { :login => "new_admin", :email => "new_admin@email.com", :name => "new_admin@email.com", :password => "newpassword1.", :password_confirmation => "newpassword1." }
    assert_not_nil User.find_by_login('new_admin').login_access.last_login_at
  end

  def test_register_invalid_license_should_keep_user_at_register_license_page
    post :do_register_license, :licensed_to  => 'bobo', :license_key => "Invalid license key"
    assert_template :register_license
    assert CurrentLicense.blank?
    assert_select "div#error",{:html => 'License data is invalid'}
  end

  def test_show_configure_site_url_with_suggested_default_site_url
    requires_jruby do
      old_site_url = MingleConfiguration.site_url
      begin
        java.lang.System.setProperty('mingle.siteURL', '')
        get :configure_site_url
        assert_response :success
        assert_select 'form'
        assert_select "input#site_url[value='http://test.host']"
        assert_select 'input#secure_site_url'
      ensure
        java.lang.System.setProperty('mingle.siteURL', old_site_url)
      end
    end
  end

  def test_site_url_should_be_prepopulated_with_legacy_smtp_site_url_when_it_exists
    requires_jruby do
      old_smtp_config_file = SMTP_CONFIG_YML
      old_site_url = MingleConfiguration.site_url
      begin
        java.lang.System.setProperty('mingle.siteURL', '')
        MingleConfiguration.smtp_config_yml_path = File.join(Rails.root, 'test', 'data', 'test_config', 'test_smtp_config_with_legacy_site_url.yml')
        get :configure_site_url
        assert_select "input#site_url[value='http://site.url.from.smtp']", :count => 1
      ensure
        java.lang.System.setProperty('mingle.siteURL', old_site_url)
        Constant.set('const' => "SMTP_CONFIG_YML", 'value' => old_smtp_config_file)
        MingleConfiguration.smtp_config_yml_path = old_smtp_config_file
      end
    end
  end

  def test_show_secure_site_url_when_no_site_url_but_secure_site_url_exists
    requires_jruby do
      old_secure_site_url = MingleConfiguration.secure_site_url
      old_site_url = MingleConfiguration.site_url
      begin
        java.lang.System.setProperty('mingle.siteURL', '')
        java.lang.System.setProperty('mingle.secureSiteURL', 'https://secure.site.url')
        get :configure_site_url
        assert_select "input#secure_site_url[value='https://secure.site.url']", :count => 1
      ensure
        java.lang.System.setProperty('mingle.secureSiteURL', old_secure_site_url)
        java.lang.System.setProperty('mingle.siteURL', old_site_url)
      end
    end
  end

  def test_do_configure_site_url
    with_reset_site_url do
      post :do_configure_site_url, :site_url => 'http://bill.awesome.com'
      assert_equal 'http://bill.awesome.com', MingleConfiguration.site_url
      assert_select 'div.field_error', :count => 0
    end
  end

  def test_do_configure_site_url_with_secure_site_url
    with_reset_site_url do
      post :do_configure_site_url, :site_url => 'http://bill.awesome.com', :secure_site_url => 'https://bill.awesome.org'
      assert_equal 'https://bill.awesome.org', MingleConfiguration.secure_site_url
    end
  end

  def test_do_configure_site_url_should_redirect_to_set_smtp_when_success
    with_reset_site_url do
      post :do_configure_site_url, :site_url => 'http://bill.awesome.com'
      assert_redirected_to :action => :configure_smtp
    end
  end

  def test_do_configure_site_url_should_validate_secure_site_url
    with_reset_site_url do
      post :do_configure_site_url, :site_url => 'http://bill.awesome.com', :secure_site_url => 'http://bill.awesome.org'
      assert_select 'div.field_error', :text => /Invalid protocol/
    end
  end

  def test_do_configure_site_url_should_stay_on_the_same_page_when_invalid_site_url
    requires_jruby do
      with_reset_site_url do
        post :do_configure_site_url, :site_url => 'balbla'
        assert_select 'div.field_error', :text => /Invalid/
      end
    end
  end

  def test_do_configure_site_url_should_show_both_error_messages_for_invalid_site_url_and_invalid_secure_site_url
    with_reset_site_url do
      post :do_configure_site_url, :site_url => '', :secure_site_url => 'http://bill.awesome.org'
     assert_select 'div.field_error', :count => 2
    end
  end

  def test_skip_smtp_config_should_create_an_empty_config_if_it_does_not_exist
    with_smtp_config(nil) do
      assert !File.exists?(SMTP_CONFIG_YML)
      get :skip_configure_smtp
      assert File.exists?(SMTP_CONFIG_YML)
    end
  end

  def test_skip_smtp_config_should_not_overwrite_existing_config
    with_smtp_config('smtp_settings' => {'user' => 'xli'}) do
      content = File.read(SMTP_CONFIG_YML)
      assert content.length > 0
      get :skip_configure_smtp
      assert_equal content, File.read(SMTP_CONFIG_YML)
    end
  end

  def with_smtp_config(config, &block)
    FileUtils.mv(SMTP_CONFIG_YML, "#{SMTP_CONFIG_YML}.bak") if File.exists? SMTP_CONFIG_YML
    if config
      SmtpConfiguration.create(config)
    end
    block.call
  ensure
    FileUtils.mv("#{SMTP_CONFIG_YML}.bak", SMTP_CONFIG_YML) if File.exists? "#{SMTP_CONFIG_YML}.bak"
  end

  def test_shows_eula
    post :eula
    assert_tag :p, :content => /End User License Agreement/

    post :eula_accepted
    assert License.eula_accepted?

    post :eula
    assert_redirected_to :action => 'signup'

    create_user!

    post :eula
    assert_response :redirect
  end

  def test_connect_page_changes_labels_depending_on_selected_database_type
    begin
      ActiveRecord::Base.remove_connection
      get :connect, :database_type => 'Oracle'
      assert_select 'label[for="config_host"]', :text => /Machine name/
      assert_select 'label[for="config_port"]', :text => /Listener port/
      assert_select 'label[for="config_database"]', :text => /Database instance name/
      assert_select 'label[for="config_username"]', :text => /Username/

      get :connect, :database_type => 'PostgreSQL'
      assert_select 'label[for="config_host"]', :text => /Database host/
      assert_select 'label[for="config_port"]', :text => /Database port/
      assert_select 'label[for="config_database"]', :text => /Database name/
      assert_select 'label[for="config_username"]', :text => /Database username/
    ensure
      ActiveRecord::Base.establish_connection
    end
  end

  def test_field_errors_on_connect_page_should_use_database_specific_terminology
    post :do_connect, :database_type => 'PostgreSQL', :config => { :host => '', :port => '1111', :database => 'mingle', :username => 'mingle_user', :password => 'hi'}, :commit => "Test connection and continue ?"
    assert_select 'div.field_error', /Database host can.*t be blank/
    post :do_connect, :database_type => 'Oracle', :config => { :host => '', :port => '1111', :database => 'mingle', :username => 'mingle_user', :password => 'hi'}, :commit => "Test connection and continue ?"
    assert_select 'div.field_error', /Machine name can.*t be blank/

    post :do_connect, :database_type => 'PostgreSQL', :config => { :host => 'localhost', :port => '1111', :database => '', :username => 'mingle_user', :password => 'hi'}, :commit => "Test connection and continue ?"
    assert_select 'div.field_error', /Database name can.*t be blank/
    post :do_connect, :database_type => 'Oracle', :config => { :host => 'localhost', :port => '1111', :database => '', :username => 'mingle_user', :password => 'hi'}, :commit => "Test connection and continue ?"
    assert_select 'div.field_error', /Database instance name can.*t be blank/

    post :do_connect, :database_type => 'PostgreSQL', :config => { :host => 'localhost', :port => '1111', :database => 'mingle', :username => '', :password => 'hi'}, :commit => "Test connection and continue ?"
    assert_select 'div.field_error', /Database username can.*t be blank/
    post :do_connect, :database_type => 'Oracle', :config => { :host => 'localhost', :port => '1111', :database => 'mingle', :username => '', :password => 'hi'}, :commit => "Test connection and continue ?"
    assert_select 'div.field_error', /Username can.*t be blank/
  end

  def test_oracle_config_screen_requires_password_but_postgresql_one_does_not
    begin
      ActiveRecord::Base.remove_connection
      get :connect, :database_type => 'PostgreSQL'
      assert_select 'label[for="config_password"]' do
        assert_select 'span.required', :count => 0
      end

      get :connect, :database_type => 'Oracle'
      assert_select 'label[for="config_password"]' do
        assert_select 'span.required', :text => '*'
      end

      post :do_connect, :database_type => 'Oracle', :config => { :host => 'localhost', :port => '1111', :database => 'mingle', :username => 'whoa', :password => ''}, :commit => "Test connection and continue ?"
      assert_response :ok
      assert_select 'div.field_error', /Password can.*t be blank/

    ensure
      ActiveRecord::Base.establish_connection
    end

  end

end
