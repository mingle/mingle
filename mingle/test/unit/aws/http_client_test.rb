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

class HttpClientTest < ActiveSupport::TestCase

  def setup
    Aws::Credentials.stubs(:new).returns(::FakeCredentials.new)
  end

  def test_perform_request_should_throw_an_exception_when_response_status_is_invalid
    stubbed_client = stub
    stubbed_response = stub
    Net::HTTP.stubs(:new).once.returns(stubbed_client)
    stubbed_client.expects(:use_ssl=).returns(true)
    stubbed_client.expects(:request).returns('some_response')
    Aws::SignedHttpResponse.stubs(:new).once.with('some_response').returns(stubbed_response)
    stubbed_response.expects(:body).returns('error message')
    stubbed_response.expects(:status).returns(400)

    assert_raise_with_message Aws::HttpClient::AWSRequestException, 'Error while requesting AWS: error message' do
      Aws::HttpClient.new('url', 'es','region').perform_request('post', '/this_path', {options: 'options'}, 'cards')
    end
  end

  def test_perform_request_should_not_throw_an_exception_when_response_status_is_not_found
    stubbed_client = stub
    stubbed_response = stub
    Net::HTTP.stubs(:new).once.returns(stubbed_client)
    stubbed_client.expects(:use_ssl=).returns(true)
    stubbed_client.expects(:request).returns('some_response')
    Aws::SignedHttpResponse.stubs(:new).once.with('some_response').returns(stubbed_response)
    stubbed_response.expects(:status).returns(404)

    resp =  Aws::HttpClient.new('url', 'es','region').perform_request('post', '/this_path', {options: 'options'}, 'cards')
    assert_equal(stubbed_response, resp)
  end


  def test_perform_request_should_throw_an_exception_on_server_error
    stubbed_client = stub
    stubbed_response = stub
    Net::HTTP.stubs(:new).once.returns(stubbed_client)
    stubbed_client.expects(:use_ssl=).returns(true)
    stubbed_client.expects(:request).returns('some_response')
    Aws::SignedHttpResponse.stubs(:new).once.with('some_response').returns(stubbed_response)
    stubbed_response.expects(:body).returns('error message')
    stubbed_response.expects(:status).returns(500)

    assert_raise_with_message Aws::HttpClient::AWSRequestException, 'Error while requesting AWS: error message' do
      Aws::HttpClient.new('url', 'es','region').perform_request('post', '/this_path', {options: 'options'}, 'cards')
    end
  end
end
