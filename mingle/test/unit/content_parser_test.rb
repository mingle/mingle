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

require File.expand_path("../test_helper", File.dirname(__FILE__))

class ContentParserTest < ActiveSupport::TestCase

  def test_retains_specified_entities_in_text_nodes
    entity_map = {
      "{" => "#123",
      "}" => "#125",
      "!" => "#33"
    }

    test_content = %Q{
      should work outside of tags {{ table query: foo }}
      <p> and {{ in tags too }}</p>
      <span class="macro" raw_text="{{ but should leave attributes alone }}">!image!</span>
    }

    escaped_content = %Q{
      should work outside of tags &#123;&#123; table query: foo &#125;&#125;
      <p> and &#123;&#123; in tags too &#125;&#125;</p>
      <span class="macro" raw_text="{{ but should leave attributes alone }}">&#33;image&#33;</span>
    }

    assert_equal test_content.normalize_whitespace, ContentParser.parse_with_entity_conversion(test_content).to_xhtml.normalize_whitespace, "should behave like native parse when no entities specified"
    assert_equal escaped_content.normalize_whitespace, ContentParser.parse_with_entity_conversion(test_content, entity_map).to_xhtml.normalize_whitespace, "should escape all specified entities in text nodes, but not in attributes"
  end


  def test_does_not_blow_up_when_replacing_with_single_entity_reference
    entity_map = {
      "{" => "#123",
      "}" => "#125",
      "!" => "#33"
    }

    test_content = %Q[
      <span>
        Ensure there is a single text node that will be replaced with
        EXACTLY 1 entity reference
      </span>

      <p>{</p>
    ]

    escaped_content = %Q[
      <span>
        Ensure there is a single text node that will be replaced with
        EXACTLY 1 entity reference
      </span>

      <p>&#123;</p>
    ]

    assert_nothing_raised do
      assert_equal escaped_content.normalize_whitespace, ContentParser.parse_with_entity_conversion(test_content, entity_map).to_xhtml.normalize_whitespace
    end
  end

end
