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

module Mingle

  module Version
    CURRENT = com.thoughtworks.mingle.ManifestUtil.findKeyInClassPath("Mingle-Version") rescue "latest"
  end

  module Revision
    class RevisionProvider
      class << self
        def current
          return Git if File.exists?('.git')
          return Java if RUBY_PLATFORM =~ /java/
          Unsupported
        end
      end

      class Java
        def self.value
          com.thoughtworks.mingle.ManifestUtil.findKeyInClassPath("Mingle-Revision") rescue "unsupported"
        end

        def self.swap_dir_subfolder; "#{::Mingle::Version::CURRENT}_#{value}"; end
      end

      class Git
        def self.value
          `git log -n1 --pretty=format:%h` || 'unsupported'
        rescue
          'unsupported'
        end

        def self.swap_dir_subfolder; "#{::Mingle::Version::CURRENT}_#{value}"; end
      end

    end

    CURRENT = RevisionProvider::current::value
    SWAP_SUBDIR = RevisionProvider::current::swap_dir_subfolder
  end

  module API
    NAMESPACE = "http://www.thoughtworks-studios.com/ns/mingle"

    # generate uri under mingle namespace
    # example:
    #       Mingle::API.ns #=> "http://www.thoughtworks-studios.com/ns/mingle"
    #       Mingle::API.ns("card") #=> "http://www.thoughtworks-studios.com/ns/mingle#card"
    def self.ns(subname=nil)
      [NAMESPACE, subname].compact.join("#")
    end
  end
end
