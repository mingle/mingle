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

class TransitionsExporterTest <  ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    assert TransitionsExporter.new('').exports_to_sheet?
    assert_equal 'Transitions', TransitionsExporter.new('').name
  end

  def test_sheet_should_contain_correct_transitions_data
    login_as_admin
    full_user = create_user!(name:'full user')
    readonly_user = create_user!(name: 'readonly user')

    with_new_project do |project|
      card_type = project.card_types.create(name: 'Story')

      project.add_member(readonly_user, :readonly_member)
      project.add_member(full_user)

      qas = create_group('qas', [readonly_user])

      status_prop_def = project.create_text_list_definition!(:name => 'status', :type => 'Managed text list', :description => 'It is a manage text property')
      estimate_prop_def = project.create_text_list_definition!(:name => 'estimate', :type => 'Managed text list', :description => 'It is a manage text property')
      status_prop_def.create_enumeration_value!(:value => 'to do')
      status_prop_def.create_enumeration_value!(:value => 'doing')
      estimate_prop_def.create_enumeration_value!(:value => 'small')
      estimate_prop_def.create_enumeration_value!(:value => 'medium')

      card_type.add_property_definition status_prop_def
      card_type.add_property_definition estimate_prop_def
      card_type.save!

      transition_1 = create_transition(project, 'transition 1', :required_properties => {:status => 'to do', :estimate => 'small'}, :set_properties => {:status => 'doing', :estimate => Transition::USER_INPUT_REQUIRED}, :require_comment => true, :group_prerequisites => [qas.id], :card_type => card_type)
      transition_2 = create_transition(project, 'transition 2', :required_properties => {:status => 'doing', :estimate => 'medium'}, :set_properties => {:status => Transition::USER_INPUT_OPTIONAL, :estimate => 'small'}, :user_prerequisites => [full_user.id], :card_type => card_type)
      transition_3 = create_transition(project, 'transition 3', :required_properties => {:status => 'to do'}, :set_properties => {:status => 'doing'})


      transitions_exporter = TransitionsExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(transitions_exporter.name)
      transitions_exporter.export(sheet)

      assert_equal 9, sheet.headings.count
      assert_equal project.transitions.count + 1, sheet.number_of_rows
      assert_equal     ['Transition name', 'Card type', 'Restriction', 'Restricted to', 'Require murmur', 'Properties as pre-conditions to the transition', 'Initial property values', 'Properties to be set on transition', 'Final property values'], sheet.headings
      assert_equal [transition_1.name, card_type.name, 'Select groups', 'qas', 'Yes', "status\nestimate", "to do\nsmall", "status\nestimate", "doing\n(user input - required)"], sheet.row(1)
      assert_equal [transition_2.name, card_type.name, 'Select members', 'full user', 'No', "status\nestimate", "doing\nmedium", "status\nestimate", "(user input - optional)\nsmall"], sheet.row(2)
      assert_equal [transition_3.name, '(any)', 'All team members', '', 'No', 'status', 'to do', 'status', 'doing'], sheet.row(3)
    end
  end

  def test_should_be_exportable_when_transitions_are_defined
    login_as_admin
    with_new_project do |project|

      status_prop_def = project.create_text_list_definition!(:name => 'status', :type => 'Managed text list', :description => 'It is a manage text property')
      status_prop_def.create_enumeration_value!(:value => 'to do')
      status_prop_def.create_enumeration_value!(:value => 'doing')

      create_transition(project, 'transition 1', :required_properties => {:status => 'to do'}, :set_properties => {:status => 'doing'}, :require_comment => true)

      transitions_exporter = TransitionsExporter.new('')
      assert transitions_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_transitions_are_not_defined
    login_as_admin
    with_new_project do
      transitions_exporter = TransitionsExporter.new('')
      assert_false transitions_exporter.exportable?
    end
  end

end
