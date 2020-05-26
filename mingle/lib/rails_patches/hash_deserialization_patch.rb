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

#This patch is needed to keep version1 of the API working as expected for the execute_mql api.
#Without the call to underscore as shown below, casing of XML keys would be retained.
#This is a 'good' thing - but it is not good for us as it breaks the version1 api, which is still supported.
#This is *our* fix for the following issue: Hash#from_xml converted camelCase to underscore in 2.3.2, doesn't in 2.3.4
# https://rails.lighthouseapp.com/projects/8994/tickets/3377-hashfrom_xml-converted-camelcase-to-underscore-in-232-doesnt-in-234

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Conversions
        module ClassMethods
          private
            def unrename_keys(params)
              case params.class.to_s
                when "Hash"
                  params.inject({}) do |h,(k,v)|
                  # h[k.to_s.tr("-", "_")] = unrename_keys(v) #This is the line as it is in Rails 2.3.5
                    h[k.to_s.underscore.tr("-", "_")] = unrename_keys(v) #This is how we want this line to be, with the added underscore
                    h
                  end
                when "Array"
                  params.map { |v| unrename_keys(v) }
                else
                  params
              end
            end
        end
      end
    end
  end
end
