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

class CrossProjectCardSubstitutionTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit

  def setup
    @project = first_project
    @project.activate
    @substitution = Renderable::CrossProjectCardSubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
  end

  def test_should_match_content_with_project_identifer
    assert 'project/#1' =~ @substitution.pattern
    assert 'project/card 1' =~ @substitution.pattern
    assert 'project /#1' =~ @substitution.pattern
    assert 'project/ #1' =~ @substitution.pattern
    assert 'project / #1' =~ @substitution.pattern
    assert 'project / !1' !~ @substitution.pattern
    assert '/ !1' !~ @substitution.pattern
    assert '?/ !1' !~ @substitution.pattern
    assert '!project/ !1' !~ @substitution.pattern
  end

  def test_should_not_substitute_card_link_which_is_inside_of_link
    assert_equal "<a href=\"/projects/first_project/cards/1\">first_project/#1</a>", @substitution.apply("<a href=\"/projects/first_project/cards/1\">first_project/#1</a>")
  end

  # bug 8467
  def test_should_not_substitute_parts_of_a_standard_link
    # detail/sf02 looks like a cross project link and was being escaped
    assert_equal "http://10.2.12.30:8153/cruise/tab/build/detail/sf02/97/build/1/rails", @substitution.apply("http://10.2.12.30:8153/cruise/tab/build/detail/sf02/97/build/1/rails")
  end

  def test_should_not_substitute_card_link_which_is_wrapped_by_html_tag
    assert_equal "<span customeproperty=\"first_project/#1\">abc</span>", @substitution.apply("<span customeproperty=\"first_project/#1\">abc</span>")
  end

  def test_escaping
    assert_equal "<escape>first_project/#1</escape>", @substitution.apply("<escape>first_project/#1</escape>")
  end

  def test_should_substitute_card_link
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_PROJECT/#1</a>', @substitution.apply('first_PROJECT/#1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/#1</a>', @substitution.apply('first_project/#1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/# 1</a>', @substitution.apply('first_project/# 1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project / # 1</a>', @substitution.apply('first_project / # 1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project / card 1</a>', @substitution.apply('first_project / card 1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/card 1</a>', @substitution.apply('first_project/card 1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/card1</a>', @substitution.apply('first_project/card1')
  end

  def test_bug8066_could_not_render_cross_project_link_when_project_identifier_contains_number
    login_as_admin
    with_new_project do |project|
      project.identifier = "#{project.identifier}abc123"
      project.save!
      card = create_card!(:name => "card 1", :description => "#{project.identifier.upcase}/#1")
      formatted_content = card.formatted_content(self)
      assert_match(/projects\/#{project.identifier}\/cards\/1/, formatted_content)
      assert_match(/#{project.identifier.upcase}\/#1/, formatted_content)
    end
  end

  def test_should_substitute_card_link_ignore_case
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/CARD 1</a>', @substitution.apply('first_project/CARD 1')
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">FiRst_PROJECT/#1</a>', @substitution.apply('FiRst_PROJECT/#1')  # bug 8066
  end

  def test_should_substitute_card_link_with_suffix
    assert_equal '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/#1</a>' + '.', @substitution.apply('first_project/#1.')
    assert_equal '!' + '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/#1</a>' + '/', @substitution.apply('!first_project/#1/')
  end

  def test_should_not_substitute_card_link_with_nonexistent_project_identifier
    assert_equal 'another / #1', @substitution.apply('another / #1')
  end

  def test_should_not_substitute_card_link_with_nonexistent_keywords_in_project
    assert_equal 'first_project/bla 1', @substitution.apply('first_project/bla 1')
  end

  def test_should_not_cache_content_which_has_cross_project_link
    login_as_member
    content_provider = create_card!(:name => 'new card')

    substitution = Renderable::CrossProjectCardSubstitution.new(:project => three_level_tree_project, :content_provider => content_provider, :view_helper => view_helper)
    substitution.apply('first_project/# 1')
    assert_equal 1, content_provider.rendered_projects.size
    assert_equal first_project, content_provider.rendered_projects.first
    assert_equal false, content_provider.can_be_cached?
  end

  def test_inline_image_substitution_should_not_affect_cross_project_card_link
    content = "!http://test.host/attachments/randompath/img1!\r\n\r\nfirst_project/# 1"
    assert_include '<a href="/projects/first_project/cards/1" class="card-link-1">first_project/# 1</a>', @substitution.apply(content)
  end
end
