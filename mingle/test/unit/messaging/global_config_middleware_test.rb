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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class Messaging::GlobalConfigMiddlewareTest < ActiveSupport::TestCase
  include Messaging

  def setup
    @endpoint = InMemoryEndpoint.new
    @middleware = GlobalConfigMiddleware.new(@endpoint)
    MingleConfiguration.global_config_store['config'] = YAML.dump({'mailgun_domain' => 'http://mailgun.com/api/v3', 'running_exports' => {'eiwork' => "22-Aug-2018-07:01 AM UTC", "hello"=>"22-Aug-2018-07:01 AM UTC" }})
  end

  def teardown
    Multitenancy.clear_tenants
  end

  def test_should_override_mingle_configurations_with_global_configs
    @middleware.send_message('queue',[Messaging::SendingMessage.new({:text => 'hello'})])
    @middleware.receive_message('queue') do |msg|
      assert_equal 'http://mailgun.com/api/v3', MingleConfiguration.mailgun_domain
    end
    assert_nil MingleConfiguration.mailgun_domain
  end

  def test_should_update_running_exports_when_an_export_is_triggered
    MingleConfiguration.overridden_to(saas_env: 'test') do
      Multitenancy.add_tenant('hello', "database_username" => current_schema)
      Multitenancy.activate_tenant('hello') do
        SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

        Export.create(status: Export::IN_PROGRESS).start
        running_exports = {}
        middleware = GlobalConfigManagement
        config = middleware.new(lambda do |env|
          running_exports = MingleConfiguration.running_exports
        end)
        config.call({})
        assert_equal "{\"eiwork\"=>\"22-Aug-2018-07:01 AM UTC\", \"hello\"=>\"#{DateTime.now.utc.strftime("%d-%b-%Y-%I:%M %p UTC")}\"}", running_exports
      end
    end
  end

  def test_should_update_running_exports_when_an_export_completes
    MingleConfiguration.overridden_to(saas_env: 'test') do
      Multitenancy.add_tenant('eiwork', "database_username" => current_schema)
      Multitenancy.activate_tenant('eiwork') do
        SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

        Export.create(status: Export::COMPLETED)
        MergeExportDataProcessor.new.send(:update_running_exports)
        assert_equal ({"hello"=>"22-Aug-2018-07:01 AM UTC"}), MingleConfiguration.global_config['running_exports']
      end
    end
  end

  private

  def current_schema
    ActiveRecord::Base.configurations['test']['username']
  end

end
