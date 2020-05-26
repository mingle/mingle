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

class PluginMail < ActionMailer::Base
  def mail_from_plugin(note=nil)
    body(:note => note)
  end
  
  def mail_from_plugin_with_application_template(note=nil)
    body(:note => note)
  end
  
  def multipart_from_plugin
    content_type 'multipart/alternative'
    part :content_type => "text/html", :body => render_message("multipart_from_plugin_html", {})
    part "text/plain" do |p|
      p.body = render_message("multipart_from_plugin_plain", {})
    end
  end
  
  def multipart_from_plugin_with_application_template
    content_type 'multipart/alternative'
    part :content_type => "text/html", :body => render_message("multipart_from_plugin_with_application_template_html", {})
    part "text/plain" do |p|
      p.body = render_message("multipart_from_plugin_with_application_template_plain", {})
    end
  end  
  
end
