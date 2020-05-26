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

class Deletion
  class Blockings < Array
    def add_reasons(items, blocking_options={})
      items.each { |item| self << Blocking.new(item, blocking_options) }
    end
  end

  attr_reader :model
  
  def initialize(model, components = nil)
    @model = model
    @components = components
  end
  
  def deletions
    @components.select{|component| component.deletion.blocked? }.collect(&:deletion) if @components
  end
  
  def blockings
    @blockings ||= nested_blockings
  end
  
  def effects
    @effects ||= @model.deletion_effects
  end
  
  def blocked?
    blockings.any?
  end
  
  def node?
    @components.nil?
  end
  
  def can_delete?
    !blocked?
  end
  
  private
  
  def nested_blockings
    if node?
      @model.deletion_blockings
    else
      @components.inject([]) do |blockings, model|
        model.deletion.blockings.inject(blockings){ |blockings, blocking| blockings << blocking }
      end
    end
  end
end
