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

class HtmlSanitizer < Rails::Html::WhiteListSanitizer
  TAGS_TO_BE_REMOVED_WITH_CONTENT = %w{.//style}
  TAGS_TO_BE_REMOVED_WITH_CONTENT.push *Rails::Html::XPATHS_TO_REMOVE

  class << self
    attr_accessor :allowed_tags
    attr_accessor :allowed_attributes
  end

  self.allowed_attributes = Rails::Html::WhiteListSanitizer.allowed_attributes + %w(style)
  self.allowed_tags = Rails::Html::WhiteListSanitizer.allowed_tags + %w(table tbody thead th tr td)

  def sanitize(html, options = {})
    return unless html
    return html if html.empty?
    loofah_fragment = Loofah.fragment(html)
    remove_xpaths(loofah_fragment, TAGS_TO_BE_REMOVED_WITH_CONTENT)
    super(loofah_fragment.to_s, options)
  end
end
