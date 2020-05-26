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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class InitialSetupTest < ActiveSupport::TestCase

  def setup
    create(:admin)
    License.eula_accepted
  end

  def test_does_not_need_install_when_mingle_is_configured
    assert_equal false, Install::InitialSetup.need_install?
  end

  def test_need_install_when_smtp_is_not_configured
    existing_smtp_config = SMTP_CONFIG_YML
    Constant.set('const' => 'SMTP_CONFIG_YML', 'value' => "no_file.yml")
    assert Install::InitialSetup.need_install?
  ensure
    Constant.set('const' => 'SMTP_CONFIG_YML', 'value' => existing_smtp_config)
  end

  def test_need_install_when_site_url_not_configured
    existing_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_u_r_l = ''
    assert Install::InitialSetup.need_install?
  ensure
    MingleConfiguration.site_url = existing_site_url
  end

  def test_no_need_install_when_skip_install_check_is_on
    MingleConfiguration.with_site_u_r_l_overridden_to("") do
      assert Install::InitialSetup.need_install?
      MingleConfiguration.with_skip_install_check_overridden_to(true) do
        assert !Install::InitialSetup.need_install?
      end
      assert Install::InitialSetup.need_install?
    end
  end

  def test_need_install_when_eula_is_not_accepted
    License.get.update_attributes(:eula_accepted => 'false')
    assert_equal true, Install::InitialSetup.need_install?
  end

  def test_need_install_when_no_user_exists
    User.delete_all
    assert_equal true, Install::InitialSetup.need_install?
  end

  def test_need_install_when_db_is_not_configured_and_database_helper_can_not_setup_the_db
    Database.expects(:need_config?).returns(true)
    DatabaseHelper.any_instance.expects(:setup).returns(false)

    assert_equal true, Install::InitialSetup.need_install?
  end

  def test_does_not_need_install_when_db_is_not_configured_and_database_helper_sets_up_the_db
    Database.expects(:need_config?).returns(true)
    DatabaseHelper.any_instance.expects(:setup).returns(true)

    assert_false Install::InitialSetup.need_install?
  end

  def test_need_install_when_db_is_not_configured_and_database_helper_throws_exception
    Database.expects(:need_config?).returns(true)
    DatabaseHelper.any_instance.expects(:setup).raises(Exception.new("Need config"))

    assert_equal true, Install::InitialSetup.need_install?
  end
end
