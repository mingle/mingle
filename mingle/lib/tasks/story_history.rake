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
namespace :history do
  desc "check the development history of story"
  task :git do |t, args|
    story_token = args[:token] || args[:story]
    versions = `git log --pretty=oneline --until='8 hours ago'| grep -e '#{story_token}\\b'`.split(/\n/m).collect { |line| line.split(' ').first }
    puts versions.inject('') { |output, version| output << `git log #{version} -p -1 --color`}
  end
end
