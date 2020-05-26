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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class ObjectiveTest < ActiveSupport::TestCase

  def setup
    create(:admin, login: :admin)
    login_as_admin
    @program = create(:program)
  end

  context 'ObjectiveValidations' do
   subject { FactoryGirl.create(:objective, :planned, program_id: FactoryGirl.create(:simple_program).id)}

   should belong_to(:program)
   should validate_presence_of(:start_at)
   should validate_uniqueness_of(:name).scoped_to(:program_id).case_insensitive.with_message('already used for an existing Objective in your Program.')
   should validate_presence_of(:end_at)
   should validate_length_of(:name).is_at_most(80)
   should have_many(:objective_property_value_mappings).dependent(:destroy)
   should have_many(:objective_property_definitions).through(:objective_type)
 end

  def test_should_fetch_all_objective_ordered_by_position_and_status
    backlog_objective_1 = create(:objective, :backlog, name:'backlog objective 1', program_id: @program.id)
    backlog_objective_2 = create(:objective, :backlog, name:'backlog objective 2', program_id: @program.id)
    planned_objective_1 = create(:objective, :planned, name:'planned objective 1', program_id: @program.id, position:2)
    planned_objective_2 = create(:objective, :planned, name:'planned objective 2', program_id: @program.id, position:1)

    expected_objectives = [backlog_objective_2, planned_objective_2, backlog_objective_1, planned_objective_1].map(&:reload)
    assert_equal expected_objectives, Objective.all_objectives
  end

  def test_should_be_assigned_number
    # number_of_objectives = @program.objectives.planned.size
    objective = @program.objectives.planned.create(name: 'first', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 1 , objective.number
    objective = @program.objectives.planned.create(name: 'second', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 2, objective.number
  end

  def test_should_generate_identifier
    objective = @program.objectives.planned.create!(name: 'valid name 1234567890', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'valid_name_1234567890', objective.identifier
  end

  def test_should_retain_identifier_on_updating_objective_attributes_other_than_name
    objective = @program.objectives.planned.create!(name: 'a new objective', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'a_new_objective', objective.identifier
    objective.end_at = '2011-2-2'
    objective.save!
    assert_equal 'a_new_objective', objective.identifier
  end

  def test_should_retain_identifier_on_multiple_updates_without_name_change
    objective = @program.objectives.planned.create!(name: 'a new objective', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'a_new_objective', objective.identifier
    objective.end_at = '2011-2-2'
    objective.save!
    objective.end_at = '2011-2-2'
    objective.save!
    assert_equal 'a_new_objective', objective.identifier
  end

  def test_should_update_objective_identifier_when_name_is_udpated
    objective = @program.objectives.planned.create!(name: 'a new objective', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'a_new_objective', objective.identifier
    objective.name = 'updated name'
    objective.save!
    assert_equal 'updated_name', objective.identifier
  end

  def test_should_generate_unique_identifier
    objective = @program.objectives.planned.create!(name: 'objective name', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'objective_name', objective.identifier

    objective = @program.objectives.planned.create!(name: 'objective:name', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'objective_name1', objective.identifier

    objective = @program.objectives.planned.create!(name: 'objective@name', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'objective_name2', objective.identifier
  end

  def test_objective_name_can_have_special_characters
    objective = @program.objectives.planned.create!(name: 'what!?@#$%^', start_at: '2011-1-1', end_at: '2011-2-1')
    assert objective.valid?
  end

  def test_objective_name_can_start_with_numbers
    objective = @program.objectives.planned.create!(name: '1st Feature', start_at: '2011-1-1', end_at: '2011-2-1')
    assert_equal 'objective_1st_feature', objective.identifier
    assert objective.valid?
  end

  def test_validate_objective_name
    objective = @program.objectives.planned.create(name: '   ', start_at: '2011-1-1', end_at: '2011-2-1')

    objective.name = 'valid name with number 1234567890'
    assert objective.valid?
  end

  def test_objective_end_date_should_be_after_start_date
    objective = @program.objectives.planned.create(name: 'name', start_at: '2011-2-1', end_at: '2011-1-1')
    assert !objective.valid?
    assert_equal ['should be after start date'], objective.errors[:end_at]
    assert_equal 'End at should be after start date', objective.errors.full_messages.join(', ')
  end

  def test_should_strip_objective_name_on_save
    objective = @program.objectives.planned.create(:name => '  name     should be    stripped ', start_at: '2011-2-1', end_at: '2011-1-1')
    assert_equal 'name should be stripped', objective.name
  end

  def test_objective_name_must_be_unique_ignoring_whitespace
    @program.objectives.create( :name => ' my  objective ', start_at: '2011-2-1', end_at: 2.days.from_now)
    objective_with_same_name = @program.objectives.create({:name => '     my   objective    ', :start_at => Time.now, :end_at => 2.days.from_now})
    assert_false objective_with_same_name.valid?
  end

  def test_changing_objective_start_at_should_update_plan_start_at_when_it_is_before_plan
    @program.objectives.planned.create( :name => ' my  objective ', start_at: 1.week.ago(@program.plan.start_at), end_at: 2.days.from_now)
    @program.plan.update_attributes({:start_at => '15 Feb 2011', :end_at => '1 Sep 2011'})
    objective = @program.objectives.planned.first
    objective.start_at = 1.week.ago(@program.plan.start_at)
    objective.save

    assert_equal objective.start_at, @program.plan.reload.start_at
  end

  def test_changing_objective_end_at_should_update_plan_end_at_when_it_is_before_plan
    @program.objectives.planned.create( :name => ' my  objective ', start_at: '2011-2-1', end_at: 2.days.from_now)
    @program.plan.update_attributes({:start_at => '15 Feb 2011', :end_at => '1 Sep 2011'})
    objective = @program.objectives.planned.first
    objective.end_at = 1.week.since(@program.plan.end_at)
    objective.save

    assert_equal objective.end_at, @program.plan.reload.end_at
  end

  def test_when_objective_is_within_plan_do_not_change_plan_dates
    @program.plan.update_attributes({:start_at => '15 Feb 2011', :end_at => '1 Sep 2011'})
    @program.objectives.planned.create( :name => ' my  objective ', start_at: '2011-2-1', end_at: 2.days.from_now)
    objective = @program.objectives.planned.first

    assert_no_difference '@program.plan.reload.start_at' do
      objective.update_attributes(:start_at => 1.week.since(@program.plan.start_at))
    end

    assert_no_difference '@program.plan.reload.end_at' do
      objective.update_attributes(:end_at => 1.week.ago(@program.plan.end_at))
    end
  end

  def test_backlog_objectives_are_sorted_as_last_inserted_on_top
    @program.objectives.backlog.create!({name: 'A'})
    @program.objectives.backlog.create!({name: 'B'})
    @program.objectives.backlog.create!({name: '1'})

    assert_equal %w(1 B A), @program.objectives.backlog.map(&:name)
  end

  def test_planned_objectives_are_sorted_as_last_inserted_on_top
    create(:objective, :planned, name: 'A', program_id: @program.id)
    create(:objective, :planned, name: 'B', program_id: @program.id)
    create(:objective, :planned, name: '1', program_id: @program.id)

    assert_equal %w(1 B A), @program.objectives.planned.map(&:name)
  end

  def test_after_backlog
    @program.objectives.backlog.create!({name: 'A'})
    objective_B = @program.objectives.backlog.create!({name: 'B'})
    objectives_after_B = @program.objectives.backlog.after(objective_B)
    assert_equal ['A'], objectives_after_B.map(&:name)
  end

  def test_on_delete_updates_position_for_objectives_in_backlog
    @program.objectives.backlog.create!({name: 'A'})
    objective_B = @program.objectives.backlog.create!({name: 'B'})
    objective_B.destroy
    objective_A = @program.objectives.backlog.find_by_name('A')
    assert_equal 1, objective_A.position
  end

  def test_on_delete_updates_position_for_planned_objectives
    objective_a = create(:objective, :planned, name: 'A', program_id: @program.id)
    objective_b  = create(:objective, :planned, name: 'B', program_id: @program.id)
    assert_equal 2, objective_a.reload.position
    assert_equal 1, objective_b.position
    objective_b.destroy
    assert_equal 1, objective_a.reload.position
  end

  def test_number_is_assigned_on_create
    backlog_objective = @program.objectives.backlog.create!(name: 'test')

    current_number = backlog_objective.number
    assert_not_nil current_number

    second_backlog_objective = @program.objectives.backlog.create!(name: 'test2')
    assert_equal current_number + 1, second_backlog_objective.number
  end

  def test_should_sanitize_value_statement
    html_text = "<div>Hello</div><unsafe-tag>Unsafe content</unsafe-tag><style> div{color:red;}</style>"
    expected_sanitized_html =  "<div>Hello</div>Unsafe content"
    HtmlSanitizer.any_instance.expects(:sanitize).with(html_text).returns("<div>Hello</div><unsafe-tag>Unsafe content</unsafe-tag>" )
    HtmlSanitizer.any_instance.expects(:sanitize).with("<div>Hello</div><unsafe-tag>Unsafe content</unsafe-tag>").returns(expected_sanitized_html )

    backlog_objective = create(:objective, :backlog, value_statement:html_text, program: @program)
    actual_sanitized_html = backlog_objective.value_statement

    assert_equal expected_sanitized_html, actual_sanitized_html
  end

  def test_should_transform_plain_text_value_statement_into_html
    plain_text = "This is  plain text.\n   With multiple line. \n\n This should get transform into multiple p tag."
    backlog_objective = create(:objective, :backlog, value_statement: plain_text, program: @program)

    expected_transformed_value_statement = "<p>This is&nbsp;&nbsp;plain text.</p></br><p>&nbsp;&nbsp;&nbsp;With multiple line. </p></br><p></p></br><p> This should get transform into multiple p tag.</p>"
    actual_value_statement = @program.objectives.backlog.find(backlog_objective.id).value_statement
    assert_equal expected_transformed_value_statement, actual_value_statement
  end

  def test_should_not_transform_html_value_statement
    plain_text = "<h1>This is value statement.</h1><p>This value should not get transformed</p>"
    backlog_objective = create(:objective, :backlog, value_statement: plain_text, program: @program)

    actual_value_statement = @program.objectives.backlog.find(backlog_objective.id).value_statement
    assert_equal plain_text, actual_value_statement
  end

  def test_should_strip_name
    backlog_objective = create(:objective, :backlog, name:' Stripped name   ' , program: @program )

    assert_equal 'Stripped name', backlog_objective.name
  end

  def test_objective_should_have_versions
    objective = create(:objective, :backlog, program_id: @program.id)
    versions = objective.versions
    assert_equal  1, versions.count
    assert_equal objective.id, versions.first.objective_id

  end

  def test_objective_create_should_create_event_with_objective_version_event_type
    objective = create(:objective, :backlog, program_id: @program.id)

    version = objective.versions.first
    version.reload
    assert_equal objective.id, version.objective_id
    assert_equal 'Objective::Version', version.event.origin_type
    assert_equal version.id, version.event.origin_id
    assert_equal 'ObjectiveVersionEvent', version.event.type
  end

  def test_destroy_should_create_event_with_objective_deletion_event_type
    objective = create(:objective, :backlog, program_id: @program.id)
    objective_id = objective.id

    objective.destroy

    versions = Objective::Version.all.where(objective_id: objective_id )

    assert versions.all? do |version|
      'Objective::Version' == version.event.origin_type && version.id == version.event.origin_id
    end
    assert versions.any? { |version| 'ObjectiveDeletionEvent' == version.event.type }
  end

  def test_should_set_default_objective_type_if_not_set
    objective = create(:objective, :backlog, program_id: @program.id)

    assert_equal(@program.default_objective_type, objective.objective_type)
  end

  def test_should_create_objective_property_value_mappings
    obj = create(:objective, :backlog, program_id: @program.id, value: 40, size: 60)
    obj.create_property_value_mappings({Size:{name:'Size', value:60}, Value:{name:'Value', value:40}})
    assert_equal 2, obj.objective_property_value_mappings.length

    size_prop_def = obj.objective_property_definitions.find_by_name('Size')
    size_prop_def_value_id = size_prop_def.objective_property_values.find_by_value(60).id
    assert_false obj.objective_property_value_mappings.find_by_obj_prop_value_id(size_prop_def_value_id).nil?

    value_prop_def = obj.objective_property_definitions.find_by_name('Value')
    value_prop_def_value_id = value_prop_def.objective_property_values.find_by_value(40).id
    assert_false obj.objective_property_value_mappings.find_by_obj_prop_value_id(value_prop_def_value_id).nil?
  end

  def test_should_update_objective_property_mapping
    obj = create(:objective, :backlog, program_id: @program.id)
    obj.create_property_value_mappings({Size:{name:'Size', value:60}, Value:{name:'Value', value:40}})

    value_prop_def = obj.objective_property_definitions.find_by_name('Value')
    value_prop_def_value_id = value_prop_def.objective_property_values.find_by_value(40).id
    assert_false obj.objective_property_value_mappings.find_by_obj_prop_value_id(value_prop_def_value_id).nil?

    assert obj.update_attributes({property_definitions:{Value:{name:'Value', value:80}}})

    value_prop_def = obj.objective_property_definitions.find_by_name('Value')
    value_prop_def_value_id = value_prop_def.objective_property_values.find_by_value(80).id
    assert_false obj.objective_property_value_mappings.find_by_obj_prop_value_id(value_prop_def_value_id).nil?
  end

  def test_update_attributes_should_create_property_value_mapping_if_not_present
    obj = create(:objective, :backlog, program_id: @program.id)
    obj.create_property_value_mappings({Size:{name:'Size', value:60}})

    assert_equal 1, obj.objective_property_value_mappings.length

    assert obj.update_attributes({property_definitions:{Value:{name:'Value', value:80}}})

    value_prop_def = obj.objective_property_definitions.find_by_name('Value')
    value_prop_def_value_id = value_prop_def.objective_property_values.find_by_value(80).id

    assert_equal 2, obj.objective_property_value_mappings.length
    assert_false obj.objective_property_value_mappings.find_by_obj_prop_value_id(value_prop_def_value_id).nil?
  end

  def test_should_not_update_property_mapping_for_unknown_value
    obj = create(:objective, :backlog, program_id: @program.id)
    obj.create_property_value_mappings({Size:{name:'Size', value:60}})

    assert_equal 1, obj.objective_property_value_mappings.length

    assert obj.update_attributes({property_definitions:{Value:{name:'Value', value:23}}})

    assert_equal 1, obj.objective_property_value_mappings.length
  end

  def test_to_params_should_include_property_definition
    obj = create(:objective, :backlog, program_id: @program.id)
    obj.create_property_value_mappings({Size:{name:'Size', value:60}})
    allowed_values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    expected = {
        name: obj.name, number: obj['number'], position: obj['position'],
        status: obj['status'], value_statement: obj['value_statement'],
        property_definitions: {
            Size:{name: 'Size', value: 60, :allowed_values=> allowed_values},
            Value:{name: 'Value', value: '(not set)', :allowed_values=> allowed_values}
        }
    }
    assert_equal(expected, obj.to_params)
  end
end
