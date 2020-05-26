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

# So here's the thing. When we used Rails 1.2, tags were almost always loaded via joins when loading taggings. When this happened, the acts_as_paranoid conditions
# would be ignored and all tags, deleted or not, would be loaded. But in Rails 2.1, eager loading happens in multiple SQL statements. So taggings are loaded,
# then tags after. And when tags are loaded alone, the acts_as_paranoid conditions kick in and only undeleted ones are loaded. So the behaviour differs from
# Rails 1.2. We needed to fix this.
#
# So my theory is that Mingle under Rails 1.2 pretty much always loaded deleted tags, except when project.tags was called (this is a direct association, so the
# acts_as_paranoid conditions kick in). So this monkeypatch ensures that deleted tags are always loaded, and I've made it so that Project.tags only loads
# undeleted ones by using an explicit condition.

module Caboose #:nodoc:
  module Acts #:nodoc:
    module Paranoid
      module InstanceMethods #:nodoc:
        module ClassMethods
          
          # this method redefined by us because rails 2.1 uses args.extract_options! instead of extract_options_from_args!(args)
          def find_with_deleted(*args)
            options = args.extract_options!
            validate_find_options(options)
            set_readonly_option!(options)
            options[:with_deleted] = true # yuck!

            case args.first
              when :first then find_initial(options)
              when :all   then find_every(options)
              else             find_from_ids(args, options)
            end
          end
          
          # this method redefined by us because rails 2.1 uses construct_count_options_from_args instead of construct_count_options_from_legacy_args
          def count_with_deleted(*args)
            calculate_with_deleted(:count, *construct_count_options_from_args(*args))
          end
          
          protected
          
          # this method redefined by us because of the big explanation at the top of this file
          def with_deleted_scope(&block)
            with_scope({:find => {} }, :merge, &block)
          end
        end
      end
    end
  end
end
