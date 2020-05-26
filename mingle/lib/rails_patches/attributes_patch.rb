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

# We use method_missing in card.rb so that we can do things like
#
#      project.cards.create!(:name => 'name', :card_type_name => 'Card', :cp_release => my_release)
#
# in our tests -- for one, we are using an attribute cp_release that doesn't exist
# (it is really cp_release_card_card_id), and we are also expecting changing the release to
# add the card to the tree, etc.  So in method_missing we find the property defs and call
# update_card_by_obj on them.
#
# The prob is, Rails 2.3 throws an exception for attributes that don't exist.  So for now we are
# removing that exception throwing functionality.

module ActiveRecord
  class Base
    
    def attributes=(new_attributes, guard_protected_attributes = true)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!
      
      multi_parameter_attributes = []
      attributes = remove_attributes_protected_from_mass_assignment(attributes) if guard_protected_attributes
      
      attributes.each do |k, v|
        if k.include?("(")
          multi_parameter_attributes << [ k, v ]
        else
          # next line is the patched one -- we no longer raise UnknownAttributeError
          send(:"#{k}=", v)
        end
      end
      
      assign_multiparameter_attributes(multi_parameter_attributes)
    end
    
  end
end
