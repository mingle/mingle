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

aws_config = File.join(File.dirname(__FILE__), '..', 'aws.yml')
if File.exists?(aws_config)
  Rails.logger.info("loading AWS SDK config: #{aws_config}")
  AWS::Rails.setup
  if MingleConfiguration.disable_aws_logging?
    Rails.logger.info("disable aws logging")
    AWS.config(:logger => nil)
  end

  # see https://github.com/aws/aws-sdk-ruby/issues/244
  # more retries for avoiding EOFError
  AWS.config(:max_retries => 15)
  require 'aws/sqs'
  require 'aws/sqs/queue'
  require 'aws/sqs/queue_collection'
  require 'aws/dynamo_db'
  require 'aws/s3'

  # eager load aws classes so that we don't have multithreading issue
  AWS.eager_autoload!
end
AWS::Rails.setup if Rails.env.development?
