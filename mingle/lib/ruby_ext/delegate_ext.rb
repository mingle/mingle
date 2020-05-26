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

# This is a patch to Ruby's Delegator which, rather curiously, does not propogate
# proc objects passed to the delegator and intended for the delegatee.
#
# This is still needed as of 1.8.7.  We should revisit this when we move to 1.9 
require 'delegate'
class SimpleDelegator<Delegator
  def method_missing(m, *args, &block)
    target = self.__getobj__
    unless target.respond_to?(m)
      super(m, *args, &block)
    end
    target.__send__(m, *args, &block)
  end
  
end
