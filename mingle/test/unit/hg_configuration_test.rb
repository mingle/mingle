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

class HgConfigurationTest < ActiveSupport::TestCase

  def setup
    @project = create_project
    login_as_admin
  end

  def test_to_xml
    requires_jruby do
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path => '/a_repos', :username => 'test', :password => 'password')
      xml = config.to_xml(:version => 'v2', :view_helper => OpenStruct.new.mock_methods({:rest_project_show_url => 'url_for_project'}))

      document = REXML::Document.new(xml)
      assert_equal config.id.to_s, document.element_text_at('/hg_configuration/id')
      assert_equal 'url_for_project', document.attribute_value_at('/hg_configuration/project/@url')
      assert_equal %w(identifier name), document.get_elements('/hg_configuration/project/*').map(&:name).sort
      assert_equal '/a_repos', document.element_text_at('/hg_configuration/repository_path')
      assert_equal 'test', document.element_text_at('/hg_configuration/username')
      assert_equal 'false', document.element_text_at('/hg_configuration/marked_for_deletion')
    end
  end
  
  def test_to_xml_omits_password
    requires_jruby do
      config = HgConfiguration.create!(:project => @project, :repository_path => '/foo/bar', :password => 'open sesame')
      assert config.to_xml.index('/foo/bar')
      assert !config.to_xml.index('open sesame')
    end
  end
  
end
