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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class ElasticSearchIndexingTest < Test::Unit::TestCase
  include ElasticSearch::Indexing

  def setup
    @exec_logs = []
    @mock_client = mock
  end

  def exec(*args)
    raise @exec_error if @exec_error
    @exec_logs << args
    if @exec_result
      @exec_result
    end
  end

  def aws_es
    @mock_client
  end

  def test_reindex_for_installer
    reindex('id', {:body => 'body'}, 'index_name', 'type')

    assert_equal [[:put, '/index_name/type/id', {:body=>"{\"body\":\"body\"}"}]], @exec_logs
  end

  def test_reindex_for_saas
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      @mock_client.expects(:index).with('id', {:body => 'body'}, 'index_name', 'type')

      reindex('id', {:body => 'body'}, 'index_name', 'type')
    end
  end



  def test_should_add_search_namespace_to_doc_id_and_doc_field_when_reindex_the_doc_for_installer
    MingleConfiguration.with_search_namespace_overridden_to('true') do
      MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
        reindex('id', {:body => 'body'}, 'index_name', 'type')

        assert_equal 1, @exec_logs.size
        assert_equal :put, @exec_logs[0][0]
        assert_equal '/index_name/type/__ns__evil-bank-id', @exec_logs[0][1]
        assert_equal({'body' => 'body', 'namespace' => '__ns__evil-bank'}, JSON.parse(@exec_logs[0][2][:body]))
      end
    end
  end

  def test_should_add_search_namespace_to_doc_id_and_doc_field_when_reindex_the_doc_for_saas
    MingleConfiguration.overridden_to(search_namespace: true,
                                      saas_env: 'test',
                                      multitenancy_mode: true,
                                      app_namespace: 'evil-bank') do
      @mock_client.expects(:index).with('__ns__evil-bank-id', {:body => 'body', 'namespace' => '__ns__evil-bank'}, 'index_name', 'type')

      reindex('id', {:body => 'body'}, 'index_name', 'type')
    end
  end

  def test_search
    search('query', {:body => 'body'}, 'index_name', 'type')
    assert_equal [[:get, '/index_name/type/_search', {:query => 'query', :body => '{"body":"body"}'}]], @exec_logs
  end

  def test_search_when_saas_env
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      @mock_client.expects(:search).with('index_name', {query: {bool: {filter: []}}})
      search('query', {query: {bool: {filter: []}}}, 'index_name', nil)
    end
  end

  def test_search_should_add_namespace_filter_when_namespace_exists_and_saas_env
    MingleConfiguration.overridden_to(search_namespace: true,
                                      saas_env: 'test',
                                      multitenancy_mode: true,
                                      app_namespace: 'evil-bank') do
      @mock_client.expects(:search).with('index_name', {query: {bool: {filter: {bool: {must: [{term: {'namespace' => '__ns__evil-bank'}}]}}}}}).returns({'hits' => {'hits' => []}})
      search('query', {query: {bool: {filter: {bool: {must: []}}}}}, 'index_name', nil)
    end
  end

  def test_search_should_add_namespace_filter_when_namespace_exists_and_saas_env_and_filter_clause_is_an_array
    MingleConfiguration.overridden_to(search_namespace: true,
                                      saas_env: 'test',
                                      multitenancy_mode: true,
                                      app_namespace: 'evil-bank') do
      @mock_client.expects(:search).with('index_name', {query: {bool: {filter: [{term: {'namespace' => '__ns__evil-bank'}}]}}}).returns({'hits' => {'hits' => []}})
      search('query', {query: {bool: {filter: []}}}, 'index_name', nil)
    end
  end

  def test_search_should_filter_by_search_namespace_if_it_exists
    MingleConfiguration.with_search_namespace_overridden_to('true') do
      MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
        @exec_result = {'took' =>  4,
                        'hits' => {'total' => 1,
                                   'hits' =>  [
                     {
                         '_index' => 'helloworld',
                         '_type' => 'murmurs',
                         '_id' => '__ns__evil-bank-2',
                         'namespace' => '__ns__evil-bank'
                     }
                    ]
          }
        }

        search('query', {:body => 'body'}, 'index_name', 'type')
        assert_equal 1, @exec_logs.size
        assert_equal :get, @exec_logs[0][0]
        assert_equal '/index_name/type/_search', @exec_logs[0][1]
        body = JSON.parse(@exec_logs[0][2][:body])
        expected = {
            'body' => 'body',
            'filter' => {
              'term' => {
                'namespace' => '__ns__evil-bank'
            }
          }
        }
        assert_equal(expected, body)
      end
    end
  end

  def test_deindex_installer
    ids_to_deindex = ['id1', 'id2']
    deindex(ids_to_deindex, 'index_name', 'type')

    assert_equal [[:post, '/index_name/type/_bulk', {:body => "{\"delete\":{\"_id\":\"id1\"}}\n{\"delete\":{\"_id\":\"id2\"}}\n"}]], @exec_logs
  end

  def test_deindex_saas
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      ids_to_deindex = ['id1', 'id2']
      @mock_client.expects(:delete).with(ids_to_deindex, 'index_name', 'type')

      deindex(ids_to_deindex, 'index_name', 'type')
    end
  end

  def test_deindex_should_include_search_namespace_if_it_exists_for_installer
    namespaced_ids = %w(__ns__evil-bank-id1 __ns__evil-bank-id2)
    MingleConfiguration.with_search_namespace_overridden_to('true') do
      MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
        deindex(['id1', 'id2'], 'index_name', 'type')
        assert_equal 1, @exec_logs.size
        assert_equal :post, @exec_logs[0][0]
        assert_equal '/index_name/type/_bulk', @exec_logs[0][1]
        expected = [
                    {
                      'delete' => {
                          '_id' => namespaced_ids[0]
                      }
                    },
                    {
                      'delete' => {
                          '_id' => namespaced_ids[1]
                      }
                    }
                   ]
        body = @exec_logs[0][2][:body].strip.split("\n").map {|doc| JSON.parse(doc)}
        assert_equal(expected, body)
      end
    end
  end

  def test_deindex_should_include_search_namespace_if_it_exists_for_saas
    namespaced_ids = %w(__ns__evil-bank-id1 __ns__evil-bank-id2)
    @mock_client.expects(:delete).with(namespaced_ids, 'index_name', 'type')

    MingleConfiguration.overridden_to(search_namespace: true,
                                      saas_env: 'test',
                                      multitenancy_mode: true,
                                      app_namespace: 'evil-bank') do
      deindex(['id1', 'id2'], 'index_name', 'type')
    end
  end

  def test_deindex_for_project_installer
    deindex_for_project('project_id', 'index_name')
    expected = [
      :delete,
      '/index_name/_query',
      {:body=>"{\"query\":{\"term\":{\"project_id\":\"project_id\"}}}"}
    ]
    assert_equal expected, @exec_logs[0]
  end

  def test_deindex_for_saas
    MingleConfiguration.overridden_to(saas_env: 'test', multitenancy_mode: true) do
      @mock_client.expects(:delete_by_query).with('index_name', {'query' =>{'term' =>{'project_id' => 'project_id'}}})
      deindex_for_project('project_id', 'index_name')
    end
  end

  def test_deindex_for_project_should_include_namespace_in_query_if_it_exists_in_installer
    MingleConfiguration.with_search_namespace_overridden_to('true') do
      MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
        deindex_for_project('project_id', 'index_name')

        expected_query = {
            'query' => {
                'bool' => {
                    'must' => [
                        {
                            'term' => {
                                'project_id' => 'project_id'
                            }
                        },
                        {
                            'term' => {
                                'namespace' => '__ns__evil-bank'
                            }
                        }
                    ]
                }
            }
        }

        assert_equal 1, @exec_logs.size
        assert_equal :delete, @exec_logs[0][0]
        assert_equal '/index_name/_query', @exec_logs[0][1]
        assert_equal expected_query, JSON.parse(@exec_logs[0][2][:body])
      end
    end
  end


  def test_deindex_for_project_should_include_namespace_in_query_if_it_exists_in_saas_mode
    MingleConfiguration.overridden_to(search_namespace: true,
                                      saas_env: 'test',
                                      multitenancy_mode: true,
                                      app_namespace: 'evil-bank') do
      expected_query = {
          'query' => {
              'bool' => {
                  'must' => [
                      {
                          'term' => {
                              'project_id' => 'project_id'
                          }
                      },
                      {
                          'term' => {
                              'namespace' => '__ns__evil-bank'
                          }
                      }
                  ]
              }
          }
      }
      @mock_client.expects(:delete_by_query).with('index_name', expected_query)

      deindex_for_project('project_id', 'index_name')
    end
  end

  def test_deindex_for_site_should_only_include_namespace_in_query_for_installer
    MingleConfiguration.with_search_namespace_overridden_to('true') do
      MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
        clean_site_documents('site_name')

        expected_query = {
            'query' => {
                'term' => {
                    'namespace' => '__ns__site_name'
                }
            }
        }
        assert_equal 1, @exec_logs.size
        assert_equal :delete, @exec_logs[0][0]
        assert_equal '/evil-bank/_query', @exec_logs[0][1]
        assert_equal expected_query, JSON.parse(@exec_logs[0][2][:body])
      end
    end
  end

  def test_deindex_for_site_should_only_include_namespace_in_query_for_saas
    MingleConfiguration.overridden_to(search_namespace: true,
                                      saas_env: 'test',
                                      multitenancy_mode: true,
                                      app_namespace: 'evil-bank') do
      expected_query = {
          'query' => {
              'term' => {
                  'namespace' => '__ns__site_name'
              }
          }
      }
      @mock_client.expects(:delete_by_query).with('evil-bank', expected_query)

      clean_site_documents('site_name')
    end
  end

  def test_update_index_with_mappings_if_search_namespace_when_index_exists
    MingleConfiguration.with_search_index_name_overridden_to('search-index') do
      create_index_with_mappings
      assert_equal 5, @exec_logs.size
      assert_equal :put, @exec_logs[0][0]

      types = ['_default_', 'cards', 'murmurs', 'pages', 'dependencies']
      types.each_with_index do |type, index|
        assert_equal "/search-index/#{type}/_mapping", @exec_logs[index][1]
      end
    end
  end

  def test_create_index_with_mappings_if_search_namespace
    MingleConfiguration.with_search_index_name_overridden_to('search-index') do
      begin
        def ElasticSearch.index_missing?
          true
        end

        create_index_with_mappings
        assert_equal 1, @exec_logs.size
        assert_equal :post, @exec_logs[0][0]
        assert_equal '/search-index', @exec_logs[0][1]
        index_body = {
            'mappings' => {
              '_default_' => {'date_detection' => false, 'properties' => {'namespace' => {'type' => 'string', 'index' => 'not_analyzed'}}},
              'murmurs' => {'date_detection' => false, 'properties' => {'namespace' => {'type' => 'string', 'index' => 'not_analyzed'}}},
              'pages' => {'date_detection' => false, 'properties' => {'namespace' => {'type' => 'string', 'index' => 'not_analyzed'}}},
              'cards' => {'date_detection' => false, 'properties' => {'namespace' => {'type' => 'string', 'index' => 'not_analyzed'}}},
              'dependencies' => {
                'date_detection' => false,
                'properties' => {'namespace' => {'type' => 'string', 'index' => 'not_analyzed'},
                                 'depnum' => {'type' => 'string'},
                                 'desired_end_date' =>{'type' => 'date', 'format' => 'date_optional_time||date||date_time||date_time_no_millis'},
                                 'desired_completion_date' =>{'type' => 'date', 'format' => 'date_optional_time||date||date_time||date_time_no_millis'},
                                 'raising_project_id' => {'type' => 'long'},
                                 'raising_card_id' => {'type' => 'long'},
                                 'raising_card_number' => {'type' => 'long'},
                                 'resolving_project_id' => {'type' => 'long'}
              }
            }
          }
        }
        assert_equal(index_body, JSON.parse(@exec_logs[0][2][:body]))
      ensure
        def ElasticSearch.index_missing?
          false
        end
      end
    end
  end

  def test_should_continue_if_connection_refused
    @exec_error = ElasticSearch::NetworkError.new('Connection refused')
    MingleConfiguration.with_search_index_name_overridden_to('search-index') do
      assert_nil create_index_with_mappings
    end
  end

  def test_search_doc_namespace
    assert_equal '__ns__', ElasticSearch::Indexing::Namespace.search_doc_namespace
    MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
      assert_equal '__ns__evil-bank', ElasticSearch::Indexing::Namespace.search_doc_namespace
    end
  end

  def test_search_result_should_not_contain_namespace_in_id_when_namespace_is_indexed_with_doc_id
    MingleConfiguration.with_search_namespace_overridden_to('true') do
      MingleConfiguration.with_app_namespace_overridden_to('evil-bank') do
        @exec_result = {'took' =>  4,
                        'hits' => {'total' => 1,
                                   'hits' =>  [
                     {
                         '_index' => 'helloworld',
                         '_type' => 'murmurs',
                         '_id' => '__ns__evil-bank-2',
                         '_score' => 0.5444944,
                         'namespace' => '__ns__evil-bank'
                     }
                    ]
          }
        }

        response = search('query', {:q => 'whatever'}, 'helloworld', 'murmurs')
        expected = {'took' =>  4,
                    'hits' => {'total' => 1,
                               'hits' =>  [
                     {
                         '_index' => 'helloworld',
                         '_type' => 'murmurs',
                         '_id' => '2',
                         '_score' => 0.5444944,
                         'namespace' => '__ns__evil-bank'
                     }
                    ]
          }
        }
        assert_equal expected, response
      end
    end
  end


  def test_search_result_should_not_contain_namespace_in_id_when_namespace_is_indexed_with_doc_id_and_saas_env
    MingleConfiguration.overridden_to(search_namespace: true, app_namespace: 'evil-bank', saas_env: 'test', multitenancy_mode: true) do
      result = {'took' => 4,
                      'hits' => {'total' => 1,
                                 'hits' => [
                                   {
                                     '_id' => 'cards-__ns__evil-bank-2',
                                     '_score' => 0.5444944,
                                     'namespace' => '__ns__evil-bank'
                                   },
                                   {
                                     '_id' => 'murmurs-__ns__evil-bank-24',
                                     '_score' => 0.54449,
                                     'namespace' => '__ns__evil-bank'
                                   },
                                   {
                                     '_id' => 'dependencies-__ns__evil-bank-75',
                                     '_score' => 0.54449,
                                     'namespace' => '__ns__evil-bank'
                                   }
                                 ]
                      }
      }
      @mock_client.expects(:search).returns(result)

      response = search('query', {query: {bool: {filter: []}}}, 'helloworld', 'murmurs')
      expected = {'took' => 4,
                  'hits' => {'total' => 1,
                             'hits' => [
                               {
                                 '_id' => '2',
                                 '_score' => 0.5444944,
                                 'namespace' => '__ns__evil-bank'
                               },
                               {
                                 '_id' => '24',
                                 '_score' => 0.54449,
                                 'namespace' => '__ns__evil-bank'
                               },
                               {
                                 '_id' => '75',
                                 '_score' => 0.54449,
                                 'namespace' => '__ns__evil-bank'
                               }
                             ]
                  }
      }
      assert_equal expected, response
    end
  end
end
