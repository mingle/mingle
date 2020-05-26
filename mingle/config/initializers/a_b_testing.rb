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

# --------------------------------
# Defining experiments that are running
# e.g. ABTesting.add_experiments('exp1', 'exp2')

#ABTesting.add_experiments('')

# Add extra experiment from mingle configuration
# -Dmingle.abtestingExperiments=exp23,exp43
# this is useful when you only want turn on a certain experiment for a
# specific environment

unless MingleConfiguration.abtesting_experiments.blank?
  ABTesting.add_experiments(*(MingleConfiguration.abtesting_experiments.split(',')))
end
