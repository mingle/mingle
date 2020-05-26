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

class SysadminControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller(SysadminController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @admin = login_as_admin
    @admin.update_attribute(:system, true)
  end

  def teardown
    Multitenancy.clear_tenants
    MingleConfiguration.global_config_store.clear
    DualAppRoutingConfig.clear
  end

  def test_index
    get :index
    assert_response :ok
    assert_select 'li > a', 'Data Fixes'
  end

  def test_update_mingle_configuration
    Multitenancy.add_tenant('hello', "database_username" => current_schema)
    Multitenancy.activate_tenant('hello') do
      post :update_mingle_configuration, :name => 'debug', :value => 'true'
      assert_redirected_to :action => 'tenant_configuration'
    end
    Multitenancy.activate_tenant('hello') do
      assert MingleConfiguration.debug?
    end
  end

  def test_delete_mingle_configuration
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do
      assert MingleConfiguration.debug?

      post :delete_mingle_configuration, :name => 'debug'
      assert_redirected_to :action => 'tenant_configuration'
    end
    Multitenancy.activate_tenant('hello') do
      assert !MingleConfiguration.debug?
    end
  end

  def test_update_twitter_notification
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do
      post :update_tenant_user_notification,
        :user_notification_heading => "news flash",
        :user_notification_avatar => "avatar.png",
        :user_notification_body => "beta testing",
        :user_notification_url => "http://www.com",
        :tweet_message => "Tweet this!",
        :tweet_url => "http://foo.com"
      assert_redirected_to :action => 'tenant_configuration'
    end

    Multitenancy.activate_tenant('hello') do
      assert_not_nil MingleConfiguration.tweet_message
      assert_not_nil MingleConfiguration.tweet_url
      assert_equal "Tweet this!", MingleConfiguration.tweet_message
      assert_equal "http://foo.com", MingleConfiguration.tweet_url
    end
  end

  def test_update_and_delete_tenant_user_notification
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do
      post :update_tenant_user_notification,
        :user_notification_heading => "news flash",
        :user_notification_avatar => "avatar.png",
        :user_notification_body => "beta testing",
        :user_notification_url => "http://www.com"

      assert_redirected_to :action => 'tenant_configuration'
    end

    Multitenancy.activate_tenant('hello') do
      assert_equal "news flash", MingleConfiguration.user_notification_heading
      assert_equal "avatar.png", MingleConfiguration.user_notification_avatar
      assert_equal "beta testing", MingleConfiguration.user_notification_body
      assert_equal "http://www.com", MingleConfiguration.user_notification_url
    end

    Multitenancy.activate_tenant('hello') do
      post :delete_tenant_user_notification
      assert_redirected_to :action => 'tenant_configuration'
    end

    Multitenancy.activate_tenant('hello') do
      assert MingleConfiguration.user_notification_heading.blank?
      assert MingleConfiguration.user_notification_avatar.blank?
      assert MingleConfiguration.user_notification_body.blank?
      assert MingleConfiguration.user_notification_url.blank?
    end
  end

  def test_update_global_configuration
    post :update_global_configuration, :name => 'debug', :value => 'true'
    assert_redirected_to :action => 'global_configuration'
    debug = false
    middleware = GlobalConfigManagement
    config = middleware.new(lambda do |env|
                              debug = MingleConfiguration.debug
                            end)
    config.call({})
    assert_equal true, debug
  end

  def test_global_configuration_should_not_be_cached_with_app_namespace
    post :update_global_configuration, :name => 'debug', :value => 'hello'
    assert_equal 'hello', MingleConfiguration.global_config['debug']
    MingleConfiguration.with_app_namespace_overridden_to('hello-ns') do
      assert_equal 'hello', MingleConfiguration.global_config['debug']
    end

    MingleConfiguration.with_app_namespace_overridden_to('app-namespace') do
      post :update_global_configuration, :name => 'debug', :value => 'world'
    end
    assert_equal 'world', MingleConfiguration.global_config['debug']
    MingleConfiguration.with_app_namespace_overridden_to('hello-ns') do
      assert_equal 'world', MingleConfiguration.global_config['debug']
    end
  end

  def test_update_and_delete_global_user_notification
    MingleConfiguration.overridden_to(:multitenancy_mode => true, :saas_env => "test") do
      post :update_global_user_notification,
        :user_notification_heading => "news flash",
        :user_notification_avatar => "avatar.png",
        :user_notification_body => "beta testing",
        :user_notification_url => "http://www.com",
        :tweet_message => "Tweet this!",
        :tweet_url => "http://foo.com"

      assert_redirected_to :action => 'global_configuration'

      middleware = GlobalConfigManagement
      config = middleware.new(lambda do |env|
        assert_equal "news flash", MingleConfiguration.user_notification_heading
        assert_equal "avatar.png", MingleConfiguration.user_notification_avatar
        assert_equal "beta testing", MingleConfiguration.user_notification_body
        assert_equal "http://www.com", MingleConfiguration.user_notification_url
        assert_equal "Tweet this!", MingleConfiguration.tweet_message
        assert_equal "http://foo.com", MingleConfiguration.tweet_url
      end)
      config.call({})

      post :delete_global_user_notification
      assert_redirected_to :action => 'global_configuration'

      config = middleware.new(lambda do |env|
        assert MingleConfiguration.user_notification_heading.blank?
        assert MingleConfiguration.user_notification_avatar.blank?
        assert MingleConfiguration.user_notification_body.blank?
        assert MingleConfiguration.user_notification_url.blank?
        assert MingleConfiguration.tweet_message.blank?
        assert MingleConfiguration.tweet_url.blank?
      end)
      config.call({})

      post :update_global_user_notification, :user_notification_url => "http://www.com"

      assert_equal flash[:error], "Heading is required. Content is required."
      assert_redirected_to :action => 'global_configuration'

      config = middleware.new(lambda do |env|
        assert MingleConfiguration.user_notification_heading.blank?
        assert MingleConfiguration.user_notification_avatar.blank?
        assert MingleConfiguration.user_notification_body.blank?
        assert MingleConfiguration.user_notification_url.blank?
        assert MingleConfiguration.tweet_message.blank?
        assert MingleConfiguration.tweet_url.blank?
      end)
      config.call({})
    end
  end

  def test_memcache_client_benchmarking
    get :memcache_client_benchmarking, :seconds => 0
    assert_response :ok
  end

  def test_update_dual_routing_should_disable_routing_when_specified
    DualAppRoutingConfig.expects(:disable_routing)

    post :update_dual_routing, :commit => 'Disable'

    assert_redirected_to action: :dual_routing_toggle
  end

  def test_update_dual_routing_should_enable_routing_when_specified
    DualAppRoutingConfig.expects(:enable_routing)

    post :update_dual_routing, :commit => 'Enable'

    assert_redirected_to action: :dual_routing_toggle
  end

  def test_sysadmin_should_be_able_to_toggle_show_all_projects_admins
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do

      SysadminController.any_instance.expects(:sysadmin_only).never

      post :toggle_show_all_project_admins,
           :show_all_project_admins => true

      assert_response :success

      Multitenancy.activate_tenant('hello') do
        assert MingleConfiguration.show_all_project_admins?
      end
    end
  end

  def test_mingle_admin_should_be_able_to_toggle_show_all_projects_admins
    @admin.update_attribute(:admin, true)
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do

      SysadminController.any_instance.expects(:sysadmin_only).never

      post :toggle_show_all_project_admins,
           :show_all_project_admins => true

      assert_response :success

      Multitenancy.activate_tenant('hello') do
        assert MingleConfiguration.show_all_project_admins?
      end
    end
  end

  def test_normal_user_should_not_be_able_to_toggle_show_all_projects_admins
    login_as_member
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do

      assert_raises ErrorHandler::UserAccessAuthorizationError do
        post :toggle_show_all_project_admins, :show_all_project_admins => true
      end

      Multitenancy.activate_tenant('hello') do
        assert_false MingleConfiguration.show_all_project_admins?
      end
    end
  end

  def test_should_export_project_admins_list_as_csv_file
    Multitenancy.add_tenant('hello', "database_username" => current_schema, 'mingle.config.debug' => 'true')
    Multitenancy.activate_tenant('hello') do

    get :export_project_names_with_their_admins_in_csv
    assert_response :success
    assert_equal "filename=\"project_admins.csv\"", @response.headers['Content-Disposition']
    assert_equal 'text/csv; charset=utf-8', @response.headers['Content-Type']
    end
  end

  private

  def current_schema
    ActiveRecord::Base.configurations['test']['username']
  end
end
