# encoding: utf-8

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


raise 'This is not needed on Rails 3.0 and above. Rails 3+ uses Mail instead of TMail which can handle encodings in better way.' unless Rails.version == '2.3.18'

module TMail
  module TextUtils
    aspecial     = %Q|()<>[]:;.\\,"|
    tspecial     = %Q|()<>[];:\\,"/?=|
    lwsp         = %Q| \t\r\n|
    control      = %Q|\x00-\x1f\x7f\xc2\x80-\xc2\x9f|

    CONTROL_CHAR  = /[#{control}]/u
    ATOM_UNSAFE   = /[#{Regexp.quote aspecial}#{control}#{lwsp}]/u
    PHRASE_UNSAFE = /[#{Regexp.quote aspecial}#{control}]/u
    TOKEN_UNSAFE  = /[#{Regexp.quote tspecial}#{control}#{lwsp}]/u
  end
end
