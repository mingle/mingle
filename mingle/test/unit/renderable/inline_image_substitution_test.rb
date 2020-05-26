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

class InlineImageSubstitutionTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = with_new_project do |project|
      project.add_member(User.current)
      card = project.cards.create!(:name => "first card", :card_type_name => "card")
      card.attach_files(sample_attachment('IMG_1.JPG'))
      card.save!

      page = project.pages.create!(:name => "First Page");
      page.attachings.create!(:attachment_id => project.attachments.first.id)
    end
    @project.activate
  end

  def test_should_match_attachment_markup_after_image_markup
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert s.pattern =~ "!#1/IMG_1.jpg!"
    assert s.pattern =~ "!IMG_1.jpg!"
    assert s.pattern =~ "!external.image!"
    assert !(s.pattern =~ "! external.image!")
    assert !(s.pattern =~ "!external.image !")
    assert !(s.pattern =~ "! !")
  end

  def test_should_not_throw_exception_when_matched_page_name_is_more_than_4000_chars
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    for_oracle do
      assert_nothing_raised {s.apply("!#{'a'*5000}/foo.zip!")}
    end
  end

  def test_should_not_throw_exception_when_matched_card_number_is_super_long
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    for_oracle do
      assert_nothing_raised {s.apply("!##{('9'*126)}/foo.zip!")}
    end
  end

  #bug 7079
  def test_should_match_when_content_contains_valid_normal_exclamation_as_well_as_image
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    first_attachment = find_first_attachment
    assert_equal "!http://test.host/attachments/randompath/1/IMG_1.jpg! wow!", s.apply("!http://test.host/attachments/randompath/1/IMG_1.jpg! wow!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}! wow!", s.apply("!#{first_attachment.file_name}! wow!")
    assert_equal "wow! !http://test.host/attachments/randompath/1/IMG_1.jpg!", s.apply("wow! !http://test.host/attachments/randompath/1/IMG_1.jpg!")
    assert_equal "wow! !(mingle-image)#{attachment_url(first_attachment)}!", s.apply("wow! !#{first_attachment.file_name}!")
    assert_equal "!wow !(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!wow !#{first_attachment.file_name}!")
  end

  def test_should_match_image_markup_with_project_identifier_and_card_number
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert s.pattern =~ "!#{@project.identifier}/#1/IMG_1.jpg!"
    assert_include_project_identifier @project.identifier, s.pattern.match("!#{@project.identifier}/#1/IMG_1.jpg!")
  end

  def test_should_produce_markup_to_attach_image_inline
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    first_attachment = find_first_attachment
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#1/#{first_attachment.file_name}!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{first_attachment.file_name}!")
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(4), :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#1/#{first_attachment.file_name}!")

    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#1/#{first_attachment.file_name}!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{first_attachment.file_name}!")
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('Second Page'), :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#1/#{first_attachment.file_name}!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#1/#{first_attachment.file_name}!")

    assert_equal "!external.image!", s.apply("!external.image!")
  end

  def test_should_produce_markup_to_attach_cross_project_image_inline
    s = Renderable::InlineImageSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    first_attachment = find_first_attachment
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{@project.identifier}/#1/#{first_attachment.file_name}!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{@project.identifier}/First Page/#{first_attachment.file_name}!")
  end

  #bug #8066 project identifier is case sensitive in cross project linking
  def test_should_ignore_case_when_link_to_image_in_cross_project
    s = Renderable::InlineImageSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    first_attachment = find_first_attachment
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{@project.identifier}/#1/#{first_attachment.file_name}!")
  end

  def test_should_recognize_identifier_before_slash_as_wiki_page_name
    login_as_admin
    another_project = three_level_tree_project
    page_named_as_first_project = another_project.pages.create(:name => @project.identifier, :content => 'some thing about attachment')
    img = sample_attachment("IMG_for_#{@project.identifier}.jpg")
    attachment = Attachment.create!(:file => img, :project => another_project)
    Attaching.create!(:attachment_id => attachment.id, :attachable_id => page_named_as_first_project.id, :attachable_type => 'Page')
    page_named_as_first_project.reload
    s = Renderable::InlineImageSubstitution.new(:project => another_project, :content_provider => page_named_as_first_project, :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(attachment)}!", s.apply("!#{@project.identifier}/IMG_for_#{@project.identifier}.jpg!")
  end

  # for bug 1003
  def test_should_produce_markup_to_attach_image_through_page_name
    page = @project.pages.create(:name => 'page name', :content => 'some thing about attachment')
    page.attach_files(sample_attachment('1.gif'))
    attachment = page.attachments[0]
    page.save!
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(attachment)}!", s.apply("!page name/1.gif!")
  end

  # Bug 4774.
  def test_should_be_case_insensitive
    first_attachment = find_first_attachment
    attachment_id = first_attachment.id
    attachment_name_swapped = first_attachment.attributes['file'].swapcase
    assert(attachment_name_swapped != first_attachment.attributes['file'], "Attachment name must contain characters from the alphabet to be valid.")

    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{attachment_name_swapped}!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{attachment_name_swapped}!")

    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#1/#{attachment_name_swapped}!")
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply("!#{attachment_name_swapped}!")
  end

  def test_should_not_break_inline_image_which_has_a_corss_project_image_sibling
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name("First Page"), :view_helper => view_helper)
    first_attachment = find_first_attachment
    expected_result = "!(mingle-image)#{attachment_url(first_attachment)}! !(mingle-image)#{attachment_url(first_attachment)}!"
    assert_equal expected_result, s.apply("!#{first_attachment.file_name}! !#{@project.identifier}/First Page/#{first_attachment.file_name}!")
  end

  def test_should_not_cache_content_which_has_cross_project_inline_image
    login_as_member
    content_provider = create_card!(:name => 'new card')

    substitution = Renderable::InlineImageSubstitution.new(:project => three_level_tree_project, :content_provider => content_provider, :view_helper => view_helper)
    substitution.apply("!#{@project.identifier}/First page/IMG_1.jpg!")
    assert_equal 1, content_provider.rendered_projects.size
    assert_equal @project, content_provider.rendered_projects.first
    assert_equal false, content_provider.can_be_cached?
  end

  # bug 7231
  def test_inline_image_using_card_slash_attachment_should_not_break_other_inline_images
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    first_attachment = find_first_attachment

    content = "!#1/#{first_attachment.file_name}! and !#{first_attachment.file_name}!"
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}! and !(mingle-image)#{attachment_url(first_attachment)}!", s.apply(content)

    content = "!#{first_attachment.file_name}! and !#1/#{first_attachment.file_name}!"
    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}! and !(mingle-image)#{attachment_url(first_attachment)}!", s.apply(content)
  end

  def test_inline_image_substitution_adds_a_mingle_image_class
    s = Renderable::InlineImageSubstitution.new(:project => @project, :content_provider => @project.cards.find_by_number(1), :view_helper => view_helper)
    first_attachment = find_first_attachment

    content = "!#{first_attachment.file_name}!"

    assert_equal "!(mingle-image)#{attachment_url(first_attachment)}!", s.apply(content)
  end

  private

  def find_first_attachment
    @project.cards.first.attachments.first
  end

  def assert_include_project_identifier(project_identifier, match)
    assert_equal project_identifier, match.captures[2]
  end
end
