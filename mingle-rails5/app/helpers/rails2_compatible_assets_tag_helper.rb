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

module Rails2CompatibleAssetsTagHelper
  def rails2_compatible_stylesheet_link_tag(asset_name)
    tag_options = {
        "rel" => "stylesheet",
        "media" => "screen",
        "href" => asset_config.path_for(asset_name)
    }
    tag(:link, tag_options).html_safe
  end

  def rails2_compatible_javascript_include_tag(asset_name)
    tag_options = {
        "src" => asset_config.path_for(asset_name)
    }
    content_tag("script".freeze, "", tag_options).html_safe
  end

  private
  def asset_config
    Rails.application.config.assets_config
  end
end
