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

class RenderableTester
  include Renderable
  
  attr_reader :deliverable, :content
  
  attr_accessor :has_macros, :can_be_cached, :name
  
  def can_be_cached?
    can_be_cached
  end
  
  def project
    deliverable
  end
  
  def id
    'test_id'
  end
  
  def project_id
    project.id
  end
  
  def initialize(deliverable, content, card = nil)
    @deliverable, @content, @card = deliverable, content, card
  end
  
  def content_provider
    @card || self
  end

  def content_changed?
    false
  end

  def identifier
    'Dashboard'
  end
  
  def updated_at
    Clock.now
  end
  
  def self.table_name
    'renderable_tester'
  end
  
  def version
    1
  end
  
  def redcloth
    false
  end
    
  def chart_executing_option
    {
      :controller => 'pages',
      :action => 'chart',
      :pagename => identifier
    }
  end  
end
