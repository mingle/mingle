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

class LightBoxTest < ActiveSupport::TestCase

  def test_should_add_id_to_lightbox_body
    lightbox = Lightbox.with_close_link_and_close_button(self, "Cancel", "", :class => "remove-button popup-close")
    body = lightbox.body "macro_editor_lightbox" do
      "body"
    end

    assert_match /id="macro_editor_lightbox"/, body
  end

  def test_should_id_for_lightbox_body_is_optional
    lightbox = Lightbox.with_close_link_and_close_button(self, "Cancel", "", :class => "remove-button popup-close")
    body = lightbox.body do
      "body"
    end

    assert_no_match(/id=/, body)
  end

  def capture
  end

  def on_options_authorized(ignore_this_arg, &block)
    yield if block_given?
  end

  def concat(input)
    input
  end

end
