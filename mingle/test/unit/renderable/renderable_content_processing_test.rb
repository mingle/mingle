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

class RenderableContentProcessingTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def test_should_replace_img_tag_with_mingle_inline_image_markup
    with_each_concrete_renderable do |renderable|
      attachment = Attachment.create!(:file => sample_attachment, :project => @project)
      update_renderable_content_with_processing(renderable, "<img alt='/#{@project.identifier}/attachments/#{attachment.id}' src='/#{@project.identifier}/attachments/#{attachment.id}'  class='mingle-image' />")
      assert_equal "!#{attachment.file_name}!", renderable.content
    end
  end

  def test_should_replace_img_tag_should_preserve_css_styles
    with_each_concrete_renderable do |renderable|
      attachment = Attachment.create!(:file => sample_attachment, :project => @project)
      update_renderable_content_with_processing(renderable, "<img alt='/#{@project.identifier}/attachments/#{attachment.id}' src='/#{@project.identifier}/attachments/#{attachment.id}'  class='mingle-image' style='width:100px;height:30px;' />")
      assert_equal "!#{attachment.file_name}!{width:100px;height:30px;}", renderable.content
    end
  end


  # bug 14199
  def test_when_saving_attributes_with_colons_are_preserved
    with_each_concrete_renderable do |renderable|
      content_with_colon_attribute = '<p style="color:#0000CD;">Some blue text!</p>'
      renderable.update_attributes :content => content_with_colon_attribute
      assert_equal content_with_colon_attribute.strip, renderable.content.strip
    end
  end

  def test_should_replace_multiple_img_tags_with_mingle_inline_image_markup
    with_each_concrete_renderable do |renderable|
      first_attachment = Attachment.create!(:file => sample_attachment("1.gif"), :project => @project)
      another_attachment = Attachment.create!(:file => sample_attachment("2.gif"), :project => @project)
      update_renderable_content_with_processing(renderable, "<img class=\"mingle-image\" src=\"/#{@project.identifier}/attachments/#{first_attachment.id}\"/><img class=\"mingle-image\" src='/#{@project.identifier}/attachments/#{another_attachment.id}'/>")
      assert_equal "!#{first_attachment.file_name}!!#{another_attachment.file_name}!", renderable.content
    end
  end

  def test_should_only_replace_mingle_img_tags
    with_each_concrete_renderable do |renderable|
      first_attachment = Attachment.create!(:file => sample_attachment("1.gif"), :project => @project)
      update_renderable_content_with_processing(renderable, "<img class=\"mingle-image\" src=\"/#{@project.identifier}/attachments/#{first_attachment.id}\"/><img src='www.google.com/cow.jpg' />")
      assert_equal "!#{first_attachment.file_name}!<img src=\"www.google.com/cow.jpg\" />", renderable.content
    end
  end

  def test_should_create_attachings_for_images_that_are_not_attachments_on_card
    first_attachment = Attachment.create!(:file => sample_attachment("1.gif"), :project => @project)
    card = Card.new(:name => 'new card', :project_id => @project.id, :card_type_name => @project.card_types.first.name)
    update_renderable_content_with_processing(card, "<img class=\"mingle-image\" src=\"/#{@project.identifier}/attachments/#{first_attachment.id}\"/>")
    assert_equal 1, card.reload.attachments.size
    assert_equal first_attachment.file, card.attachments.first.file
  end

  def test_should_create_attachings_for_images_that_are_not_attachments_on_page
    first_attachment = Attachment.create!(:file => sample_attachment("1.gif"), :project => @project)
    page = @project.pages.new(:name => 'unsaved page with attachment')
    update_renderable_content_with_processing(page, "<img class=\"mingle-image\" src=\"/#{@project.identifier}/attachments/#{first_attachment.id}\"/>")
    assert_equal 1, page.attachments.size
    assert_equal first_attachment.file, page.attachments.first.file
  end

  def test_should_not_create_attachings_for_images_update
    with_each_concrete_renderable do |renderable|
      first_attachment = Attachment.create!(:file => sample_attachment("1.gif"), :project => @project)
      renderable.update_attributes :content => "<img class=\"mingle-image\" src=\"/#{@project.identifier}/attachments/#{first_attachment.id}\"/>"
      assert_equal 0, renderable.attachments.size
    end
  end

  def test_should_not_substitute_card_links_to_html_markup_on_save
    with_each_concrete_renderable do |renderable|
      renderable.update_attributes(:content => "#123")
      assert_equal "#123", renderable.content
    end
  end

  def test_should_replace_html_markup_with_macro_markup_on_update
    with_each_concrete_renderable do |renderable|
      update_renderable_content_with_processing(renderable, "<div raw_text='#{URI.escape("{{ project }}")}' class='macro'>#{@project.identifier}</div>")
      assert_equal "{{ project }}", renderable.content
    end
  end

  private

  def update_renderable_content_with_processing(renderable, content)
    renderable.content = content
    renderable.editor_content_processing = true
    renderable.save!
  end

  def with_each_concrete_renderable
    yield @project.cards.create!(:name => 'card for test', :card_type_name => @project.card_types.first.name)
    yield @project.pages.create!(:name => 'pagefortest')
  end

end
