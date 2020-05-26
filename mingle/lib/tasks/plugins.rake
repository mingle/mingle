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
require 'fileutils'

namespace :scm do
  def fetch(git_url)
    `cd ../mingle_scm_plugins && git clone #{git_url}`
  end

  def build(plugin_checkout_dir)
    `cd ../mingle_scm_plugins/#{plugin_checkout_dir}/rails_plugin  && ./jrake`
  end

  def deploy(plugin_name)
    `cp ../mingle_scm_plugins/#{plugin_name}/rails_plugin/dist/#{plugin_name}.tar.gz ./vendor/plugins/`
    `rm -rf ./vendor/plugins/#{plugin_name}`
    `tar -xzf ./vendor/plugins/#{plugin_name}.tar.gz -C ./vendor/plugins/ && rm ./vendor/plugins/#{plugin_name}.tar.gz`
  end

  task :clean do
    `rm -rf ../mingle_scm_plugins && mkdir -p ../mingle_scm_plugins`
  end

  namespace :hg do
    task :fetch do
      fetch 'git://github.com/mingle/mingle_hg_plugin.git'
    end

    task :build_plugin do
      build 'mingle_hg_plugin'
    end

    task :deploy_plugin do
      deploy 'mingle_hg_plugin'
    end
  end

  namespace :git do
    task :fetch do
      fetch 'git://github.com/mingle/mingle_git_plugin.git'
    end

    task :build_plugin do
      build 'mingle_git_plugin'
    end

    task :deploy_plugin do
      deploy 'mingle_git_plugin'
    end
  end

  task :build_hg_plugin => [:clean, "hg:fetch", "hg:build_plugin", "hg:deploy_plugin"]
  task :build_git_plugin => [:clean, "git:fetch", "git:build_plugin", "git:deploy_plugin"]
end

namespace :plugins do
  namespace :dependency_tracker do
    BUILD_DIR = File.join(File.dirname(__FILE__), "..", "..", "tools", "dependency-tracker")

    task :fetch do
      Dir.chdir BUILD_DIR do
        `git pull --rebase`
      end
    end

    task :build_plugin do
      Dir.chdir BUILD_DIR do
        `./cruise-rake.sh distribution`
      end
    end

    task :deploy_plugin do
      src_file = File.join(BUILD_DIR, "out", "dependency_tracker*.tar.gz")
      dest_dir = File.join(File.dirname(__FILE__), "..", "..", "vendor", "plugins")
      `tar -xzf #{src_file} -C #{dest_dir}`
    end

    task :all => [:fetch, :build_plugin, :deploy_plugin]
  end

  desc "Build dependency tracker"
  task :build_dependency_tracker => ["dependency_tracker:all"]
end
