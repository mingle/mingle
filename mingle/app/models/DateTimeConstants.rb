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

module DateTimeConstants
  AMERICAN_DATE_FORMAT = '%m/%d%Y'
  ISO_DATE_FORMAT = '%F'
  ISO_TIME_FORMAT = '%T'
  ISO_DATE_TIME_FORMAT= "#{ISO_DATE_FORMAT}T#{ISO_TIME_FORMAT}"
  AMERICAN_DATE_TIME_FORMAT = "#{AMERICAN_DATE_FORMAT}T#{ISO_TIME_FORMAT}"
end
