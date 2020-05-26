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

class ResultTest < ActiveSupport::TestCase

  def test_should_translate_page_results_to_page
    response = {
                  "_type" => "pages",
                  "_id" => "1",

                  "_source" => {
                    "name" => "my name",
                    "tag_names" => ["tag1", "tag2"],
                    "indexable_content" => "page content"
                  }
               }

    result = Result::Page.new(response)

    assert_equal "pages", result.type
    assert_equal "1", result.identifier
    assert_equal "my name", result.name
    assert_equal ["tag1", "tag2"], result.tags
    assert_equal "page content", result.content
  end

  def test_should_translate_card_results_to_card
    response = {
                  "_type" => "cards",
                  "_id" => "1",

                  "_source" => {
                    "name" => "my name",
                    "tag_names" => ["tag1", "tag2"],
                    "number" => "123",
                    "indexable_content" => "card description"
                  }
               }

    result = Result::Card.new(response)

    assert_equal "cards", result.type
    assert_equal "1", result.identifier
    assert_equal "my name", result.name
    assert_equal ["tag1", "tag2"], result.tags
    assert_equal "123", result.number
    assert_equal "card description", result.short_description
  end

  def test_should_translate_murmur_results_to_murmur
    response = {
                  "_type" => "murmurs",
                  "_id" => "1",

                  "_source" => {
                    "author" => {"name" => "user name"},
                    "murmur" => "some murmur",
                  }
               }

    result = Result::Murmur.new(response)

    assert_equal "murmurs", result.type
    assert_equal "1", result.identifier
    assert_equal "some murmur", result.murmur
    assert_equal "user name", result.user_display_name
  end

  def test_should_use_highlight_result_when_present_for_page
    response = {
                  "_type" => "pages",
                  "_source" => {"indexable_content" => "page content"},
                  "highlight" => { "indexable_content" => ["<b>page</b> content"]}
               }

    result = Result::Page.new(response)
    assert_equal "#{Result::FRAGMENT_PRE}<b>page</b> content#{Result::FRAGMENT_POST}", result.content
  end

  def test_should_use_highlight_result_when_present_for_card
    response = {
                  "_type" => "cards",
                  "_source" => {"indexable_content" => "page content"},
                  "highlight" => { "indexable_content" => ["<b>card</b> content"]}
               }

    result = Result::Card.new(response)
    assert_equal "#{Result::FRAGMENT_PRE}<b>card</b> content#{Result::FRAGMENT_POST}", result.short_description
  end

  def test_should_use_highlight_result_when_present_for_murmur
    response = {
                  "_type" => "cards",
                  "_source" => {"murmur" => "murmur content"},
                  "highlight" => { "murmur" => ["<b>murmur</b> content"]}
               }

    result = Result::Murmur.new(response)
    assert_equal "#{Result::FRAGMENT_PRE}<b>murmur</b> content#{Result::FRAGMENT_POST}", result.murmur
  end

  def test_should_know_how_to_show_multiple_highlighted_results
    response = {
                  "_type" => "cards",
                  "_source" => {"murmur" => "murmur content and some other murmur content"},
                  "highlight" => { "murmur" => ["<b>murmur</b> content", "other <b>murmur</b> content"]}
               }

    result = Result::Murmur.new(response)
    assert_equal ["#{Result::FRAGMENT_PRE}<b>murmur</b> content#{Result::FRAGMENT_POST}", "#{Result::FRAGMENT_PRE}other <b>murmur</b> content#{Result::FRAGMENT_POST}"].join("\n"), result.murmur
  end

  def test_should_interpret_empty_fields_as_blank
    response = {
                  "_type" => "murmurs",
                  "_id" => "1",
                  "_source" => {
                    "author" => {"name" => "user name"}
                  }
               }

    result = Result::Murmur.new(response)

    assert_equal "", result.murmur
  end

  def test_should_not_highlight_page_name_in_url_identifier
    response = {
                  "_type" => "pages",
                  "_source" => {"name" => "hello"},
                  "highlight" => { "name" => ["<strong>hello</strong>"]}
               }

    result = Result::Page.new(response)
    assert_equal "hello", result.url_identifier
  end

  def test_includes_properties_should_be_false_when_not_present_in_result
    response = {
                  "_type" => "cards",
                  "_source" => {
                      "description" => "As a _____"
                    },
                  "highlight" => { "description" => ["<b>card</b> content"]},
               }
    result = Result::Card.new(response)
    assert_equal false, result.includes_properties?
  end

  
  def test_includes_properties_should_be_true_when_value_is_empty_hash
    response = {
                  "_type" => "cards",
                  "_source" => {
                      "description" => "As a _____", 
                      "properties_to_index" => { }
                    },
                  "highlight" => { "description" => ["<b>card</b> content"]},
               }
    result = Result::Card.new(response)
    assert_equal true, result.includes_properties?
  end
  
  def test_includes_properties_should_be_true_when_value_contains_some_properties
    response = {
                  "_type" => "cards",
                  "_source" => {
                      "description" => "As a _____", 
                      "properties_to_index" => { "Status" => "Done" }
                    },
                  "highlight" => { "description" => ["<b>card</b> content"]},
               }
    result = Result::Card.new(response)
    assert_equal true, result.includes_properties?
  end

  def test_should_get_type_from_source_when_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      response = {
          '_type' => 'document',
          '_source' => {
              'type' => 'cards'
          }
      }
      result = Result::Card.new(response)
      assert_equal 'cards', result.type
    end
  end

  def test_for_should_create_result_from_type_in_source_when_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      response = {
          '_type' => 'document',
          '_source' => {
              'type' => 'pages'
          }
      }
      result = Result.for(response)
      assert_equal Result::Page, result.class
    end
  end

  def test_for_should_create_result_from_type
    response = {
        '_type' => 'cards',
        '_source' => {
            'name' => 'foo'
        }
    }
    result = Result.for(response)
    assert_equal Result::Card, result.class
  end

  def test_should_remove_prefix_from_the_highlighted_property_result_when_present_for_card
    response = {
        "_type" => "cards",
        "_source" => {"indexable_content" => "page content"},
        "highlight" => { "properties_to_index.status" => ["<b>TO</b> Do"]}
    }

    result = Result.for(response)
    expected = {"status" => ["<b>TO</b> Do"]}
    assert_equal expected , result.properties
  end

  def test_should_return_the_highlighted_property_name_with_the_value_when_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      response = {
          '_type' => 'document',
          '_source' => {'indexable_content' => 'page content', 'type' => 'cards'},
          'inner_hits' => {'properties_to_index' => {
              'hits' => {
                  'hits' => [
                      {'highlight' => {
                          'properties_to_index.name' => ['<b>priority</b>']
                      },
                      '_source' => {'name' => 'priority', 'value' => 'not important'}}
                  ]
              }
          }}
      }

      result = Result.for(response)
      expected = {'<b>priority</b>' => ['not important']}
      assert_equal expected , result.properties
    end
  end

  def test_should_return_the_highlighted_property_value_with_the_name_when_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      response = {
          '_type' => 'document',
          '_source' => {'indexable_content' => 'page content', 'type' => 'cards'},
          'inner_hits' => {'properties_to_index' => {
              'hits' => {
                  'hits' => [
                      {'highlight' => {
                          'properties_to_index.value' => ['<b>high priority</b>']
                      },
                       '_source' => {'name' => 'priority', 'value' => 'high priority'}}
                  ]
              }
          }}
      }

      result = Result.for(response)
      expected = {'priority' => ['<b>high priority</b>']}
      assert_equal expected , result.properties
    end
  end

  def test_should_return_the_highlighted_property_value_with_the_highlighted_name_when_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      response = {
          '_type' => 'document',
          '_source' => {'indexable_content' => 'page content', 'type' => 'cards'},
          'inner_hits' => {'properties_to_index' => {
              'hits' => {
                  'hits' => [
                      {'highlight' => {
                          'properties_to_index.value' => ['<b>high priority</b>'],
                          'properties_to_index.name' => ['<b>priority</b>']
                      },
                       '_source' => {'name' => 'priority', 'value' => 'high priority'}}
                  ]
              }
          }}
      }

      result = Result.for(response)
      expected = {'<b>priority</b>' => ['<b>high priority</b>']}
      assert_equal expected , result.properties
    end
  end
end
