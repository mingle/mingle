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

module ActionControllerBaseFlashPatch
  def self.included(base)
    base.class_eval do
      def flash
        @_flash ||= ActionController::Flash::FlashHash.from_session_value(session['flash'])
      end
    end
  end
end

module FlashHashJSONPatches
  def self.included(base)
    base.class_eval do
      def store(session, key = 'flash')
        session[key] = {
            flashes: self,
            discard: @used.keys.select { |k| @used[k] },
            html_safe: self.keys.select {|k| ActiveSupport::SafeBuffer === self[k]}
        }
      end

      def [](key)
        super(key.to_s) || super(key)
      end

      def []=(key, value)
        delete(key) if has_key? key
        keep(key)
        super(key.to_s, value)
      end

      private

      def use(k=nil, v=true)
        unless k.nil?
          @used[k.to_s] = v
        else
          keys.each{ |key| use(key, v) }
        end
      end
    end

    base.instance_eval do
      def from_session_value(value)
        flash = ActionController::Flash::FlashHash.new
        if ActionController::Flash::FlashHash === value
          flash = value
        elsif Hash === value
          value = value.with_indifferent_access
          (value[:html_safe] || []).each { |k| value[:flashes][k] = value[:flashes][k].html_safe }
          flash.update(value[:flashes] || value)
          (value[:discard] || []).each {|k| flash.discard(k)}
        end
        flash.sweep
        flash
      end
    end
  end
end

ActionController::Base.send :include, ActionControllerBaseFlashPatch

ActionController::Flash::FlashHash.send :include, FlashHashJSONPatches
