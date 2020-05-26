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

class CardSelector
  
  RESULT_LIMIT = 50
  
  module TreeRelationshipExt
    def card_selector_filter_values_mql
      "FROM TREE \"#{tree_configuration.name}\" WHERE #{valid_card_type.card_selector_context_mql} "
    end

    def card_selector_filter_values_search_context
      "tree_configuration_ids:#{tree_configuration.id} AND #{valid_card_type.card_selector_search_context}"
    end

    def card_selector_all_values_mql
      valid_card_type.card_selector_context_mql
    end

    def card_selector_all_values_search_context
      valid_card_type.card_selector_search_context
    end

  end
  
  module CardTypeExt
    def card_selector_context_mql
      "type = \"#{name}\""
    end
    def card_selector_search_context
      "card_type_id:#{id}"
    end
  end
  
  module CardRelationshipExt
    def card_selector_filter_values_search_context
      []
    end
    def card_selector_all_values_search_context
      []
    end
    def card_selector_all_values_mql
      nil
    end
    def card_selector_filter_values_mql
      nil
    end
  end

  module PropertyDefinitionExt
    def support_card_selector?
      property_type.class == ::PropertyType::CardType
    end
  end
  
  
  module ProjectVariableExt
    def support_card_selector?
      data_type == ::ProjectVariable::CARD_DATA_TYPE
    end
    
    def card_selector_all_values_mql
      card_type && card_type.card_selector_context_mql
    end
    def card_selector_all_values_search_context
      card_type && card_type.card_selector_search_context
    end
  end
  
  ::CardType.send(:include, CardTypeExt)
  ::PropertyDefinition.send(:include, PropertyDefinitionExt)
  ::CardTypeDefinition.send(:include, PropertyDefinitionExt)
  ::CardRelationshipPropertyDefinition.send(:include, CardRelationshipExt)
  ::TreeRelationshipPropertyDefinition.send(:include, TreeRelationshipExt)
  ::ProjectVariable.send(:include, ProjectVariableExt)

  class Factory
    def self.create_card_selector(context_provider, action_type)
      return unless context_provider.support_card_selector?
      new(context_provider).card_selector(action_type)
    end
    
    def initialize(context_provider)
      @context_provider = context_provider
    end
    
    def card_selector(action_type)
      CardSelector.new(@context_provider.project, send("#{action_type}_card_selector_attrs"))
    end
    
    def edit_card_selector_attrs
      { 
        :title => "Select card for #{@context_provider.name}", 
        :context_mql => @context_provider.card_selector_all_values_mql,
        :search_context => @context_provider.card_selector_all_values_search_context
      }      
    end
    
    def filter_card_selector_attrs
      { 
        :title => "Select card for #{@context_provider.name}", 
        :context_mql => @context_provider.card_selector_filter_values_mql,
        :search_context => @context_provider.card_selector_filter_values_search_context,
        :card_result_attribute => 'number'
      }      
    end
    
    def history_filter_card_selector_attrs
      { 
        :title => "Select card for #{@context_provider.name}", 
        :context_mql => @context_provider.card_selector_filter_values_mql,
        :search_context => @context_provider.card_selector_filter_values_search_context
      }      
    end    
  end
  
  attr_reader :title, :attributes
  
  def initialize(project, attributes={})
    @attributes = attributes
    @project = project
    @context_mql = attributes[:context_mql]
    @search_context = attributes[:search_context]
    @title = attributes[:title]
    @card_result_attribute = attributes[:card_result_attribute]
  end
  
  def context_query
    @context_query ||= CardQuery.parse(@context_mql)
  end
  
  def filter_by(filter=nil, pagination={})
    find(filter, pagination)
  end
  
  def search(q, pagination={})
    search = Search::Client.new(:results_limit => RESULT_LIMIT, :highlight => false)
    search_fields = ['name']
    search_fields << 'number' if q.strip =~ /^(\d+)$/
    q = "(number:#{$1} OR \"#{q.strip}\")" if q.strip =~ /^#(\d+)$/
    q = "(#{q}) AND #{@search_context}" if @search_context.present?
    search.find(:q => q, :search_fields => search_fields, :type => Card.elastic_options[:type])
  end

  def card_types
    context_query.implied_card_types
  end
  
  def card_type_filters
    if card_types.size > 1
      Filters.new @project, []
    else
      Filters.new @project, card_types.collect{|c| "[type][is][#{c.name}]"}
    end
  end
  
  def card_result_value(card)
    card.send(@card_result_attribute || :id).to_s
  end
  
  def to_filter(parent_constraints)
    parent_constraints ||= {}
    filter_strings = parent_constraints.collect do |key, value|
      next if value == CardSelection::MIXED_VALUE
      "[#{key}][is][#{@project.property_value(key, value).url_identifier}]"
    end.compact
    Filters.new(@project, filter_strings)
  end
  
  private
  def find(query, pagination={})
    finder = pagination[:page] ? :paginate : :find

    select_id_query = context_query.restrict_with(query).find_column_value_sql(:id)
    joins = "INNER JOIN (#{select_id_query}) card_query_cond_alias ON card_query_cond_alias.id = #{Card.quoted_table_name}.id"

    @project.cards.send(finder, :all, pagination.merge(:joins => joins))
  end
  
  def single_card_query(number)
    CardQuery.parse("NUMBER = #{number}") 
  end
end
