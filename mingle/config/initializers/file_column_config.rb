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

if MingleConfiguration.use_s3_attachments_storage?
  Rails.logger.info("use s3 attachment storage")
  FileColumn.config_store(:s3,
                          :namespace => proc { MingleConfiguration.app_namespace },
                          :bucket_name => MingleConfiguration.file_column_bucket_name)

  Storage::S3Store::CONTENT_TYPES.tap do |types|
    types['mingle'] = "application/octet-stream"
    types['program'] = "application/octet-stream"
    types['dependencies'] = "application/octet-stream"
  end
else
  Rails.logger.info("use filesystem attachment storage")
end
