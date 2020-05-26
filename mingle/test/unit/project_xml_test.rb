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

class ProjectXmlTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    SmtpConfiguration.load
    @project = first_project
    @project.activate
    login_as_admin
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end

  def test_to_xml_should_not_include_secret_key
    assert !@project.to_xml.include?("secret_key")
  end

  def test_to_xml_should_not_include_cards_table
    assert !@project.to_xml.include?("cards_table")
  end

  def test_to_xml_v2_should_not_add_extra_value_element_for_keywords
    @project.update_attribute :card_keywords, 'hungry, bonna'
    xml = @project.to_xml(:version => 'v2')
    assert xml =~ /<keyword>hungry<\/keyword>/
    assert xml =~ /<keyword>bonna<\/keyword>/
  end

  def test_to_xml_v1__should_show_card_keywords_in_seperated_lines
    @project.update_attribute :card_keywords, 'hungry, bonna'
    xml = @project.to_xml(:version => 'v1')
    assert xml =~ /<keyword>\n\s*(.*)<value(.*)>hungry<\/value>\n\s*(.*)<\/keyword>/
    assert xml =~ /<keyword>\n\s*(.*)<value(.*)>bonna<\/value>\n\s*(.*)<\/keyword>/
  end

  def test_to_xml_should_include_public_attribute_version_1
    xml = @project.to_xml(:version => "v1")
    ['created_at', 'modified_by_user_id', 'updated_at', 'anonymous_accessible', 'created_by_user_id', 'date_format', 'description', 'email_address', 'email_sender_name', 'id', 'identifier', 'name', 'precision', 'template', 'time_zone'].each do |attribute|
      assert xml =~ /(<#{attribute}(.*)>(.*)<\/#{attribute}>)|(<#{attribute}\/>)/
    end
  end

  def test_to_xml_should_include_public_attribute_version_2
    xml = @project.to_xml(:version => "v2")
    document = REXML::Document.new(xml)
    elements = document.elements_at('//project/*').map(&:name)
    expected_elements = %w{created_at auto_enroll_user_type keywords modified_by updated_at anonymous_accessible created_by date_format description email_address email_sender_name identifier name precision template time_zone}
    assert_equal expected_elements.sort, elements.sort
  end

  def test_v2_to_xml_created_by_user_should_be_compact
    project_as_xml = @project.to_xml(:version => 'v2')
    assert_equal @project.created_by.name, get_element_text_by_xpath(project_as_xml, "//project/created_by/name")
    assert_equal @project.created_by.login, get_element_text_by_xpath(project_as_xml, "//project/created_by/login")
    document = REXML::Document.new(project_as_xml)
    assert_equal ['login', 'name'], document.elements_at("//project/created_by/*").map(&:name).sort
  end

  def test_v2_to_xml_modified_by_user_should_be_compact
    project_as_xml = @project.to_xml(:version => 'v2')
    assert_equal @project.modified_by.name, get_element_text_by_xpath(project_as_xml, "//project/modified_by/name")
    assert_equal @project.modified_by.login, get_element_text_by_xpath(project_as_xml, "//project/modified_by/login")
    document = REXML::Document.new(project_as_xml)
    assert_equal ['login', 'name'], document.elements_at("//project/modified_by/*").map(&:name).sort
  end

  def test_to_xml_version_2_of_project_xml_should_contain_a_link_to_source_control
    new_repos_config(@project, :password => 'top-secret-stuff').id
    config = @project.send(:repository_configuration)
    view_helper.default_url_options = { :host => 'example.com' }
    xml = @project.to_xml(:version => "v2", :view_helper => view_helper)

    document = REXML::Document.new(xml)
    assert_equal "http://example.com/api/v2/projects/first_project/subversion_configurations.xml", document.attribute_value_at("/project/subversion_configuration/@url")
    assert_equal 0, document.get_elements("/project/subversion_configuration/*").size
  end

  def test_to_xml_should_not_include_subversion_configuration_if_no_repository_configuration_exists
    xml = @project.to_xml(:version => 'v2')
    document = REXML::Document.new(xml)
    project_elements = document.elements_at("/project/*").map(&:name)
    assert_not project_elements.include?('subversion_configuration')
  end

  def test_to_xml_should_never_include_perforce_configuration
    config = PerforceConfiguration.create!({:project_id => @project.id, :username => 'name', :repository_path => 'path', :host => 'host', :port => 1})
    @project.reload
    config = @project.send(:repository_configuration)

    xml = @project.to_xml(:version => 'v2')
    document = REXML::Document.new(xml)
    project_elements = document.elements_at("/project/*").map(&:name)
    assert_not project_elements.include?('perforce_configuration')
    assert_not project_elements.include?('subversion_configuration')
  end

  def test_should_not_include_any_not_shown_attribute
    xml = @project.to_xml
    ['icon', 'hidden'].each do |attribute|
      assert xml !~ /<#{attribute}(.*)>(.*)<\/#{attribute}>/
    end
  end

  def new_repos_config(project, options = {})
    config = SubversionConfiguration.create!({:project_id => project.id, :repository_path => "foorepository"}.merge(options))
    project.reload
    config
  end

end
