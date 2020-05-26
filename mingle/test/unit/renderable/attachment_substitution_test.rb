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

class AttachmentSubstitutionTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = with_new_project do |project|
      project.add_member(User.current)
      card = project.cards.create!(:name => "first card", :card_type_name => "card")
      card.attach_files(sample_attachment('IMG_1.JPG'))
      card.save!

      page1 = project.pages.create!(:name => "First Page");
      page1.attachings.create!(:attachment_id => project.attachments.first.id)

      page2 = project.pages.create!(:name => "Second Page");
      page2.attachings.create!(:attachment_id => project.attachments.first.id)

      page3 = project.pages.create!(:name => "page one");
      page3.attachings.create!(:attachment_id => project.attachments.first.id)
    end
    @project.activate
  end

  def test_should_match_forward_slash_separated_resource_as_attachment
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_match s.pattern, '[[#1/IMG_1.jpg]]'
    assert_match s.pattern, '[[#1/IMG_1.jpg]]'
    assert_match s.pattern, '[[1/IMG_1.jpg]]'
    assert_match s.pattern, '[[page one/IMG_1.jpg]]'
    assert_match s.pattern, '[[IMG_1.jpg]]'
    assert_match s.pattern, '[[named link|#1/IMG_1.jpg]]'
    assert_match s.pattern, '[[more named links|IMG_1.jpg]]'
    assert_match s.pattern, '[[named link|1/IMG_1.jpg]]'
    assert_match s.pattern, '[[more named links|page one/IMG_1.jpg]]'
  end

  def test_should_not_throw_exception_when_matched_page_name_is_more_than_4000_chars
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    for_oracle do
      assert_nothing_raised {s.apply("[[#{'a'*5000}/foo.zip]]")}
    end
  end

  def test_should_not_throw_exception_when_matched_card_number_is_super_long
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    for_oracle do
      assert_nothing_raised {s.apply("[[##{('9'*126)}/foo.zip]]")}
    end
  end

  def test_should_match_forward_slash_separated_resource_with_project_identifier_as_attachment
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[#{@project.identifier}/#1/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[#{@project.identifier}/1/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[#{@project.identifier}/page one/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[#{@project.identifier}/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[named link|#{@project.identifier}/#1/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[more named links|#{@project.identifier}/1/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[named link|#{@project.identifier}/page one/IMG_1.jpg]]")
    assert_include_project_identifier "#{@project.identifier}", s.pattern.match("[[more named links|#{@project.identifier}/IMG_1.jpg]]")
  end

  # Bug 7125
  def test_attachment_hyperlinks_in_email_must_have_href_as_full_path
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_equal true, s.apply("[[#{@project.identifier}/IMG_1.jpg]]").include?(%Q{href="http://test.host/})
  end

  def test_should_not_match_if_preceded_by_image_markup
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_no_match s.pattern, '!#1/IMG_1.jpg!'
    assert_no_match s.pattern, '!#{@project.identifier}/#1/IMG_1.jpg!'
  end

  def test_render_non_substituted_content_without_substitutions
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_equal "nothing here", s.apply("nothing here")
  end

  # Bug 4774.
  def test_should_be_case_insensitive
    first_attachment = resolve_first_attachment
    attachment_id = first_attachment.id
    card = @project.cards.find_by_number(1)
    assert_false card.redcloth

    attachment_name_swapped = first_attachment.attributes['file'].swapcase
    assert(attachment_name_swapped != first_attachment.attributes['file'], "Attachment name must contain characters from the alphabet to be valid.")

    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => card, :view_helper => view_helper)
    assert s.pattern =~ "[[#{attachment_name_swapped}]]"
    attachment_path = "http://test.host/projects/#{@project.identifier}/attachments/#{attachment_id}"
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#1/#{attachment_name_swapped}</a>}, s.apply("[[#1/#{attachment_name_swapped}]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{attachment_name_swapped}</a>}, s.apply("[[#{attachment_name_swapped}]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply("[[name|#1/#{attachment_name_swapped}]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">nom</a>}, s.apply("[[nom|#{attachment_name_swapped}]]")

    page = @project.pages.find_by_name('First Page')
    assert_false page.redcloth
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => page, :view_helper => view_helper)
    assert s.pattern =~ "[[#{attachment_name_swapped}]]"
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/First Page/#{attachment_name_swapped}</a>}, s.apply("[[#{@project.identifier}/First Page/#{attachment_name_swapped}]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/#{attachment_name_swapped}</a>}, s.apply("[[#{@project.identifier}/#{attachment_name_swapped}]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply("[[name|#{@project.identifier}/First Page/#{attachment_name_swapped}]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">nom</a>}, s.apply("[[nom|#{@project.identifier}/#{attachment_name_swapped}]]")
  end

  def test_should_produce_url_to_named_attachment
    first_attachment = resolve_first_attachment
    img_1_id = first_attachment.id

    card = @project.cards.find_by_number(1)
    assert_false card.redcloth

    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => card, :view_helper => view_helper)

    attachment_path = "http://test.host/projects/#{@project.identifier}/attachments/#{img_1_id}"
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#1/IMG_1.jpg</a>}, s.apply('[[#1/IMG_1.jpg]]')
    assert_equal %Q{<a href="#{attachment_path}" target="blank">IMG_1.jpg</a>}, s.apply('[[IMG_1.jpg]]')
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply('[[name|#1/IMG_1.jpg]]')
    assert_equal %Q{<a href="#{attachment_path}" target="blank">nom</a>}, s.apply('[[nom|IMG_1.jpg]]')

    first_page = @project.pages.find_by_name('First Page')
    assert_false first_page.redcloth
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => first_page, :view_helper => view_helper)
    assert_equal %Q{<a href="#{attachment_path}" target="blank">First Page/IMG_1.jpg</a>}, s.apply('[[First Page/IMG_1.jpg]]')
    assert_equal %Q{<a href="#{attachment_path}" target="blank">IMG_1.jpg</a>}, s.apply('[[IMG_1.jpg]]')
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply('[[name|First Page/IMG_1.jpg]]')
    assert_equal %Q{<a href="#{attachment_path}" target="blank">nom</a>}, s.apply('[[nom|IMG_1.jpg]]')

    second_page = @project.pages.find_by_name('Second Page')
    assert_false second_page.redcloth
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => second_page, :view_helper => view_helper)
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply("[[name|#{@project.identifier}/First Page/IMG_1.jpg]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">nom</a>}, s.apply( "[[nom|#{@project.identifier}/First Page/IMG_1.jpg]]")
  end

  def test_should_not_match_project_identifier_partly
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_equal "[[not_#{@project.identifier}/First Page/IMG_1.jpg]]", s.apply( "[[not_#{@project.identifier}/First Page/IMG_1.jpg]]")
  end

  def test_should_recognize_identifier_before_slash_as_wiki_page_name
    login_as_admin
    another_project = three_level_tree_project
    page_named_as_first_project = another_project.pages.create(:name => @project.identifier, :content => 'some thing about attachment')
    img = sample_attachment("IMG_for_#{@project.identifier}.jpg")
    attachment = Attachment.create!(:file => img, :project => @project)
    Attaching.create!(:attachment_id => attachment.id, :attachable_id => page_named_as_first_project.id, :attachable_type => 'Page')
    page_named_as_first_project.reload
    s = Renderable::AttachmentLinkSubstitution.new(:project => another_project, :content_provider => page_named_as_first_project, :view_helper => view_helper)

    attachment_path = "http://test.host/projects/#{@project.identifier}/attachments/#{attachment.id}"
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/IMG_for_#{@project.identifier}.jpg</a>}, s.apply("[[#{@project.identifier}/IMG_for_#{@project.identifier}.jpg]]")
  end

  def test_should_not_replace_content_when_project_identifier_follow_by_slash_wiki_page_name
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert @project.pages.find_by_name('First Page')
    assert_equal "[[#{@project.identifier}/First Page]]", s.apply("[[#{@project.identifier}/First Page]]")
  end

  def test_should_produce_url_to_named_attachment_with_identifier
    img_1_id = resolve_first_attachment.id
    card = @project.cards.find_by_number(1)
    assert_false card.redcloth

    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => card, :view_helper => view_helper)

    attachment_path = "http://test.host/projects/#{@project.identifier}/attachments/#{img_1_id}"

    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/#1/IMG_1.jpg</a>}, s.apply("[[#{@project.identifier}/#1/IMG_1.jpg]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply("[[name|#{@project.identifier}/#1/IMG_1.jpg]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/First Page/IMG_1.jpg</a>}, s.apply("[[#{@project.identifier}/First Page/IMG_1.jpg]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">name</a>}, s.apply("[[name|#{@project.identifier}/First Page/IMG_1.jpg]]")
  end

  def test_should_find_page_by_identifier_ignoring_case
    s = Renderable::AttachmentLinkSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    img_1_id = resolve_first_attachment.id

    attachment_path = "http://test.host/projects/#{@project.identifier}/attachments/#{img_1_id}"

    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/First page/IMG_1.jpg</a>}, s.apply("[[#{@project.identifier}/First page/IMG_1.jpg]]")
    assert_equal %Q{<a href="#{attachment_path}" target="blank">#{@project.identifier}/first_page/IMG_1.jpg</a>}, s.apply("[[#{@project.identifier}/first_page/IMG_1.jpg]]")
  end

  def test_should_not_cache_content_which_has_cross_project_attachement_link
    login_as_member
    content_provider = create_card!(:name => 'new card')

    substitution = Renderable::AttachmentLinkSubstitution.new(:project => three_level_tree_project, :content_provider => content_provider, :view_helper => view_helper)
    substitution.apply("[[#{@project.identifier}/First page/IMG_1.jpg]]")
    assert_equal 1, content_provider.rendered_projects.size
    assert_equal @project, content_provider.rendered_projects.first
    assert_equal false, content_provider.can_be_cached?
  end

  #bug #8066 project identifier is case sensitive in cross project linking
  def test_should_ignore_case_when_link_to_attachment_in_cross_project
    login_as_member
    content_provider = create_card!(:name => 'new card')

    substitution = Renderable::AttachmentLinkSubstitution.new(:project => three_level_tree_project, :content_provider => content_provider, :view_helper => view_helper)
    substitution.apply("[[#{@project.identifier}/First page/IMG_1.jpg]]")
    assert_equal 1, content_provider.rendered_projects.size
    assert_equal @project, content_provider.rendered_projects.first
  end

  private

  def resolve_first_attachment
    @project.attachments.first
  end

  def assert_include_project_identifier(project_identifier, match)
    assert_equal project_identifier, match.captures[4]
  end
end
