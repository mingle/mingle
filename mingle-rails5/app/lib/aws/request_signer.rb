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

module Aws
  class RequestSigner
    def initialize(credentials, service_name, region)
      @signer = Aws::Sigv4::Signer.new(
          service: service_name,
          region: region,
          access_key_id: credentials.access_key_id,
          secret_access_key: credentials.secret_access_key,
          session_token: credentials.session_token
      )
    end

    def sign(req)
      signature = @signer.sign_request(
          http_method: req.method,
          url: req.uri,
          body: req.body
      )
      req['x-amz-date'] = signature.headers['x-amz-date']
      req['host'] = signature.headers['host']
      req['x-amz-security-token'] = signature.headers['x-amz-security-token']
      req['x-amz-content-sha256'] = signature.headers['x-amz-content-sha256']
      req['authorization'] = signature.headers['authorization']
      req
    end
  end
end
