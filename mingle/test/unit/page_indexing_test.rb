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

class PageIndexingTest < ActiveSupport::TestCase

  def setup
    @user = create_user! :login => 'zaphod', :email => 'zaphod@galaxy.org', :name => 'Zaphod Beeblebrox', :version_control_user_name => 'zbeeblebrox'
    login(@user.email)
    @project = first_project
    @project.activate
  end
  
  def teardown
    @project.deactivate
  end
  
  
  def test_when_indexed_should_include_name
    page = @project.pages.create!(:name => 'Brother Tode')
    assert_equal 'Brother Tode', page.as_json_for_index['name']
  end
  
  def test_when_indexed_should_include_project_id
    page = @project.pages.create!(:name => 'Brother Tode')
    assert_equal @project.id, page.as_json_for_index[:project_id]
  end
  
  def test_when_indexed_should_include_content
    page = @project.pages.create!(:name => 'Brother Tode', :content => 'leader of the deviants')
    assert_equal 'leader of the deviants', page.as_json_for_index[:indexable_content]
  end

  def test_indexed_content_should_not_include_italics_markup
    page = @project.pages.create!(:name => 'Hammerhead', :content => 'I have a hammer shaped head, can you _believe_ it?')
    assert_equal 'I have a hammer shaped head, can you believe it?', page.as_json_for_index[:indexable_content]
  end

  def test_when_indexed_should_not_include_version
    page = @project.pages.create!(:name => 'Bullet')
    assert_not_nil page.version
    assert !page.as_json_for_index.has_key?('version')
  end

  def test_when_indexed_should_include_created_by
    page = @project.pages.create!(:name => 'Brother Tode')
    json = page.as_json_for_index[:created_by]
    assert_equal 'Zaphod Beeblebrox', json['name']
    assert_equal 'zaphod', json['login']
    assert_equal 'zaphod@galaxy.org', json['email']
    assert_equal 'zbeeblebrox', json['version_control_user_name']
  end
  
  def test_when_indexed_should_include_modified_by
    page = @project.pages.create!(:name => 'Brother Tode')
    json = page.as_json_for_index[:modified_by]
    assert_equal 'Zaphod Beeblebrox', json['name']
    assert_equal 'zaphod', json['login']
    assert_equal 'zaphod@galaxy.org', json['email']
    assert_equal 'zbeeblebrox', json['version_control_user_name']
  end
  
  def test_when_index_should_include_tags
    page = @project.pages.create!(:name => 'Brother Tode')
    page.tag_with('rss')
    assert_equal ['rss'], page.as_json_for_index[:tag_names]
  end
end
