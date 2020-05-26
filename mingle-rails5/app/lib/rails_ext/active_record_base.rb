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

class ActiveRecord::Base
  # Have to override here instead of ApplicationRecord because MingleSession inherits from ActiveRecord::SessionStore::Session which
  # does not inherit from ApplicationRecord so session fetching fails on tenant switching in multitenancy mode.
  class << self
    def connection
      Multitenancy::CONNECTION_MANAGER.current_or_default_connection
    end
  end
end
