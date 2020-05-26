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

class S3ImportPolicyDocumentTest < ActiveSupport::TestCase

  def setup
    ENV['AWS_ACCESS_KEY_ID'] = "foo"
    ENV['AWS_SECRET_ACCESS_KEY'] = "bar"
    login_as_admin
  end

  def teardown
    ENV['AWS_ACCESS_KEY_ID'] = nil
    ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  def test_policy_document_should_be_base64_encoded
    doc = S3ImportPolicyDocument.new('ns', 'http://example.com', 1.day)
    assert_not_nil decode_policy(doc)['expiration']
    assert decode_policy(doc)['conditions'].any?
  end

  def test_expiration_in_policy_are_set_in_furture
    doc = S3ImportPolicyDocument.new('ns', 'http://example.com', 1.day + 1.hour)
    expiration = Time.iso8601(decode_policy(doc)['expiration'])
    assert expiration > Time.now + 1.day
  end

  def test_expiration_in_policy_are_set_to_utc_format
    doc = S3ImportPolicyDocument.new('ns', 'http://example.com', 1.day)
    expiration = Time.iso8601(decode_policy(doc)['expiration'])
    assert_equal 'UTC', expiration.zone
  end

  def test_must_provide_namespace
    assert_raise RuntimeError do
      S3ImportPolicyDocument.new('', 'http://example.com', 1.day)
    end
    assert_raise RuntimeError do
      S3ImportPolicyDocument.new(nil, 'http://example.com', 1.day)
    end
  end

  private

  def decode_policy(doc)
    JSON.parse(Base64.decode64(doc.encrypted_policy_document))
  end
end
