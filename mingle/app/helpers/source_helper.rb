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

module SourceHelper
  
  FILE_TYPE_MAP = {
    'rb' => 'ruby', 
    'rhtml' => 'rails',
    'cs' => 'c-sharp',
    'xsd' => 'xml',
    'xml' => 'xml',
    'xhtml' => 'xml',
    'xslt' => 'xml',
    'html' => 'xml',
    'htm' => 'xml',
    'jsp' => 'xml',
    'pas' => 'pascal',
    'cpp' => 'cpp',
    'c' => 'c',
    'css' => 'css',
    'java' => 'java',
    'js' => 'js',
    'php' => 'php',
    'py' => 'py',
    'sql' => 'sql',
    'vb' => 'vb'
  }
  
  def file_type(file)
    ext = file.path.gsub(/.+\.(\w+)$/) {|match| $1}
    FILE_TYPE_MAP[ext] || 'text-file'
  end
  
end
