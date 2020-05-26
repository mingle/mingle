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

class S3BucketManagerTest < ActiveSupport::TestCase
  def test_it_should_delete_everything
    MingleConfiguration.with_icons_bucket_name_overridden_to("icons") do
      s3_mock = mock('s3')
      
      prefix_collection_mock = mock('prefix_collection')
      prefix_collection_mock.expects(:with_prefix).with('test/').returns(mock(:delete_all))

      object_collection_mock = mock('object_collection')
      object_collection_mock.expects(:exists?).returns(true)
      object_collection_mock.expects(:objects).returns(prefix_collection_mock)

      s3_mock.expects(:buckets).times(1).returns('icons' => object_collection_mock)
      s3 = Multitenancy::S3BucketManager.new(s3_mock)

      s3.clear('test')
    end
  end
end
