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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class QueryTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
  end

  def teardown
    @project.deactivate
  end

  def test_should_know_query_string
    assert_equal "(where are my car keys?) #{project_id_clause}", Search::Query.new('where are my car keys?').query_string
  end

  def test_should_transform_type_into_card_type_name_for_correct_search
    with_card_prop_def_test_project do |project|
      iteration_type = project.card_types.find_by_name('iteration')
      assert_equal "(chicha libre card_type_id:#{iteration_type.id}) #{project_id_clause}", Search::Query.new('chicha libre type:iteration').query_string
    end
  end

  def test_should_escape_colon_in_urls_so_they_are_not_parsed_as_property_key_and_value
    assert_equal "(http\\://google.com) #{project_id_clause}", Search::Query.new('http://google.com').to_hash[:query][:queryString][:query]
  end

  def test_should_make_query_downcase
    assert_equal "(i am a lowercase query) #{project_id_clause}", Search::Query.new('I Am A LOWERCASE QuERy').query_string
  end

  def test_should_not_downcase_lucene_operators
    assert_equal "(chicha AND libre OR (jurassic AND NOT five)) #{project_id_clause}", Search::Query.new('cHIcha AND LiBre OR (Jurassic AND NOT FIVE)').query_string
  end

  def test_should_serialize_to_elastic_search_format
    expected = {
                 :query => { :queryString => { :fields => [], :default_operator => "AND", :query => "(findme) #{project_id_clause}"} },
                 :highlight => {
                       :encoder => "html",
                       :fragment_size => 250,
                       :number_of_fragments => 3,
                       :pre_tags => ["<span class='term fragment_highlight'>"], :post_tags =>  ["</span>"],
                       :fields => {
                           :indexable_content => {},
                           :description => {},
                           :murmur => {},
                           :name => {:number_of_fragments => 0,
                             :pre_tags => ["<span class='name fragment_highlight'>"], :post_tags =>  ["</span>"],
                           },
                           :tag_names => {},
                           :checklist_items_texts => {},
                           :raises_dependencies => {},
                           :resolves_dependencies => {},
                           :status => {},
                           :raised_by_project => {},
                           :resolved_by_project => {},
                           :raised_by_card => {},
                           :resolved_by_cards => {},
                           "properties_to_index*" => {}
                       }
                 }
              }.to_json
     assert_equal(expected, Search::Query.new('findme').to_json)
  end

  def test_query_not_to_highlight_result
     query = Search::Query.new('findme', :highlight => false).to_json
     assert_equal(nil, ActiveSupport::JSON.decode(query)["highlight"])
   end

  def test_uses_search_field_as_default_search_field
    query_with_filter_json = Search::Query.new('findme', :highlight => false, :search_fields => ["name", "number"]).to_json
    assert_equal(["name", "number"], ActiveSupport::JSON.decode(query_with_filter_json)["query"]["queryString"]["fields"])
  end

  def test_transform_card_type_only_finds_card_types_in_current_project
    story_type = (create_project :skip_activation => true).card_types.create :name => "story"
    assert !story_type.nil?

    with_new_project do |project|
      another_story_type = project.card_types.create :name => "story"
      query = Search::Query.new("type:story elastic").to_json
      result = ActiveSupport::JSON.decode(query)

      assert_equal "(card_type_id:#{another_story_type.id} elastic) #{project_id_clause}", result["query"]["queryString"]["query"]
    end
  end

  def test_CARD_TYPE_REGEX_matches_quoted_names
    assert_equal "double-quote", Search::Query::CARD_TYPE_REGEX.match('type:"double-quote"')[2]
    assert_equal "single-quote", Search::Query::CARD_TYPE_REGEX.match("type:'single-quote'")[2]
    assert_equal "mixed case", Search::Query::CARD_TYPE_REGEX.match("TyPE:'mixed case'")[2]
    assert_equal "multiple words", Search::Query::CARD_TYPE_REGEX.match("type:'multiple words'")[2]
    assert_equal "multiple words", Search::Query::CARD_TYPE_REGEX.match("something in front of type:'multiple words'")[2]
    assert_equal "multiple words", Search::Query::CARD_TYPE_REGEX.match("type:'multiple words' something after")[2]
    assert_nil Search::Query::CARD_TYPE_REGEX.match("my_type:'multiple words'")
    assert_nil Search::Query::CARD_TYPE_REGEX.match('type:"term')
  end

  def test_CARD_TYPE_REGEX_matches_unquoted_single_words
    assert_equal "card", Search::Query::CARD_TYPE_REGEX.match('type:card')[3]
    assert_equal "mixed_case", Search::Query::CARD_TYPE_REGEX.match("TyPE:mixed_case")[3]
    assert_equal "card", Search::Query::CARD_TYPE_REGEX.match("something in front of type:card")[3]
    assert_equal "card", Search::Query::CARD_TYPE_REGEX.match("type:card something after")[3]
    assert_nil Search::Query::CARD_TYPE_REGEX.match("my_type:card")
  end

  def test_query_generated_for_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      expected_query = {
        query: {
          bool: {
            should: [
              {
                nested: {path: 'properties_to_index', query: {bool: {must: [{query_string: {default_operator: 'AND', query: '(search term)'}}]}}}
              },
              {
                query_string: {default_operator: 'AND', query: '(search term)'}
              }
            ],
            minimum_should_match: 1,
            filter: {
              bool: {
                must: [
                  bool: {
                    should: [
                      {term: {project_id: Project.current.id}},
                      {term: {raising_project_id: Project.current.id}},
                      {term: {resolving_project_id: Project.current.id}}
                    ],
                    minimum_should_match: 1
                  }
                ]
              }
            }}
        }
      }


      assert_equal(expected_query, Search::Query.new('search term', search_fields: ['_all'], highlight: false).to_hash)
    end
  end

  def test_query_generated_for_new_es_with_type_size_and_highlight_in_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      expected_query = {
        query: {
          bool: {
            should: [
              {
                nested: {
                  path: 'properties_to_index',
                  query: {bool: {must: [{query_string: {default_operator: 'AND', query: '(search term)'}}]}},
                  inner_hits: inner_hits
                }
              },
              {
                query_string: {default_operator: 'AND', query: '(search term)'}
              }
            ],
            minimum_should_match: 1,
            filter: {
              bool: {
                must: [
                  {
                    bool: {
                      should: [
                        {term: {project_id: Project.current.id}},
                        {term: {raising_project_id: Project.current.id}},
                        {term: {resolving_project_id: Project.current.id}}
                      ],
                      minimum_should_match: 1
                    }
                  },
                  {term: {type: 'murmurs'}}
                ]
              }
            }}
        },
        size: 10,
        highlight: highlight_without_properties}
      assert_equal(expected_query, Search::Query.new('search term', search_fields: ['_all'], highlight: true, size: 10, type: 'murmurs').to_hash)
    end
  end

  private
  def project_id_clause
    "AND (project_id:#{Project.current.id} OR raising_project_id:#{Project.current.id} OR resolving_project_id:#{Project.current.id})"
  end

  def inner_hits
    {
      :highlight =>
        {
          :encoder => 'html',
          :fragment_size => 250,
          :number_of_fragments => 3,
          :pre_tags => ["<span class='term fragment_highlight'>"],
          :post_tags => ['</span>'],
          :fields =>
            {'properties_to_index.name' => {},
             'properties_to_index.value' => {}
            }
        }
    }
  end

  def highlight_without_properties
    {
      :encoder => "html",
      :fragment_size => 250,
      :number_of_fragments => 3,
      :pre_tags => ["<span class='term fragment_highlight'>"],
      :post_tags => ["</span>"],
      :fields =>
        {
          :indexable_content => {},
          :description => {},
          :murmur => {},
          :name =>
            {:number_of_fragments => 0,
             :pre_tags => ["<span class='name fragment_highlight'>"],
             :post_tags => ["</span>"]},
          :tag_names => {},
          :checklist_items_texts => {},
          :raises_dependencies => {},
          :resolves_dependencies => {},
          :status => {},
          :raised_by_project => {},
          :resolved_by_project => {},
          :raised_by_card => {},
          :resolved_by_cards => {}
        }
    }
  end
end
