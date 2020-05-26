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

class ElasticSearchClientTest < ActiveSupport::TestCase

  def test_init_should_initialise_client
    es_endpoint = 'https://www.elastic-search.com'
    aws_region = 'us-west-1'
    mocked_es_client = mock
    mocked_http_client = mock

    Aws::HttpClient.expects(:new).with(es_endpoint, 'es', aws_region).returns(mocked_http_client)
    Elasticsearch::Client.expects(:new).with(transport: mocked_http_client).returns(mocked_es_client)

    client = Aws::ElasticSearchClient.new(es_endpoint, aws_region)

    assert_equal(mocked_es_client, client.instance_variable_get('@es_client'))
  end

  def test_create_index_with_mappings_should_create_index_if_it_doesnt_exist
    indices_stub = stub
    Elasticsearch::Client.stubs(:new).returns(stub(indices: indices_stub))

    indices_stub.expects(:exists?).once.returns(false)
    indices_stub.expects(:create).once.with(index: 'mingle', body: body.to_json).returns({errors: false}.to_json)

    Aws::ElasticSearchClient.new('url', 'region').create_index_with_mappings('mingle')
  end

  def test_create_index_with_mappings_should_put_mappings_and_settings_if_the_index_already_exists
    indices_stub = stub
    Elasticsearch::Client.stubs(:new).returns(stub(indices: indices_stub))

    indices_stub.expects(:exists?).once.returns(true)
    indices_stub.expects(:put_mapping).once.with(index: 'mingle', type: 'document', body: mappings.to_json).returns({errors: false}.to_json)
    indices_stub.expects(:put_settings).once.with(index: 'mingle', body: dynamic_settings.to_json).returns({errors: false}.to_json)
    Aws::ElasticSearchClient.new('url', 'region').create_index_with_mappings('mingle')
  end

  def test_index_should_index_document
    Timecop.freeze do
      stubbed_client = stub
      Elasticsearch::Client.stubs(:new).returns(stubbed_client)

      stubbed_client.expects(:index).once.with(id: 'card-id', index: 'mingle', type: 'document', body: {name: 'hello', properties_to_index: [], type: 'card', timestamp: (Time.now.to_f * 1000).to_i}.to_json).returns({errors: false}.to_json)
      Aws::ElasticSearchClient.new('url', 'region').index('id', {name: 'hello'}, 'mingle', 'card')
    end
  end

  def test_index_should_modify_properties_structure
    Timecop.freeze do
      stubbed_client = stub
      Elasticsearch::Client.stubs(:new).returns(stubbed_client)
      properties = [{'name' => 'status', 'value' => 'done'}, {'name' => 'estimate', 'value' => 12}]
      stubbed_client.expects(:index).once.with(id: 'card-id', index: 'mingle', type: 'document', body: {name: 'hello', properties_to_index: properties, type: 'card', timestamp: (Time.now.to_f * 1000).to_i}.to_json).returns({errors: false}.to_json)
      Aws::ElasticSearchClient.new('url', 'region').index('id', {name: 'hello', properties_to_index: {status: 'done', estimate: 12}}, 'mingle', 'card')
    end
  end

  def test_delete_should_bulk_delete_documents
    stubbed_client = stub
    Elasticsearch::Client.stubs(:new).returns(stubbed_client)

    stubbed_client.expects(:bulk).once.with(body: [{delete: {_id: 'pages-11', _index: 'mingle', _type: 'document'}},
                                                   {delete: {_id: 'pages-25', _index: 'mingle', _type: 'document'}}]).returns({errors: false}.to_json)
    Aws::ElasticSearchClient.new('url', 'region').delete(%w(11 25), 'mingle', 'pages')
  end

  def test_delete_by_query_should_delete_documents
    stubbed_client = stub
    Elasticsearch::Client.stubs(:new).returns(stubbed_client)

    query = {query: {bool: {must: [{term: {project_id: 6}}, {term: {namespace: '__ns__tenantname'}}]}}}
    stubbed_client.expects(:delete_by_query).once.with(index: 'mingle', body: query.to_json).returns({errors: false}.to_json)

    Aws::ElasticSearchClient.new('url', 'region').delete_by_query('mingle', query)
  end

  def test_should_not_initialise_client_if_endpoint_not_passed
    client = Aws::ElasticSearchClient.new(nil, 'region')
    assert_nil(client.instance_variable_get('@es_client'))

    client = Aws::ElasticSearchClient.new('', 'region')
    assert_nil(client.instance_variable_get('@es_client'))
  end

  def test_search_should_return_empty_results_on_error
    es_endpoint = 'https://www.elastic-search.com'
    aws_region = 'us-west-1'
    mocked_es_client = mock
    mocked_http_client = mock

    Aws::HttpClient.expects(:new).with(es_endpoint, 'es', aws_region).returns(mocked_http_client)
    Elasticsearch::Client.expects(:new).with(transport: mocked_http_client).returns(mocked_es_client)
    mocked_es_client.expects(:search).raises(Aws::HttpClient::AWSRequestException)

    client = Aws::ElasticSearchClient.new(es_endpoint, aws_region)
    resp = client.search('', {})

    assert_equal({'hits' => {'hits' =>[], 'total' => 0}}, resp)
  end

  private
  def body
    {
      mappings: mappings,
      settings: {
        analysis: {
          analyzer: {
            mingle: {
              tokenizer: 'standard',
              filter: %w(standard lowercase snowball)
            }
          }
        },
      }.merge(dynamic_settings)
    }
  end

  def dynamic_settings
    {'index.mapping.total_fields.limit' => 1000}
  end

  def mappings
    {
      document:
        {date_detection: false,
         properties: {
           namespace: {type: 'keyword'},
           type: {type: 'keyword'},
           timestamp: {type: 'date'},
           name: {type: 'text', boost: 5, analyzer: 'mingle'},
           murmur: {type: 'text', boost: 2, analyzer: 'mingle'},
           description: {type: 'text', boost: 1, analyzer: 'mingle'},
           indexable_content: {type: 'text', boost: 2, analyzer: 'mingle'},
           properties_to_index: {type: 'nested'}
         }
        }
    }
  end

end
