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

class RebuildCardRevisionLinkObserverTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    login_as_admin
  end
  
  def test_update_card_keywords_marks_card_revision_links_invalid
    @project.update_attribute :card_keywords, 'card, #'
    SubversionConfiguration.create!({:project_id => @project.id, :repository_path => "foorepository"})
    @project.reload
    assert !@project.repository_configuration.card_revision_links_invalid      
    @project.update_attributes(:card_keywords => "card, page, #")
    
    assert @project.repository_configuration.card_revision_links_invalid
  end
  
  def test_update_card_keywords_does_not_mark_card_revision_links_invalid_when_value_does_not_change
    @project.update_attribute :card_keywords, "card, page, #"
    SubversionConfiguration.create!({:project_id => @project.id, :repository_path => "foorepository"})
    @project.reload

    @project.card_keywords = "card, page, #"
    @project.save!
    assert !@project.repository_configuration.card_revision_links_invalid
  end
  
  def test_update_identifier_should_mark_card_revision_links_invalid
    with_new_project do |project|
      project.update_attribute :card_keywords, 'card, #'
      SubversionConfiguration.create!({:project_id => project.id, :repository_path => "foorepository"})
      project.reload
      assert !project.repository_configuration.card_revision_links_invalid      
      project.update_attributes(:identifier => project.identifier + "_new")
      assert project.repository_configuration.card_revision_links_invalid
    end
  end
  
  def test_update_identifier_should_not_mark_card_revision_links_invalid_when_identifier_value_does_not_changed
    @project.update_attribute :card_keywords, "card, page, #"
    SubversionConfiguration.create!({:project_id => @project.id, :repository_path => "foorepository"})
    @project.reload

    @project.update_attributes(:identifier => @project.identifier)
    
    assert !@project.repository_configuration.card_revision_links_invalid    
  end

end
