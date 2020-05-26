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

# Tags: multitenancy
class BackgroundJobTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    # Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    @tenant_config_namespace = UUID.generate(:compact)
    # add an invalid db connection pool, all test should work well
    # with it
    ActiveRecordPartitioning.with_connection_pool(:url => 'invalid partition2 url')
  end

  def teardown
    Multitenancy.clear_activerecord_connection_pools
    # Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
  end

  def test_background_job_should_process_messages_for_all_tenants
    with_tenant('site1') do |t|
      UnitTestDataLoader.new.run('first_project')

      with_first_project do |project|
        Messaging::Mailbox.transaction do
          card = project.cards.create!(:name => 'card1', :card_type_name => 'Card')
          assert !card.versions.last.event.history_generated?
        end
      end
    end

    with_tenant('site2') do |t|
      UnitTestDataLoader.new.run('first_project')

      with_first_project do |project|
        Messaging::Mailbox.transaction do
          card = project.cards.create!(:name => 'card1', :card_type_name => 'Card')
          assert !card.versions.last.event.history_generated?
        end
      end
    end

    BackgroundJob.new(lambda { HistoryGeneration.run_once }).run_once

    with_tenant('site1') do
      with_first_project do |p|
        assert p.cards.find_by_name('card1').versions.last.event.history_generated?
      end
    end

    with_tenant('site2') do
      with_first_project do |p|
        assert p.cards.find_by_name('card1').versions.last.event.history_generated?
      end
    end
  end

  def test_import_project_with_upgrade
    # can't use overridden_to because it only writes to thread-local; use setter to actually set property
    # so it can propagate to project import, and resolve the correct site
    MingleConfiguration.tenant_config_dynamodb_table = @tenant_config_namespace

    with_tenant('site1') do
      export_file = UnitTestDataLoader.uploaded_file("#{Rails.root}/test/data/2_2_exported_project.mingle", nil, "application/octet-stream")

      Messaging::Mailbox.transaction do
        ProjectImportPublisher.new(User.first_admin, 'p2_2', 'p2_2').publish_message(export_file)
      end
    end

    BackgroundJob.new(lambda { ProjectImportProcessor.run_once(:batch_size => 100) }).run_once

    with_tenant('site1') do
      assert Project.find_by_identifier('p2_2')
    end
  ensure
    MingleConfiguration.tenant_config_dynamodb_table = nil
  end

  def with_tenant(name, &block)
    create_tenant(name) unless Multitenancy.tenant_exists?(name)
    Multitenancy.activate_tenant(name, &block)
  end

  def create_tenant(name)
    TenantInstallation.create_tenant(name, valid_site_setup_params)
  end

  def valid_site_setup_params
    {
      :first_admin => {
        :login => "admin",
        :name => "Admin User",
        :email => "email@exmaple.com"
      },
      :license => valid_license
    }
  end

  def drop_tenant(name)
    TenantInstallation.destroy_tenant(name)
  end

  def with_first_project(&block)
    project = Project.find_by_identifier("first_project")
    project.with_active_project(&block)
  end
end
