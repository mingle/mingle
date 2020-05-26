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

module Result
  FRAGMENT_PRE = "<span class=\"fragment\">&hellip;"
  FRAGMENT_POST = '&hellip;</span>'
  FRAGMENT_SIZE = 250

  def initialize(result)
    @result = result
  end

  def type
    MingleConfiguration.saas? ? @result['_source']['type'] : @result['_type']
  end

  def identifier
    @result['_id']
  end

  def name
    [value('name')].flatten.join
  end

  def tags
    value('tag_names') || []
  end

  def checklist_items
    value('checklist_items_texts') || []
  end

  def includes_properties?
    @result['_source']['properties_to_index'] != nil
  end

  def value(key)
    if highlighted?(key)
      @result['highlight'][key]
    else
      @result['_source'][key]
    end
  end

  def fragmented_value(key)
    if highlighted?(key)
      value(key).map { |v| "#{FRAGMENT_PRE}#{v}#{FRAGMENT_POST}" }.join("\n")
    else
      (value(key) || '').truncate_with_ellipses(FRAGMENT_SIZE)
    end
  end

  def highlighted?(key)
    @result.has_key?('highlight') && @result['highlight'].has_key?(key)
  end

  def for(result)
    type = MingleConfiguration.saas? ? result['_source']['type'] : result['_type']
    result_class = "Result::#{type.singularize.classify}".constantize
    result['highlight'] = process_highlighted_content(result) if result.has_key?('highlight')
    result_class.send(:new, result)
  end

  private
  def process_highlighted_content(result)
    highlighted_result = {}
    result['highlight'].each do |key, value|
      highlighted_result[key.gsub('properties_to_index.', '')] = value
    end
    highlighted_result
  end

  module_function :for, :process_highlighted_content

  class Page
    include Result

    def content
      fragmented_value 'indexable_content'
    end

    def url_identifier
      @result['_source']['name']
    end

    def name
      result = value('name')
      result.to_s.html_safe
    end

  end

  class Card
    include Result

    def short_description
      fragmented_value 'indexable_content'
    end

    def number
      value('number') || ''
    end

    def card_type_name
      value('card_type_name') || ''
    end

    def card_type
      Project.current.card_types.detect { |ct| ct.id == card_type_id.to_i }
    end

    def card_type_id
      value('card_type_id') || ''
    end

    def properties
      props = (@result['highlight'] || {}).except('indexable_content', 'tag_names', 'checklist_items_texts',
                                                  'raises_dependencies', 'resolves_dependencies')
      if MingleConfiguration.saas?
        props.merge!(properties_from_inner_hits)
      end
      props
    end

    def raises_dependencies
      value('raises_dependencies') || []
    end

    def resolves_dependencies
      value('resolves_dependencies') || []
    end

    alias :id :identifier

    private

    def properties_from_inner_hits
      props = {}
      @result['inner_hits']['properties_to_index']['hits']['hits'].each do |property|
        if property['highlight'].key?('properties_to_index.name')
          props["#{property['highlight']['properties_to_index.name'].join()}"] = [property['_source']['value']]
          if property['highlight'].key?('properties_to_index.value')
            props["#{property['highlight']['properties_to_index.name'].join()}"] = property['highlight']['properties_to_index.value']
          end
        else
          props["#{property['_source']['name']}"] = property['highlight']['properties_to_index.value']
        end
      end
      props
    end
  end

  class Murmur
    include Result

    def user_display_name
      value('author')['name']
    end

    def murmur
      fragmented_value 'murmur'
    end

  end

  class Dependency
    include Result

    def number_and_name
      value('number_and_name')
    end

    def number
      value 'depnum'
    end

    def raised_by_card
      (value('raised_by_card') || []).first
    end

    def resolved_by_cards
      value('resolved_by_cards') || []
    end

    def properties
      (@result['highlight'] || {}).except('depnum', 'name', 'number_and_name', 'description',
                                          'raising_project_id', 'resolving_project_id', 'raising_card_id',
                                          'raising_card_number', 'raised_by_card', 'resolved_by_cards')
    end

    def raising_project_id
      @result['_source']['raising_project_id'].to_i
    end

    def content
      fragmented_value 'description'
    end

    def raised_by_project
      @result['_source']['raised_by_project']
    end

    def resolved_by_project
      @result['_source']['resolved_by_project']
    end
  end

  class ResultSet < Array
    attr_reader :total_entries, :per_page

    def initialize(results_limit=0, total_entries=0)
      @per_page = results_limit
      @total_entries = total_entries.to_i
    end

    def total_pages
      size == 0 ? 0 : @total_entries.to_f/size
    end
  end

end
