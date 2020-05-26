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

class WYSIWYGInlineImageSubstitutionTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    login_as_member

    @card = create_card!(:name => 'wysiwyg card')
    @card.attach_files(sample_attachment('1.gif'))
  end

  def test_wysiwyg_image_is_rendered
    s = Renderable::WYSIWYGInlineImageSubstitution.new(:project => @project, :content_provider => @card, :view_helper => view_helper)
    formatted_content = s.apply(%Q{!1.gif!})
    assert_match /<img.*?class=\"mingle-image\".*/, formatted_content
    assert_match /<img.*?alt=\"!1.gif!\".*/, formatted_content
    assert_match /<img.*?src=\"http:\/\/test.host\/projects\/#{@project.identifier}\/attachments\/#{@card.attachments.first.id}\".*/, formatted_content
  end

  def test_expand_attachment_image_with_css_styles
    s = Renderable::WYSIWYGInlineImageSubstitution.new(:project => @project, :content_provider => @card, :view_helper => view_helper)
    formatted_content = s.apply(%Q{!1.gif!{width:120px;height:100px}})
    assert_equal_ignoring_spaces_and_return %Q{<img class="mingle-image" alt="!1.gif!{width:120px;height:100px}" src="http://test.host/projects/#{@project.identifier}/attachments/#{@card.attachments.first.id}" style="width:120px;height:100px"/>}, formatted_content
  end


  def test_should_render_nonexistent_attach_as_broken_img_link
    s = Renderable::WYSIWYGInlineImageSubstitution.new(:project => @project, :content_provider => @card, :view_helper => view_helper)
    assert s.apply("!not_here.png!") =~ /img/
  end


end
