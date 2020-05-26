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

module AWSHelper
  def s3_presigned_post(bucket_name, options={})
    key_prefix = options.delete(:key_prefix) || default_key_prefix
    bucket = AWS::S3.new.buckets[bucket_name]

    defaults = {
      :expires => (Time.now + 2.day).utc,
      :success_action_status => 201,
      :ignore => ["content-type", "authenticity_token"]
    }

    options = defaults.merge(options).reject { |k,v| v.nil? }
    bucket.presigned_post(options).where(:key).starts_with(key_prefix)
  end

  def default_key_prefix
    key = "temp-upload"
    MingleConfiguration.app_namespace ? [MingleConfiguration.app_namespace, key].join("/") : key
  end

  def random_s3_key
    [default_key_prefix, "files".uniquify].join('/')
  end

  def access_key_id
    AWS.config.credential_provider.access_key_id
  end

  def secret_access_key
    AWS.config.credential_provider.secret_access_key
  end

  def session_token
    AWS.config.credential_provider.session_token
  end

  def s3_multipart_upload_credentials
    if MingleConfiguration.s3_upload_access_key_id
      {:access_key_id => MingleConfiguration.s3_upload_access_key_id,
       :secret_access_key => MingleConfiguration.s3_upload_secret_key}
    else
      {:access_key_id => access_key_id,
       :secret_access_key => secret_access_key,
       :session_token => session_token}
    end
  end

  def s3_upload_file(bucket_name, key, path_to_file)
    bucket = AWS::S3.new.buckets[bucket_name]
    bucket.objects[key].write(:file => path_to_file)
  end
end
