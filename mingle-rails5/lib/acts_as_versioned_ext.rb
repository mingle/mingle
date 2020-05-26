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

module ActiveRecord
  module Acts
    module Versioned
      def acts_as_versioned_ext(options = {})
        keep_versions = options.delete(:keep_versions_on_destroy)

        options[:association_options] ||= {}
        options[:association_options].merge!(:dependent => :destroy)
        options[:versioned_extension] = ExtensionMethods if keep_versions
        options[:versioned_extend] = ApplicationRecord

        acts_as_versioned(options)

      end

    end
    module ExtensionMethods
      #override has_many destroy method to do nothing, i.e. to not delete the versions
      def destroy!;
      end
    end
  end
end
