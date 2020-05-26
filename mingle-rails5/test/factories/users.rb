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
  factory :user do
    login {Helpers.unique_name}
    password {MINGLE_TEST_DEFAULT_PASSWORD}
    password_confirmation {MINGLE_TEST_DEFAULT_PASSWORD}
    name {"name of #{login}"}
    email {"#{login}@email.com"}

    factory :light_user do
      light true
    end

    factory :bob do
      login 'bob'
      email 'bob@email.com'
      name  'bob@email.com'
    end

    factory :admin do
      admin 'true'
    end

    trait :deactivated do
      activated false
    end
  end
end
