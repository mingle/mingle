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

class SecretKeyBaseHelperTest < ActiveSupport::TestCase

  def setup
    @test_config = File.join(Rails.root, 'test', 'config')
  end

  def teardown
    FileUtils.rm_rf(File.join(@test_config, 'secrets.yml'))
  end

  def test_secret_key_base_base_should_not_create_secrets_yml_when_exists
    File.write(File.join(@test_config, SecretKeyBaseHelper::SECRETS_YML), secret_config)

    assert_equal("secret_key_base_value", SecretKeyBaseHelper.new(@test_config).secret_key_base)
  end

  def test_secret_key_base_base_should_create_secrets_yml
    secret_config  = "secret_key_base"*10
    SecureRandom.expects(:hex).with(128).returns(secret_config  )

    assert_equal(secret_config, SecretKeyBaseHelper.new(@test_config).secret_key_base)
  end

  private

  def secret_config
    config = {
        secret_key_base: "secret_key_base_value"
    }
    config.to_yaml
  end
end
