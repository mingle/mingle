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

require File.expand_path("../../unit_test_helper", File.dirname(__FILE__))
require File.expand_path("../renderable_test_helper", File.dirname(__FILE__))

class InlineMarkupProcessorTest < ActiveSupport::TestCase
  include ::RenderableTestHelper

  def test_should_protect_macro_content_from_escaping
    processor = InlineMarkupProcessor.new(%Q{
      <p>{{We should escape &, <, and > here!}}</p>
      #{create_raw_macro_markup("{{table query: select number where name = \"But not here & > <!\"}}")}
    })

    # compare resulting strings, don't parse to a dom because this defeats the purpose of this test
    expected = %Q{
      <p>&#123;&#123;We should escape &amp;, &lt;, and &gt; here&#33;&#125;&#125;</p>
      {{table query: select number where name = "But not here & > <!"}}
    }
    assert_equal_ignoring_spaces expected, processor.process
  end

end
