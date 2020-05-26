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

class IframeMacro < Macro
  parameter :src, :required => true, :example => "https://getmingle.io"
  parameter :width, :default => 800, :example => "800"
  parameter :height, :default => 400, :example => "400"

  def execute_macro
    if MingleConfiguration.site_url =~ /^https/ && src !~ /^https\:/
      return "Cannot render insecure content from '#{src}' when Mingle site page is loaded over HTTPS."
    end
    if @context[:edit] || @context[:preview]
      # show macro place holder, so that we can edit the iframe content
      ""
    else
      "<iframe src=\"#{ERB::Util::h(src)}\" width=\"#{ERB::Util::h(width)}\" height=\"#{ERB::Util::h(height)}\"></iframe>"
    end
  end

  def can_be_cached?
    true
  end
end

Macro.register('iframe', IframeMacro)
