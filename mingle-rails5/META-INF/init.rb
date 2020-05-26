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

WARBLER_CONFIG = {"public.root"=>"/public", "rails.env"=>"development", "rails.root"=>"/", "war.packaged"=>nil, "gem.path"=>"/vendor/bundled/jruby/2.3.0", "jruby.min.runtimes"=>"1", "jruby.max.runtimes"=>"1"}

if $servlet_context.nil?
  ENV['GEM_HOME'] = File.expand_path(File.join('..', '/vendor/bundled/jruby/2.3.0'), __FILE__)
  ENV['BUNDLE_GEMFILE'] ||= File.expand_path(File.join('..', '/Gemfile'), __FILE__)
else
  ENV['GEM_HOME'] = $servlet_context.getRealPath('/vendor/bundled/jruby/2.3.0')
  ENV['GEM_PATH'] = nil
  ENV['BUNDLE_GEMFILE'] ||= $servlet_context.getRealPath('/Gemfile')
end

ENV['RAILS_ENV'] = 'development'

module Bundler
  module Patch
    def clean_load_path
      # nothing to be done for embedded JRuby
    end
  end
  module SharedHelpers
    def included(bundler)
      bundler.send :include, Patch
    end
  end
end

require 'bundler/shared_helpers'
