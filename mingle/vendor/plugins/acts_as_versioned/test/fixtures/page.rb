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

class Page < ActiveRecord::Base
  belongs_to :author
  has_many   :authors,  :through => :versions, :order => 'name'
  belongs_to :revisor,  :class_name => 'Author'
  has_many   :revisors, :class_name => 'Author', :through => :versions, :order => 'name'
  acts_as_versioned :if => :feeling_good? do
    def self.included(base)
      base.cattr_accessor :feeling_good
      base.feeling_good = true
      base.belongs_to :author
      base.belongs_to :revisor, :class_name => 'Author'
    end
    
    def feeling_good?
      @@feeling_good == true
    end
  end
end

module LockedPageExtension
  def hello_world
    'hello_world'
  end
end

class LockedPage < ActiveRecord::Base
  acts_as_versioned \
    :inheritance_column => :version_type, 
    :foreign_key        => :page_id, 
    :table_name         => :locked_pages_revisions, 
    :class_name         => 'LockedPageRevision',
    :version_column     => :lock_version,
    :limit              => 2,
    :if_changed         => :title,
    :extend             => LockedPageExtension
end

class SpecialLockedPage < LockedPage
end

class Author < ActiveRecord::Base
  has_many :pages
end
