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

module HistoryTabPageId

  FILTER_USER_ID='filter_user'
  SELECT_TEAM_MEMBER_OPTION_ID='Select team member...'
  CARD_TYPE_NAME_DROP_LINK='card_type_name_drop_link'
  ACQUIRED_CARD_TYPE_NAME_DROP_LINK='acquired_card_type_name_drop_link'
  CARD_FILTER_FIRST_VALUE_DROPLINK="cards_filter_0_values_drop_link"
  CARD_FILTER_FIRST_OPTION_ANY="cards_filter_0_values_option_(any)"

  def filter_types_id(type)
    "filter_types[#{type}]"
  end

  def acquired_card_type_option_id(type)
    "acquired_card_type_name_option_#{type}"
  end

  def card_filter_delete_id(index)
    "cards_filter_#{index}_delete"
  end
end
