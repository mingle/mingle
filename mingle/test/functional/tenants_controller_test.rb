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

require File.expand_path(File.dirname(__FILE__) + '/../functional_test_helper')

# tests for create and upgrade action are in acceptance tests
# suite (test/acceptance/scenarios/multitenancy/tenants_controller_test.rb)
# because they need create/migrate databases
class TenantsControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller(TenantsController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    Multitenancy.add_tenant('first', current_db_tenant_config)
    Multitenancy.add_tenant('second', current_db_tenant_config)

    MingleConfiguration.multitenancy_migrator = "true"
    Clock.fake_now(:year => 2008, :month => 7, :day => 12)

  end

  def teardown
    Clock.reset_fake
    Multitenancy.clear_tenants
    MingleConfiguration.multitenancy_migrator = nil
  end

  def dummy_db_url
    'jdbc:oracle:thin:@fmtstdmngdb09.thoughtworks.com:1521:dummy'
  end

  def test_should_block_api_from_non_migrator_nodes
    MingleConfiguration.overridden_to(:multitenancy_migrator => false) do
      [:create, :upgrade, :index].each do |action|
        get action
        assert_response :not_found
      end
    end
  end

  def test_index_return_list_of_tenant_names
    get :index, :format => 'xml'
    assert_response :ok
    assert_equal ['first', 'second'], Hash.from_xml(@response.body)['tenants'].map {|t| t['name'] }
  end

  def test_show_tenant_config_should_include_default_db_url_if_no_db_config_in_tenant_config
    get :show, :name => 'first', :format => 'xml'
    assert_response :ok
    tenant = Hash.from_xml(@response.body)['tenant']
    assert_equal 'first', tenant['name']
    assert_equal ActiveRecordPartitioning.default_config[:url], tenant['db_url']
  end

  def test_show_tenant_config_with_db_url_existing
    Multitenancy.add_tenant('new-site', current_db_tenant_config.merge('db_config' => {'url' => dummy_db_url}))
    get :show, :name => 'new-site', :format => 'xml'
    assert_response :ok
    assert_equal 'new-site', Hash.from_xml(@response.body)['tenant']['name']
    assert_equal dummy_db_url, Hash.from_xml(@response.body)['tenant']['db_url']
  end

  def test_tenant_stats
    Multitenancy.add_tenant('new-site', current_db_tenant_config.merge('db_config' => {'url' => dummy_db_url}))

    get :stats, :format => 'xml'
    assert_response :ok

    stats = Hash.from_xml(@response.body)["stats"].sort_by do |e|
      e['count']
    end
    assert_equal({'db_url' => dummy_db_url, 'count' => '1'}, stats[0])
    assert_equal({'db_url' => ActiveRecordPartitioning.default_config[:url], 'count' => '2'}, stats[1])
  end

  def test_upgrade_no_existing_tenant_will_cause_404
    post :upgrade, :name => 'not-exists-site'
    assert_response :not_found
  end

  def test_get_license_registration_for_a_tenant
    get :license_registration, :name => 'first', :format => 'xml'
    assert_response :ok
    assert_sort_equal ['licensed_to',
                       'edition',
                       'expiration_date',
                       'max_active_full_users',
                       'max_active_light_users',
                       'allow_anonymous',
                       'current_active_users',
                       'activated_light_users',
                       'full_users_used_as_light'], Hash.from_xml(@response.body)['license_registration'].keys
  end

  def test_register_license_with_bad_license_key_response_400
    old_license_key = License.get.license_key
    put :register_license, :name => 'second', :format => 'xml', :license => {:licensed_to => "foobar", :licensed_key => "bad key"}
    assert_response :bad_request
    assert_equal old_license_key, License.get.reload.license_key
  end

  def test_register_license_with_valid_license_key_should_update_license
    old_license_key = License.get.license_key

    put(:register_license, :name => 'second',
        :format => 'xml',
        :license => {
          :licensed_to => "barbobo",
          :license_key => {
            :licensee => 'barbobo',
            :max_active_users => '100000',
            :expiration_date => '2013-03-26',
            :max_light_users => '200',
            :product_edition => Registration::NON_ENTERPRISE}.to_query})
    assert_response :ok
    assert_not_equal old_license_key, License.get.reload.license_key
  end

  def test_validate_checks_for_site_name_duplication
    get :validate, :name => 'doesnt-exist'
    assert_response :ok

    get :validate, :name => 'first'
    assert_response :conflict
  end

  def test_validate_checks_the_site_name_format
    ['a_b', '!ab', '1!ab', 'site name', '  ', '-9'].each do |invalid_name|
      get :validate, :name => invalid_name
      assert_response :bad_request
    end
    ['a-b', 'A-b', 'a-B', 'a--b', '9', '9-9', '9-a'].each do |valid_name|
      get :validate, :name => valid_name
      assert_response :ok
    end
  end

  def test_derive_tenant_name_changes_special_characters_to_hyphens
    get :derive_tenant_name, :company_name => 'hell_o hola.com'
    assert_response :success
    assert_equal "hell-o-hola-com", @response.body
  end

  def test_derive_tenant_name_will_strip_trailing_special_character
    get :derive_tenant_name, :company_name => 'Osito Inc.'
    assert_equal 'osito-inc', @response.body
  end

end
