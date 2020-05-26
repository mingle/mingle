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

module ActionController
  module RequestForgeryProtection
    module ClassMethods
      # the only change from rails 2.3.14 is using prepend_before_filter instead of before_filter
      def protect_from_forgery(options = {})
        self.request_forgery_protection_token ||= :authenticity_token
        prepend_before_filter :verify_authenticity_token, :only => options.delete(:only), :except => options.delete(:except)
        if options[:secret] || options[:digest]
          ActiveSupport::Deprecation.warn("protect_from_forgery only takes :only and :except options now. :digest and :secret have no effect", caller)
        end
      end
    end
  end
end
