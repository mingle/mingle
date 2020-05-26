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

class << ActiveRecord::Base
  def belongs_to_with_deleted(association_id, options = {})
    with_deleted = options.delete :with_deleted
    belongs_to_without_deleted(association_id, options).tap do
      if with_deleted
        reflection = reflect_on_association(association_id)
        association_accessor_methods(reflection,            Caboose::Acts::BelongsToWithDeletedAssociation)
        association_constructor_method(:build,  reflection, Caboose::Acts::BelongsToWithDeletedAssociation)
        association_constructor_method(:create, reflection, Caboose::Acts::BelongsToWithDeletedAssociation)
      end
    end
  end
  
  alias_method_chain :belongs_to, :deleted
end
ActiveRecord::Base.send :include, Caboose::Acts::Paranoid
