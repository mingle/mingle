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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class IntegrationsHelperTest < ActiveSupport::TestCase
  include IntegrationsHelper
  include SlackClientStubs

  def test_should_encrypt_tenant_name_as_state_for_slack
    tenant_name = 'valid-tenant-name'
    MingleConfiguration.overridden_to({
        :app_namespace => tenant_name,
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q=='}) do
      assert_equal('52d9c188db44f50d70c9d1a4dd7a8e67d8a4332fde6f94be2f182ed253caed47',
                   encrypt_data_for_slack("tenantName:#{tenant_name}"))
    end
  end

  def test_should_render_slack_user_sign_in_link
    tenant_name = 'valid-tenant-name'
    slack_app_url_base = 'https://slack.app'
    bob = build(:bob)
    User.current = bob
    slack_client_id = 'slack-client-id'
    redirect_uri = 'profile/show'
    MingleConfiguration.overridden_to({:app_namespace => tenant_name,
                                       :slack_app_url => slack_app_url_base,
                                       :slack_client_id => slack_client_id,
                                       :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q=='}) do
      freeze_time do
        link = slack_user_sign_in_link redirect_uri

        plain_text_state = {  userLogin: bob.login,
                              userId: bob.id,
                              userName: bob.name,
                              tenantName: tenant_name,
                              mingleRedirectUri: redirect_uri,
                              eulaAcceptedAt: Time.now.utc.milliseconds.to_i
                            }.to_json

        query_params = Rack::Utils.parse_query(URI.parse(link).query).with_indifferent_access
        assert_equal slack_client_id, query_params[:client_id]
        assert_equal "#{slack_app_url_base}/authorizeUser", query_params[:redirect_uri]
        assert_equal USER_INTEGRATION_SCOPE, query_params[:scope]
        assert_equal encrypt_data_for_slack(plain_text_state), query_params[:state]
      end
    end
  end

  def test_value_of_slack_scope_constants
    assert_equal 'identify,commands,chat:write:bot,channels:read,users:read', APP_INTEGRATION_SCOPE
    assert_equal 'identity.basic', USER_INTEGRATION_SCOPE
  end

  def test_should_decrypt_mingle_slack_api_data
    mingle_slack_api_data = {:mingleTeamId=>7, :mingleUserId=>120}.to_json
    MingleConfiguration.overridden_to({:slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q=='}) do
      assert_equal(mingle_slack_api_data,
                   decrypt_data_from_slack('a2e9562002aa1587cbc01ae55412f75069c48861aaa08d0521fdac9399ef6f885f165c9bef59f851'))
    end
  end

  def test_projects_mapped_to_slack_should_return_projects_which_have_channel_mapping
    freeze_time do
      create(:project) do |project1|
        create(:project) do |project2|
          tenant_name = 'tenant-name'
          stub_mapped_projects_request(tenant_name, {mappings: [{mingleTeamId: project1.team.id}]})
          mapped_projects = nil

          MingleConfiguration.overridden_to(app_namespace: tenant_name, slack_app_url: 'https://slackserver.com') do
            with_fake_aws_env_for_slack_client do
              mapped_projects = projects_mapped_to_slack([project1, project2])
            end
          end

          assert_equal [project1], mapped_projects
        end
      end
    end
  end

  def test_projects_mapped_to_slack_should_return_empty_lit_when_there_is_no_mapped_projects
    freeze_time do
      create(:project) do |project1|
        create(:project) do |project2|
          tenant_name = 'tenant-name'
          stub_mapped_projects_request(tenant_name, {mappings: nil})
          mapped_projects = nil

          MingleConfiguration.overridden_to(app_namespace: tenant_name, slack_app_url: 'https://slackserver.com') do
            with_fake_aws_env_for_slack_client do
              mapped_projects = projects_mapped_to_slack([project1, project2])
            end
          end

          assert mapped_projects.blank?
        end
      end
    end
  end

end
