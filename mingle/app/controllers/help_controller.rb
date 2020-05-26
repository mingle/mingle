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

class HelpController < ApplicationController
  skip_filter TransactionFilter
  allow :get_access_for => [:macro]

  class HelpArticle
    attr_reader :anchor, :header, :content
    
    def initialize(anchor, header, content)
      @anchor, @header, @content = anchor, header, content
    end
  end
  
  def macro
    @title = "Macro help"
    @articles = Macro.macros.collect do |name, macro_class|
      HelpArticle.new(name, name, RedCloth.new(macro_class.help).to_html || "Not documented")
    end
    render :template => 'help/articles'
  end
end

