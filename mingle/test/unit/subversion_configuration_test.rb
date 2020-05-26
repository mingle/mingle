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

class SubversionConfigurationTest < ActiveSupport::TestCase

  def setup
    @project = create_project
    login_as_admin
  end

  def test_blank_repository_password_is_ok
    config = new_repos_config(:repository_path => "http://bob_repository/trunk")
    assert config.reload.password.blank?
    config.password = nil
    config.save!
    assert config.reload.password.blank?
    config.password = ''
    config.save!
    assert config.reload.password.blank?
    config.password = ' '
    config.save!
    assert config.reload.password.blank?
  end

  def test_repository_password_is_encrypted_in_db
    config = new_repos_config(:username =>"test", :password => "password", :repository_path =>"/a_repos")
    assert !config.send(:read_attribute, :password).blank?
    assert "password" != config.send(:read_attribute, :password)
    assert_equal "password", config.decrypted_password
  end

  def test_username_password_and_repository_path_are_trimmed_on_save
    config = new_repos_config({:username=>"  bob  ", :password=> "   new password   ", :repository_path=> "  http://bob_repository/trunk  "})
    assert_equal "new password", config.decrypted_password
    assert_equal "http://bob_repository/trunk", config.repository_path
    assert_equal "bob", config.username
    assert_attribute_trim_on_write(config, :password, "decrypted_password")
    assert_attribute_trim_on_write(config, :username)
  end
  
  def assert_attribute_trim_on_write(config, attribute, attribute_fetch_method_name = "")
    config.send("#{attribute}=", "   foobar   ")
    config.save!
    assert_equal "foobar", fetch_attribute(config, attribute, attribute_fetch_method_name)
    config.send("#{attribute}=", "  ")
    config.save!
    assert_blank fetch_attribute(config, attribute, attribute_fetch_method_name)
    config.send("#{attribute}=", nil)
    config.save!
    assert_nil fetch_attribute(config, attribute, attribute_fetch_method_name)
  end

  def fetch_attribute(config, attribute, attribute_fetch_method_name)
    if attribute_fetch_method_name.blank?
      config.reload.send(attribute)
    else
      config.reload.send(attribute_fetch_method_name)
    end
  end

  def test_to_xml
    config = new_repos_config(:username =>"test", :password => "password", :repository_path =>"/a_repos")
    
    document = REXML::Document.new(config.to_xml(:version => "v1"))
    
    assert_equal config.id.to_s, document.element_text_at("/subversion_configuration/id")
    assert_equal false.to_s, document.element_text_at("/subversion_configuration/marked_for_deletion")
    assert_equal config.project_id.to_s, document.element_text_at("/subversion_configuration/project_id")
    assert_equal "/a_repos", document.element_text_at("/subversion_configuration/repository_path")
    assert_equal "test", document.element_text_at("/subversion_configuration/username")
  end
  
  def test_to_xml_version_2_should_link_to_project_resource
    config = new_repos_config(:username =>"test", :password => "password", :repository_path =>"/a_repos")
    xml = config.to_xml(:version => "v2", :view_helper => OpenStruct.new.mock_methods({:rest_project_show_url => "url_for_project"}))
    
    document = REXML::Document.new(xml)
    assert_equal "url_for_project", document.attribute_value_at("/subversion_configuration/project/@url")
    assert_equal ['identifier', 'name'], document.get_elements("/subversion_configuration/project/*").map(&:name).sort
    assert_equal 0, document.get_elements("/subversion_configuration/project_id").size
  end
  
  def test_source_browsing_ready_returns_true_for_subversion_configuration
    assert_equal true, new_repos_config.source_browsing_ready?
  end
  
  # bug 8515 
  def test_should_not_create_more_than_one_configuration
    config = new_repos_config(:username =>"test", :password => "password", :repository_path =>"/a_repos")
    new_config = new_repos_config(:username =>"test1", :password => "password1", :repository_path =>"/a_repos/1")
    
    configs = SubversionConfiguration.find(:all)
    
    assert_equal 1, configs.size
    assert_equal "/a_repos", configs.first.repository_path
    assert_equal ["Could not create the new repository configuration because a repository configuration already exists."], new_config.errors.full_messages
  end

  # bug 8515
  def test_should_allow_creation_of_a_second_configuration_if_exisiting_is_marked_for_delete
    config = new_repos_config(:username =>"test", :password => "password", :repository_path =>"/a_repos", :marked_for_deletion => true)
    new_config = new_repos_config(:username =>"test1", :password => "password1", :repository_path =>"/a_repos/1")
    
    configs = SubversionConfiguration.find(:all)
    assert_equal 2, configs.size
    
    not_for_delete = configs.find_all { |c| !c.marked_for_deletion? }
    assert_equal 1, not_for_delete.size
    assert_equal "/a_repos/1", not_for_delete.first.repository_path
    assert not_for_delete.first.errors.empty?
  end

  protected
  
  def new_repos_config(options = {})
    SubversionConfiguration.create_or_update(@project.id, options[:id], options)
    # SubversionConfiguration.create!({:project_id => @project.id}.merge(options))
  end
end
