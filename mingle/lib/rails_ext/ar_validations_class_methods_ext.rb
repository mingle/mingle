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

module ActiveRecord::Validations::ClassMethods
  def validates_email_format_of(field, opt={})
    if opt[:allow_blank]
      validates_format_of field, opt.merge(:with => /^(|([^@\s]+)@((?:[-_a-z0-9]+\.)+[a-z]{2,}))$/i, :allow_nil => true)
    else
      validates_format_of field, opt.merge(:with => EMAIL_FORMAT_REGEX)
    end
  end
end
