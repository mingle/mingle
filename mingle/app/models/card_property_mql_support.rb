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

module CardPropertyMqlSupport
  class CardIdAdapter
    subclass_responsibility :card_id

    def numeric?
      true
    end
  end

  class CardId < CardIdAdapter
    attr_reader :card_id
    def initialize(id)
      @card_id = id ? id.to_i : id
    end

    def to_s
      "Card[id: #{card_id.inspect}]"
    end
  end

  class CardNumber < CardIdAdapter
    attr_reader :num
    def initialize(num)
      @num = num
    end

    def in_comparison_value(column)
      num.respond_to?(:in_comparison_value) ? CardNumber.new(num.in_comparison_value(column)) : self
    end

    def card_id
      Project.current.card_number_to_id(num)
    end

    def to_s
      @num
    end
  end

  def self.card_id(id)
    CardId.new(id)
  end

  def self.card_number(num)
    CardNumber.new(num)
  end

  def comparison_value(mql_identifier)
    if mql_identifier.is_a?(CardIdAdapter)
      mql_identifier.card_id
    elsif mql_identifier =~ /\A#(\d+) / #<number> <name>
      project.card_number_to_id($1)
    else #name
      project.card_name_to_id(mql_identifier)
    end.try(:to_i)
  end

  def mql_select_column_value(value)
    return if value.nil?
    key = "mql_values_#{self.id}"
    value = value.to_i
    values = ThreadLocalCache.get(key) { [] }
    values << value
    lambda do
      ret = ThreadLocalCache.get("#{key}_ret") { {} }
      ret.merge!(mql_select_column_values(values - ret.keys))
      values.clear
      ret[value].try(:number_and_name)
    end
  end

  def mql_select_column_values(values)
    return {} if values.blank?
    select = SqlHelper.quote_column_names(['id', 'number', 'name']).join(", ")
    values.uniq.each_slice(1000).inject({}) do |memo, v|
      memo.merge(Hash[project.cards.find(:all, :select => select, :conditions => ["id in (?)", v]).map{|c|[c.id, c]}])
    end
  end
end
