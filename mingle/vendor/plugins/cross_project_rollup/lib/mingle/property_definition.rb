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

#Copyright 2009 ThoughtWorks, Inc.  All rights reserved.

module Mingle
  PropertyDefinition.class_eval do
    def managed_text?
      self.type_description == Mingle::PropertyDefinition::MANAGED_TEXT_TYPE
    end
    
    def card?
      [Mingle::PropertyDefinition::CARD_TYPE, Mingle::PropertyDefinition::TREE_RELATIONSHIP_TYPE].include?(type_description)
    end
    
    def user?
      type_description == Mingle::PropertyDefinition::USER_TYPE
    end
  end
end
