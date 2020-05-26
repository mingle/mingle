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

require File.join(File.dirname(__FILE__), 'base_tab')

class DisplayTabs
  class WikiTab < UserDefinedTab
    def tab_type
      'Page'
    end

    def initialize(project, favorite)
      super(project, favorite, nil, "wiki-tab")
    end

    def params
      @target.favorited.link_params
    end

    def dirty?
      false
    end

    def rename(new_name)
      existing_page = @target.favorited
      new_page = @project.pages.build(:name => new_name, :content => existing_page.content, :attachings => existing_page.attachings, :taggings => existing_page.taggings)

      if new_page.save
        @target.update_attributes(:favorited => new_page)
        existing_page.update_attributes(:content => "This page was renamed to [[#{new_page.name}]].")
      else
        self.errors.add(:base, new_page.errors.full_messages.join("\n"))
      end
    end

    def sidebar_text
      "Favs & History"
    end
  end
end
