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

module SessionMarshallingPatches
  MARSHAL_SIGNATURE = 'BAh'.freeze

  def self.included(base)
    base.instance_eval do
      def marshal(data)
        JSON.dump(value: data) if data
      end

      def unmarshal(data)
        return unless data
        if needs_migration?(data)
          Marshal.load(::Base64.decode64(data))
        else
          session_hash = JSON.load(data)
          session_hash.is_a?(Hash) ? session_hash.with_indifferent_access[:value] : session_hash
        end
      end

      def needs_migration?(value)
        value.start_with?(MARSHAL_SIGNATURE)
      end
    end
  end
end

ActiveRecord::SessionStore::Session.send :include, SessionMarshallingPatches
