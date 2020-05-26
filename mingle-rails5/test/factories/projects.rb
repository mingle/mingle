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

FactoryGirl.define do
  factory :project do
    identifier {"project_#{Helpers.unique_name}"}
    name {"name of #{identifier}"}
    created_by_user_id "some_id"
    after(:create) do |object|
      group = Group.find_by_deliverable_id(object.id)
      create(:user_membership, user_id: object.created_by_user_id, group_id: group.id)
    end
  end

  factory :first_project do
    identifier {"first_project_#{Helpers.unique_name}"}
  end

  trait :active do
    after :create, &:activate
  end
end
