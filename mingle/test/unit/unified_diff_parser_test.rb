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

class UnifiedParserTest < ActiveSupport::TestCase
  def test_can_parse_unified_diff_formats
    diff = <<-DIFF
--- /a.txt
+++ /a.txt
@@ -1 +1,2 @@
-some content
+content before
+same content
    DIFF
    parsed = UnifiedDiffParser.new(diff)

    assert_equal 1, parsed.chunks.size
    assert_equal 3, parsed.chunks.first.lines.size

    assert_equal 1, parsed.chunks.first.lines.first.old_lineno
    assert_equal nil, parsed.chunks.first.lines.first.new_lineno
    assert parsed.chunks.first.lines.first.removed?
    assert_equal 'some content', parsed.chunks.first.lines.first.content

    assert_equal nil, parsed.chunks.first.lines.last.old_lineno
    assert_equal 2, parsed.chunks.first.lines.last.new_lineno
    assert parsed.chunks.first.lines.last.added?
    assert_equal 'same content', parsed.chunks.first.lines.last.content
  end

  def test_can_parse_more_complex_diff_and_property_changes_will_be_ignored
    diff = <<-DIFF

Property changes on: .
___________________________________________________________________
Name: svn:ignore
   - .project

   + .project
tmp


--- /trunk/app/views/cards/list.rhtml
+++ /trunk/app/views/cards/list.rhtml
@@ -1,19 +1,17 @@
 <% @sidebar = capture do %>

 <script type="text/javascript">
-
   function showSaveViewPanel(){
- $('view-save-panel').style["display"]="";
- $('view-save-link').style["display"]="none";
+    Element.hide('view-save-link');
+    new Effect.Appear('view-save-panel');
   }
 </script>
 <% if @view.name.nil? %>
- <%= link_to_function "Save view as....",  "showSaveViewPanel()", :id => 'view-save-link' %>
+ <%= link_to_function "Save View As...",  "showSaveViewPanel()", :id => 'view-save-link' %>
 <% end %>
 <div id="view-save-panel" style="display:none">
 <h3>View Name</h3>
 <% form_tag :action => 'create_view' do -%>
-
 <%= text_field "view", "name" %>
 <%= hidden_view_tags @view %>
 <p class="actions">
DIFF

    parsed = UnifiedDiffParser.new(diff)
    assert_equal 1, parsed.chunks.size
    assert_equal 22, parsed.chunks.first.lines.size

    assert !parsed.chunks.first.lines.last.added?
    assert !parsed.chunks.first.lines.last.removed?
    assert_equal 19, parsed.chunks.first.lines.last.old_lineno
    assert_equal 17, parsed.chunks.first.lines.last.new_lineno
    assert '<p class="actions">', parsed.chunks.first.lines.last.content
  end
end
