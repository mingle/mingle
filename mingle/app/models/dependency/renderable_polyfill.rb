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

module Dependency::RenderablePolyfill
  def content
    description
  end

  def content=(value)
    self.description = value
  end

  def content_changed?
    description_changed?
  end

  def has_macros; false; end
  def has_macros=(has_macros); end

  def redcloth; false; end
  def redcloth=(ignored); end
  alias_method :redcloth?, :redcloth
end
