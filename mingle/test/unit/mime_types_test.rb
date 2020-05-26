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

class MimeTypesTest < ActiveSupport::TestCase
  def test_custom_mime_types_are_loaded
    assert_equal "application/x-word", Rack::Mime::MIME_TYPES[".docx"]
    assert_equal "application/x-excel", Rack::Mime::MIME_TYPES[".xlsx"]
    assert_equal "application/vnd.openxmlformats-officedocument.presentationml.presentation", Rack::Mime::MIME_TYPES[".pptx"]
    assert_equal "application/vnd.ms-outlook", Rack::Mime::MIME_TYPES[".msg"]
    assert_equal "text/plain", Rack::Mime::MIME_TYPES[".eml"]
  end
end
