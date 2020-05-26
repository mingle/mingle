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

class Favorite < ActiveRecord::Base
  belongs_to :project
  belongs_to :favorited, polymorphic: true

  scope :of_pages, -> { where(favorited_type: 'Page') }
  scope :of_card_list_views, -> { where(favorited_type: 'CardListView') }
  scope :of_team, -> { where(user_id: nil) }
  scope :personal, -> (user) { user.anonymous? ? where(['1 != 1']) : where(user_id: user.id) }
  scope :include_favorited, -> { includes(:favorited) }
end
