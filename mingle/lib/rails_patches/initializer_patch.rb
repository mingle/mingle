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


module Rails
  class Initializer

    # Eager load application classes
    # see http://github.com/rails/rails/commit/f57ca8772914810ae5049054b7a5b362cc1766d1
    # fixed eager loading in rake tasks
    def load_application_classes
      return if $rails_rake_task && configuration.dependency_loading
      if configuration.cache_classes
        configuration.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
      end
    end

  end
end
