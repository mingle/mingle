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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class CardRenderingTest < ActiveSupport::TestCase
  include RenderableTestHelper

  def setup
    login_as_member
    @project = with_new_project do |project|
      project.add_member(User.current)
      setup_managed_text_definition("status", %w[new open done])
      card = project.cards.create!(:name => "first card", :card_type_name => "card")
      card.attach_files(sample_attachment('IMG_1.JPG'))
      card.save!

      page1 = project.pages.create!(:name => "First Page");
      page1.attachings.create!(:attachment_id => project.attachments.first.id)
    end
    @project.activate
  end

  def test_wysiwyg_card_should_not_have_its_tags_removed_during_formatting
    card = @project.cards.create!(:name => 'fancy new card', :card_type_name => 'Card')
    description_content = %{<p></p><p>
      </p><h1>Heading</h1>
      <p>Paragraph</p>
      <p><b>Bold</b></p>
      <p><u>Underline</u></p>
      <p><i>Italics</i></p>
      <p><strike>Strike</strike></p>
      <p><s>Strike</s></p>
      <p></p>}
    card.update_attributes(:description => description_content)
    assert_equal description_content, card.formatted_content(view_helper)
  end

  def test_removing_attachment_used_in_img_tag_strips_image_tag
    card = @project.cards.create!(:name => 'fancy new card', :card_type_name => 'Card')
    card.description = '!rowdy_rao.png!'
    card.attach_files(sample_attachment('rowdy_rao.png'))
    card.save!
    assert card.formatted_content(view_helper) =~ /<img.*alt="!rowdy_rao.png!"/
    assert card.attachments.first.destroy
    assert card.reload.formatted_content(view_helper) =~ /<img/
  end


  def test_wysiwyg_card_should_have_script_tags_removed_during_formatting
    card = @project.cards.create!(:name => 'fancy new card', :card_type_name => 'Card')
    description_content = "This is it <script>whatever</script>"
    card.update_attributes(:description => description_content)
    assert_equal 'This is it', card.formatted_content(view_helper).strip
  end

  def test_the_wysiwyg_editor_should_substitute_card_links_during_render
    card = @project.cards.create!(:name => 'the card', :card_type_name => 'Card')
    description_content = "#123"
    card.update_attributes(:description => description_content)
    rendered_content = card.formatted_content(view_helper)
    links = Nokogiri::HTML::DocumentFragment.parse(rendered_content).css("a")
    assert_equal 1, links.size
    assert_equal "/projects/#{@project.identifier}/cards/123", links.first['href']
  end

  def test_wysiwyg_card_should_substitute_page_links_on_render
    card = @project.cards.create!(:name => 'the card', :card_type_name => 'Card', :description => '[[First Page]]')
    rendered_content = card.formatted_content(view_helper)
    links = Nokogiri::HTML::DocumentFragment.parse(rendered_content).css("a")
    assert_equal 1, links.size
    assert_equal "/projects/#{@project.identifier}/wiki/First_Page", links.first['href']
  end

  def test_linking_to_cross_project_cards
    other_project = card_selection_project
    card = @project.cards.create!(:name => 'the card', :card_type_name => 'Card', :description => "#{other_project.identifier}/#1")
    rendered_content = card.formatted_content(view_helper)
    links = Nokogiri::HTML::DocumentFragment.parse(rendered_content).css("a")
    assert_equal 1, links.size
    assert_equal "/projects/#{other_project.identifier}/cards/1", links.first['href']
  end

  def test_linking_to_attachments_on_cards
    card = @project.cards.create!(:name => 'the card', :card_type_name => 'Card', :description => "[[#1/IMG_1.JPG]]")
    rendered_content = card.formatted_content(view_helper)
    links = Nokogiri::HTML::DocumentFragment.parse(rendered_content).css("a")
    assert_equal 1, links.size
    img_1 = @project.attachments.first
    assert links.first['href'].include?("/projects/#{@project.identifier}/attachments/#{img_1.id}")
  end

  def test_script_tag_from_macro_is_not_stripped_out
    with_safe_macro('dummy-script', DummyScriptTagMacro) do
      macro_definition = "{{ dummy-script url: http://foobar.com/api }}"
      card = @project.cards.create!(:name => 'the card', :card_type_name => 'Card', :description => macro_definition)
      rendered_content = card.formatted_content(view_helper)
      script_tags = Nokogiri::HTML::DocumentFragment.parse(rendered_content).css("script")
      assert_equal 1, script_tags.size
    end
  end

  def test_greater_than_inside_mql_is_not_stripped
    macro_definition = <<-CONTENT
    <p>{{
      value query: select count(*) WHERE status <= open
     }}<br />\r
     &nbsp;</p>\r
CONTENT
    card = @project.cards.create!(:name => 'the card', :card_type_name => 'Card', :description => macro_definition)
    rendered_content = card.formatted_content(view_helper)
    assert rendered_content !~ /query/
  end

  def test_wiki_page_link_should_not_be_surrounded_by_notextile
    card = @project.cards.create!(:name => 'le card', :card_type_name => 'Card', :description => '[[YesTextile]]')
    rendered_content = card.formatted_content(view_helper)
    assert rendered_content !~ /notextile/
  end

  def test_card_having_deleted_attachment_in_description_should_retain_image_name
    card = @project.cards.create! :name => 'das card', :card_type_name => 'Card'
    card.description = "<p><img alt=\"!800px-CowParade_Prague_2004_192_VESELA_KRAVA.jpg!\" class=\"mingle-image\" src=\"http://localhost/projects/fun/attachments/nonexistent\" /></p>\r\n"
    assert_nothing_raised do
      card.save!
    end
    assert "!800px-CowParade_Prague_2004_192_VESELA_KRAVA.jpg!", card.reload.description
  end

  def test_mingle_card_links_are_ignored_inside_pre_and_code_blocks
    card = @project.cards.create!:name => 'card link-a-roo', :card_type_name => 'Card'
    template = "<TAG>#1</TAG>"
    ['pre', 'code'].each do |tag|
      card.description = template.gsub('TAG', tag)
      assert_equal "<#{tag}>#1</#{tag}>", card.formatted_content(view_helper)
    end
  end

  def test_wiki_links_are_ignored_inside_pre_and_code_blocks
    template = "<TAG>[[FishFishFishBitesMcBitesFishayFishay]]</TAG>"
    card = @project.cards.create!:name => 'wizzle dizzle WSDL', :card_type_name => 'Card'
    ['pre', 'code'].each do |tag|
      card.description = template.gsub('TAG', tag)
      assert_equal "<TAG>[[FishFishFishBitesMcBitesFishayFishay]]</TAG>".gsub('TAG', tag), card.formatted_content(view_helper)
    end
  end

  def test_macros_inside_code_or_pre_blocks_are_ignored
    template = "{{ project }} <TAG>{{ project }}</TAG>"
    card = @project.cards.create!:name => 'wizzle dizzle WSDL', :card_type_name => 'Card'
    ['pre', 'code'].each do |tag|
      card.description = template.gsub('TAG', tag)
      assert_equal "#{@project.identifier} <#{tag}>{{ project }}</#{tag}>", card.formatted_content(view_helper)
    end
  end

  def test_bang_bang_image_markup_is_ignored_inside_pre_and_code_blocks
    card = @project.cards.create! :name => 'wizzle dizzle WSDL', :card_type_name => 'Card'
    content_template = <<-HTML
    <h1>Use this SOAP Enterprise Web Service XYZ:</h1>
    <TAG>
      &lt;xml&gt;
        &lt;!-- This is a comment --&gt;
        &lt;domain&gt;
          &lt;entity&gt;Hello&#33;&lt;/entity&gt;
        &lt;/domain&gt;
        &lt;!-- This is a comment --&gt;
      &lt;/xml&gt;
    </TAG>
    <p>Seriously, just use the code</p>
HTML
    expected_template = <<-HTML
    <h1>Use this SOAP Enterprise Web Service XYZ:</h1>
    <TAG>
      &lt;xml&gt;
        &lt;!-- This is a comment --&gt;
        &lt;domain&gt;
          &lt;entity&gt;Hello!&lt;/entity&gt;
        &lt;/domain&gt;
        &lt;!-- This is a comment --&gt;
      &lt;/xml&gt;
    </TAG>
    <p>Seriously, just use the code</p>
HTML
    ['pre', 'code'].each do |tag|
      card.description = content_template.gsub('TAG', tag)
      assert_equal expected_template.gsub('TAG', tag).strip, card.formatted_content(view_helper).strip
    end
  end

end
