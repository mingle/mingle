#!/usr/bin/env ruby
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

require File.dirname(__FILE__) + '/memtest'

Runner.new do |runner|
 runner.users = ['djrice', 'jmitchel', 'jemarley', 'jprice', 'aqian',
'amonago']
 runner.repeat = 1

 property_rename = ::PropertyRename.new('feature')
 list_cards = ::GetRequest.new('cards/list')
 history = ::GetRequest.new('history')
 overview = ::GetRequest.new('')

 simple_operations = [list_cards, history, overview, property_rename]

 runner.mingle = simple_operations
 runner.mingle_feedback = simple_operations
 runner.mingle_pm_workbench = simple_operations
 runner.testing_sandbox_mingle_clone = simple_operations
end

