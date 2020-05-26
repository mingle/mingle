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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fake_credentials')
module Aws
  class RequestSignerSpec < ActiveSupport::TestCase
    def test_should_sign_the_request
      travel_to(Time.parse('2016-11-17 21:45:00 UTC')) do
        expected_auth = 'AWS4-HMAC-SHA256 Credential=fake_access_key_id/20161117/region/service-name/aws4_request, ' +
            'SignedHeaders=host;x-amz-content-sha256;x-amz-date, ' +
            'Signature=74ade29485e46165db7cdcc0c098131d47bdf8e5805aba0e3a7c45fb4f517d98'
        content_sha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        req = Net::HTTP::Get.new(URI.parse'https://randomdomain.com/path/for/request?with=query&params=true')
        signer = RequestSigner.new(FakeCredentials.new, 'service-name', 'region')

        signed_request = signer.sign(req)

        assert_equal expected_auth, signed_request['authorization']
        assert_equal content_sha256, signed_request['x-amz-content-sha256']
        assert_equal Time.now.utc.strftime('%Y%m%dT%H%M%SZ'), signed_request['x-amz-date']
      end
    end
  end
end
