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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class ImageAttachmentProcessorTest < ActiveSupport::TestCase

  #bug [mingle1/#15293]
  def test_should_ignore_stack_level_too_deep_error_raised_from_find_mingle_image_tags
    wysiwyg_img = %[<p><p><p><p><div></p></><img class="mingle-image" src="1" /></p>]
    processor = ImageAttachmentProcessor.new(wysiwyg_img)
    def processor.find_mingle_image_tags(doc)
      raise SystemStackError
    end
    assert processor.process
  end

  def test_should_ignore_img_tag_that_is_missing_src_attr
    wysiwyg_img = %[<p><p><p><p><div></p></><img class="mingle-image" /></p>]
    processor = ImageAttachmentProcessor.new(wysiwyg_img)
    assert processor.process
  end

  def test_should_ignore_img_tag_that_src_attr_value_is_not_number
    wysiwyg_img = %[<p><p><p><p><div></p></><img class="mingle-image" src='/'/></p>]
    processor = ImageAttachmentProcessor.new(wysiwyg_img)
    assert processor.process
  end
end
