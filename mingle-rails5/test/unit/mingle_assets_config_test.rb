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

class MingleAssetsConfigTest < ActiveSupport::TestCase

  def setup
    @mingle_assets_config_new = MingleAssetsConfig.new(
        {
            :sprockets_app_js => 'sprockets_app-8457hfjdi5tdf45.js',
        }
    )
  end

  def test_should_return_asset_path_when_mingle_asset_host_is_configured
    MingleConfiguration.overridden_to(:asset_host => 'https://mingle-assets-host.com') do
      assert_equal 'https://mingle-assets-host.com/assets/sprockets_app-8457hfjdi5tdf45.js', @mingle_assets_config_new.path_for(:sprockets_app_js)
    end
  end

  def test_should_return_asset_path_when_mingle_asset_host_is_not_configured
    assert_equal '/assets/sprockets_app-8457hfjdi5tdf45.js', @mingle_assets_config_new.path_for(:sprockets_app_js)
  end
end
