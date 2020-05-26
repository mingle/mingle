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

require File.join(File.dirname(__FILE__), 'test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../messaging/messaging_test_helper')

# Tags: multitenancy, install
class TenantDestructionProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def test_destroy_tenant
    TenantInstallation.create_tenant('sitename', valid_site_setup_params)
    tenant = Multitenancy.find_tenant('sitename')
    schema_name = tenant.schema_name
    assert_equal [schema_name].map(&:downcase), Multitenancy.schemas(schema_name).map(&:downcase) # Oracle does uppercase, Postgres does lowercase. We don't care.

    message = Messaging::SendingMessage.new({:name => 'sitename'})
    TenantDestructionProcessor.process(message, TenantDestructionProcessor.new)
    tenant = Multitenancy.find_tenant('sitename')
    assert_nil tenant
    assert_equal [], Multitenancy.schemas(schema_name)
  end

  def test_should_clear_elastic_search_data_for_site_and_preserve_other_sites_data
    #site name and index name should be unique to prevent random failures
    site_name = "site1".uniquify.delete("_")
    index_name = 'indexthing'.uniquify.delete("_")
    TenantInstallation.create_tenant(site_name, valid_site_setup_params)
    old_config = MingleConfiguration.multitenancy_mode
    MingleConfiguration.multitenancy_mode = nil
    MingleConfiguration.overridden_to(saas_env: nil) do
      set_namespace_and_index(site_name, index_name) do

        ElasticSearch.enable
        start_elastic_search

        ElasticSearch.create_index_with_mappings

        # create ES document for a different site
        MingleConfiguration.with_app_namespace_overridden_to(site_name + "foo") do
          ElasticSearch.reindex('1', {:name => 'card 1', :number => '1'}, index_name, 'cards')
        end

        ElasticSearch.reindex('2', {:name => 'card 2', :number => '2'}, index_name, 'cards')
        ElasticSearch.reindex('55', {:name => 'page 1'}, index_name, 'pages')

        assert ElasticSearch.find_one(index_name, "cards", '2')['found']
        assert ElasticSearch.find_one(index_name, "pages", '55')['found']

        TenantInstallation.destroy_tenant(site_name)

        assert !ElasticSearch.find_one(index_name, "cards", "2")['found']
        assert !ElasticSearch.find_one(index_name, "pages", "55")['found']

        # test that other site's ES documents remain
        MingleConfiguration.with_app_namespace_overridden_to(site_name + "foo") do
          assert ElasticSearch.find_one(index_name, "cards", "1")['found']
        end

        ElasticSearch.disable
        stop_elastic_search
      end

    end
  rescue
    MingleConfiguration.multitenancy_mode = old_config
  end

  def test_should_clear_saas_tos_cache
    TenantInstallation.create_tenant('sitename', valid_site_setup_params)
    tenant = Multitenancy.find_tenant('sitename')
    tenant.activate do
      SaasTos.accept(OpenStruct.new(:email => "foo@bar.com"))
      assert SaasTos.accepted?
      assert Cache.get("saas_tos")
    end

    TenantInstallation.clear_saas_tos_cache(tenant)

    tenant.activate do
      assert !Cache.get("saas_tos")
    end
  end

  def test_tenant_destroy_should_clear_saas_tos_cache
    TenantInstallation.create_tenant('sitename', valid_site_setup_params)
    tenant = Multitenancy.find_tenant('sitename')
    tenant.activate do
      SaasTos.accept(OpenStruct.new(:email => "foo@bar.com"))
      assert SaasTos.accepted?
    end

    message = Messaging::SendingMessage.new({:name => 'sitename'})
    TenantDestructionProcessor.process(message, TenantDestructionProcessor.new)

    TenantInstallation.create_tenant('sitename', valid_site_setup_params)
    tenant = Multitenancy.find_tenant('sitename')

    tenant.activate do
      assert !SaasTos.accepted?
    end
  end

  def valid_site_setup_params
    {
      :first_admin => {
        :name => "Admin User",
        :email => "email@exmaple.com"
      },
      :license => valid_license
    }
  end

  def set_namespace_and_index(site_name, index_name, &block)
    MingleConfiguration.search_namespace = 'true'
    MingleConfiguration.with_app_namespace_overridden_to(site_name) do
      MingleConfiguration.with_search_index_name_overridden_to(index_name) do
        yield block
      end
    end
  end
end
