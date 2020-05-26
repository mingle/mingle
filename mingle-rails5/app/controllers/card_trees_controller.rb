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

# todo: rename to TreeConfigurationController
class CardTreesController < ProjectAdminController
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => %w(create new edit update edit_aggregate_properties create_aggregate_property_definition update_aggregate_property_definition delete show_edit_aggregate_form show_add_aggregate_form delete_aggregate_property_definition confirm_delete manage_trees)
end
