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

class RelationshipsMap
  include Enumerable

  def initialize(relationship_property_defs)
    @relationships = relationship_property_defs
  end

  def card_types
    return [] if @relationships.empty?
    @relationships.collect(&:valid_card_type) << last_card_type
  end
  memoize :card_types

  def relationship_to_parent_card_type(card_type)
    index = card_type_index(card_type)
    return nil if index < 1 || index >= card_types.size

    relationship_for_card_type(card_types[index - 1])
  end

  def parent_card_ids(card)
    ids = []
    each_before(card.card_type) do |relationship|
      ids << relationship.db_identifier(card)
    end
    ids.compact
  end

  def empty?
    @relationships.empty?
  end

  def reload
    @relationships.reload
  end

  def sub(relationships)
    @relationships - relationships
  end

  def relationship_for_card_type(card_type)
    @relationships.detect { |relationship| relationship.valid_card_type == card_type }
  end
  memoize :relationship_for_card_type

  def each(&block)
    @relationships.each(&block)
  end

  def each_before(card_type)
    @relationships.each do |r|
     yield(r) if card_type_index(card_type) > card_type_index(r.valid_card_type)
    end
  end

  def each_after(card_type)
    @relationships.each do |r|
      yield(r) if card_type_index(card_type) < card_type_index(r.valid_card_type)
    end
  end

  def card_type_index(card_type)
    card_types.index(card_type) || -1
  end

  def mql_columns
    self.collect { |r| CardQuery::Column.new(r.name) }
  end

  private
  def last_card_type
    raise 'Last relationship should only have one type applicable' if @relationships.last.card_types.size > 1
    @relationships.last.card_types.first
  end
end
