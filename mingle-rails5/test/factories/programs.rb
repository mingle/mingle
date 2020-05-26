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
  factory :program do
    identifier {'prog'.uniquify[0..20]}
    name {"#{identifier}"}

    factory :simple_program do
      identifier 'simple_program'
      name 'simple_program'
      after(:create) do |program|
        program.plan ||= FactoryGirl.build(:objective, :program => program)
      end
    end

    factory :program_with_objectives do
      after(:create) do |program|
        program.plan ||= [FactoryGirl.build(:planned_objective, program: program)]
      end
    end

    factory :program_with_backlog_objectives do
      after(:create) do |program|
        [FactoryGirl.build(:backlog_objective, program: program)]
      end
    end

  end

end
