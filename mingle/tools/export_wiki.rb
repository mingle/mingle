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

require File.join(File.dirname(__FILE__), 'lib/environment.rb')

# ----------
#
#  This script exports a project's wiki pages. 
#
#  Edit line 17 to set the identifier of the project you wish to export.
# 
#  To execute this script, from the installation directory, run:
#  $ tools/run tools/export_wiki.rb 
#
#  The wiki will be exported to a folder named '<project_name> Wiki'
#  in the Mingle installation directory.
#  
# ----------
  
project_identifier = 'todos'

#TODO: #4478: we need to confirm if we are still using this tool, otherwise we need to remove or refactory it

# extra environment requirements
require 'action_controller/base'
require 'action_controller/test_process'
require File.expand_path(File.dirname(__FILE__) + '/../app/controllers/application.rb')

# mix in everything needed to render views and build URLs
include ApplicationHelper, ActionView::Helpers::JavaScriptHelper, ActionView::Helpers::TagHelper, 
      ActionView::Helpers::FormTagHelper, ActionView::Helpers::TextHelper, ActionView::Helpers::CaptureHelper,
      ActionView::Helpers::UrlHelper      


# monkey patch link substitutions to link to html files rather than page controller actions
module Renderable
  class WikiLinkSubstitution < Substitution
    def substitute(match)
      # check whether there was a quoting just before the match
      # in that case return $& thereby cancelling the substitution
      original = $&
      page = match.captures[0]
      if $` =~ /\\$/
        original
      else
        "<a href='#{Page.name2identifier(page)}.html'>#{page}</a>".no_textile
      end
    end  
  end
  
  class NamedWikiLinkSubstitution < Substitution
    def substitute(match)
      "<a href='#{Page.name2identifier(match.captures[1])}.html'>#{match.captures[0]}</a>"
    end   
  end  
end


# rails black magic that allows this script to use the various URL helpers
@controller = PagesController.new
@controller.send(:params=, {})
@controller.send(:request=, ActionController::TestRequest.new)
@controller.send(:initialize_current_url)


# now we can actually write the pages to disk ...
project = Project.find_by_identifier(project_identifier)
project.activate

dir = "#{project.name} wiki"
FileUtils.rm_rf(dir)
FileUtils.mkdir_p(dir)
FileUtils.mkdir_p(File.join(dir, 'css'))
FileUtils.cp('public/stylesheets/application.css', File.join(dir, 'css'))
FileUtils.cp('public/stylesheets/wiki.css', File.join(dir, 'css'))

project.pages.each do |page|
  content = %{
<html>
  <head>
    <title>#{page.name}</title>
    <link href='css/application.css' media='screen' rel='Stylesheet' type='text/css' />
    <link href='css/wiki.css' media='screen' rel='Stylesheet' type='text/css' />
  </head>
  <body>
    <div id='content' class='wiki'>
      <h1>#{page.name}</h1>
        #{page.formatted_content_as_snippet(self)}
    </div>
  </body>
</html>  
  }
  
  File.open(File.join(dir, "#{page.identifier}.html"), 'w') do |io|
    io << content
  end
end
