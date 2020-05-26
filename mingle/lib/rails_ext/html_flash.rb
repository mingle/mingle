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

module HtmlFlash

  def html_flash
    HtmlFlashProxy.new(flash)
  end

  class HtmlFlashProxy
    def initialize(flash)
      @flash = flash
    end

    def now
      HtmlFlashProxy.new(@flash.now)
    end

    def []=(k, v)
      @flash[k] = v.kind_of?(Array) ? v.map(&:html_safe) : v.html_safe
    end

    def [](k)
      @flash[k]
    end
  end

end

class ActionController::Base
  include HtmlFlash
end

module ApplicationHelper
  include HtmlFlash
end
