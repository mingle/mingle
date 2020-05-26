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

class RenderableKeyTest < ActiveSupport::TestCase
  include CachingTestHelper, CachingUtils
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_should_use_latest_version_of_page_in_renderable_key
    page = @project.pages.first
    page.update_attributes(:name => 'new name')
    assert_equal "#{page.class}/#{page.id}/#{page.version}", key(page)
  end
  
  def test_should_use_latest_version_of_card_in_renderable_key
    card = @project.cards.find_by_number(1)
    assert_equal "#{card.class}/#{card.id}/#{card.version}", key(card)
  end

  def test_should_use_version_number_from_page_version_and_id_from_page_in_key
    page = @project.pages.first
    page.update_attributes(:name => 'new foo')
    page.update_attributes(:name => 'another_new_name')
    second_version = page.reload.versions[1]
    assert_equal "#{page.class}/#{page.id}/2/false", key(second_version)
  end  
  
  def test_should_use_version_number_from_card_version_and_id_from_card_in_key
    card = @project.cards.find_by_number(1)
    card_version = card.versions[1]
    assert_equal "#{card.class}/#{card.id}/2/true", key(card_version)
  end
  
  def test_should_use_latest_version_of_page_and_macro_content_key_in_renderable_key
    card = @project.cards.find_by_number(1)
    card_version = card.versions[1]
    assert_equal "#{card.class}/#{card.id}/2/true", key(card_version)
  end

  def key(renderable)
    KeySegments::Renderable.new(renderable).to_s
  end
end
