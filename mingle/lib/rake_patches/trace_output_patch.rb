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

Rake::TraceOutput.module_eval do

  # NOTE: avoid TypeError: String can't be coerced into Fixnum
  # due this method getting some strings == [ 1 ] argument ...
  def trace_on(out, *strings)
    sep = $\ || "\n"
    if strings.empty?
      output = sep
    else
      output = strings.map { |s|
        next if s.nil?; s = s.to_s
        s =~ /#{sep}$/ ? s : s + sep
      }.join
    end
    out.print(output)
  end

end
