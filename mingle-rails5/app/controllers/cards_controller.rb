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

class CardsController < ProjectApplicationController
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => %w(update_property_color destroy bulk_destroy confirm_delete confirm_bulk_delete reorder_lanes),
             UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => %w(new create edit update preview update_property update_property_on_lightbox bulk_set_properties_panel bulk_set_properties bulk_tagging_panel remove_card_from_tree remove_card_from_tree_on_card_view create_view create_view_async bulk_transition transition bulk_transition transition_in_popup transition_in_old_popup require_popup_for_transition require_popup_for_transition_in_popup require_comment_for_bulk_transition remove_attachment set_value_for tree_cards_quick_add tree_cards_quick_add_to_root add_children bulk_add_tags bulk_remove_tag update_tags add_comment show_tree_cards_quick_add show_tree_cards_quick_add_to_root show_tree_cards_quick_add_on_card_show_page update_restfully add_comment_restfully dependencies_statuses reorder_tags),
             UserAccess::PrivilegeLevel::READONLY_TEAM_MEMBER => %w(copy confirm_copy copy_to_project_selection render_macro),
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => %w(csv_export)
end
