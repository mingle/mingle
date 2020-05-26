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

class ElasticSearchAwsEsTest < Test::Unit::TestCase

  def setup
    ElasticSearch.instance_variable_set('@es_client', nil)
  end

  def teardown
    ElasticSearch.instance_variable_set('@es_client', nil)
  end

  def test_init_aws_es_should_initialize_aws_elastic_search_client_and_create_mappings
    es_endpoint = 'https://www.elastic-search.com'
    aws_region = 'us-west-1'
    mocked_client = mock
    Aws::ElasticSearchClient.expects(:new).with(es_endpoint, aws_region).returns(mocked_client)
    mocked_client.expects(:create_index_with_mappings).with('mingle')

    ElasticSearch.init_aws_es(es_endpoint, aws_region)

    assert_equal(mocked_client, ElasticSearch.aws_es)
  end

  def test_aws_es_should_initialize_and_cache_empty_client
    mocked_client = mock
    Aws::ElasticSearchClient.expects(:new).once.with.returns(mocked_client)
    assert_equal(mocked_client, ElasticSearch.aws_es)

    # Should return same instance on next invocation
    assert_equal(mocked_client, ElasticSearch.aws_es)
  end

end
