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

class FlexibleDataFix
  def initialize(attrs, &block)
    @attrs = attrs
    @applied = false
    @proc = Proc.new(&block) if block_given?
  end

  def attrs
    @attrs
  end

  def name
    @attrs["name"]
  end

  def description
    @attrs["description"] || 'no description'
  end

  def queued?
    false
  end

  def required?
    @attrs["required"].nil? ? true : @attrs["required"]
  end

  def apply(project_ids=[])
    @proc.call if @proc
    @applied = true
  end

  # for test
  def applied?
    @applied
  end

  def reset
    @applied = false
  end
end
