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
require 'warble_helper'

def generate_installer_war
  Bundler.with_original_env do
    Rake::Task["crypt:encrypt_ruby"].invoke
    # ENV['ENCRYPT_CODE'] = 'true'
    system('./gradlew clean jar')
    sh 'bundle exec warble war'
  end
end

def generate_war
  WarbleHelper.copy_configs
  Bundler.with_original_env do
    system('./gradlew clean jar')
    sh 'bundle exec warble war'
  end
  WarbleHelper.restore_configs
end

namespace :war do
  task :build, [:installer] => 'assets:precompile' do |t, args|
    WarbleHelper.recreate_web_xml
    if args[:installer] && args[:installer] == 'true'
      generate_installer_war
    else
      generate_war
    end

  end
end
