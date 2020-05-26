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

class DBTemplateTest < ActiveSupport::TestCase

  def setup
    login_as_member
  end

  def test_qualified_for_a_template_in_db
    template = create_project :identifier => 'db_template'
    template.update_attribute(:template, true)

    assert DBTemplate.new('db_template').qualified?
  end

  def test_qualified_for_a_non_existing_template
    assert_false DBTemplate.new('non_existing').qualified?
  end

  def test_copy_into
    template = create_project
    template.update_attribute(:template, true)
    template.card_types.first.update_attribute :name, 'This is Card Type imported from db template'

    project = create_project
    DBTemplate.new(template.identifier).copy_into(project, {})

    assert_equal 'This is Card Type imported from db template', project.card_types.first.name
  end

  def test_templates_return_all_templates_that_are_not_hidden
    template1 = create_project :name => "template1", :description => "this is a template"
    template1.update_attribute(:template, true)

    template2 = create_project :name => "template2"
    template2.update_attribute(:template, true)
    template2.update_attribute(:hidden, true)

    db_templates = DBTemplate.templates
    assert_equal ["template1"], db_templates.map(&:name)
    assert_equal ["this is a template"], db_templates.map(&:description)
  end

  def test_templates_does_not_return_pre_defined_templates
    template1 = create_project :name => "template1"
    template1.update_attribute(:template, true)

    template2 = create_project :name => "template2"
    template2.update_attribute(:template, true)
    template2.update_attribute(:pre_defined_template, true)

    assert_equal ["template1"], DBTemplate.templates.map(&:name)
  end

  def test_objects_returned_from_templates_should_be_a_real_project_object
    template = create_project
    template.update_attribute(:template, true)
    assert_equal [Project], DBTemplate.templates.map(&:class)
  end

end
