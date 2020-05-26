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

module Multitenancy
  class S3BucketManager
    def initialize(s3 = AWS::S3.new)
      @s3 = s3
      @buckets = [
        MingleConfiguration.icons_bucket_name,
        MingleConfiguration.tmp_file_bucket_name,
        MingleConfiguration.attachments_bucket_name,
        MingleConfiguration.import_files_bucket_name,
        MingleConfiguration.daily_history_cache_bucket_name
      ].reject(&:blank?)
    end

    def clear(tenant_name)
      @buckets.each {|b| clear_bucket(b, tenant_name)}
    end

    private

    def clear_bucket(bucket_name, tenant_name)
      bucket = @s3.buckets[bucket_name]
      bucket.objects.with_prefix(tenant_name + "/").delete_all if bucket && bucket.exists?
    end
  end
end
