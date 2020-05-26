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

class S3ImportPolicyDocument
  attr_reader :key

  def initialize(namespace, callback_url, expires_in, user=User.current)
    raise "Must specify namespace" if namespace.blank?
    @key = [namespace,
            user.login.underscored.uniquify].join('/')

    @policy_document = {"expiration" =>  (Time.now + expires_in).utc.iso8601,
      "conditions" => [{"bucket" => MingleConfiguration.import_files_bucket_name},
                       ["starts-with", "$key", @key],
                       ["starts-with", "$authenticity_token", ""],
                       {"acl" => "private"},
                       ["starts-with", "$Content-Type", ""],
                       ["starts-with", "$success_action_redirect", callback_url]
                      ]
    }

    @policy_document["conditions"] << {"x-amz-security-token" => session_token} if session_token
  end

  def signature
    credential_provider = AWS.config.credential_provider
    Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha1'),
                                         secret_access_key(credential_provider),
                                         encrypted_policy_document)).gsub("\n","")
  end

  def encrypted_policy_document
    Base64.encode64(@policy_document.to_json).gsub("\n", "")
  end

  def access_key_id
    ENV['AWS_ACCESS_KEY_ID'] || AWS.config.credential_provider.access_key_id
  end

  def secret_access_key
    s3_temporary_creds[:secret_access_key]
  end

  def session_token
    AWS.config.credential_provider.session_token
  end

  private
  def secret_access_key(credential_provider)
    ENV['AWS_SECRET_ACCESS_KEY'] || credential_provider.secret_access_key
  end

end
