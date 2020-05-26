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

# This patch ensures that when we call remote_function method from actionPack gem for ajax queries, if the method type is set as
# GET, then the javascript to append CSRF token to the URL is NOT added. The gem was not checking the method type before adding the javascript.
# The remote_function method calls options_for_ajax method which has been patched
module ActionView
  module Helpers
    module PrototypeHelper
      protected
      def options_for_ajax(options)
        js_options = build_callbacks(options)

        js_options['asynchronous'] = options[:type] != :synchronous
        js_options['method']       = method_option_to_s(options[:method]) if options[:method]
        js_options['insertion']    = "'#{options[:position].to_s.downcase}'" if options[:position]
        js_options['evalScripts']  = options[:script].nil? || options[:script]

        if options[:form]
          js_options['parameters'] = 'Form.serialize(this)'
        elsif options[:submit]
          js_options['parameters'] = "Form.serialize('#{options[:submit]}')"
        elsif options[:with]
          js_options['parameters'] = options[:with]
        end

        if protect_against_forgery? && !options[:form] && js_options['method'] != "'get'"
          if js_options['parameters']
            js_options['parameters'] << " + '&"
          else
            js_options['parameters'] = "'"
          end
          js_options['parameters'] << "#{request_forgery_protection_token}=' + encodeURIComponent('#{escape_javascript form_authenticity_token}')"
        end

        options_for_javascript(js_options)
      end

      def method_option_to_s(method)
        ((method.is_a?(String) || method.is_a?(Symbol)) and !method.to_s.index("'").nil?) ? method : "'#{method}'"
      end

    end
  end
end
