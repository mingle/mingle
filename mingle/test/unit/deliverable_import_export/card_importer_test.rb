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

class CardImporterTest < ActiveSupport::TestCase
  include CardImporterTestHelper
  
  self.use_transactional_fixtures = false
  
  def setup
    @project = create_project
    login_as_member
    
    @full_raw_excel_content_file_path = SwapDir::CardImportingPreview.file(@project).pathname
    @raw_excel_content_file_path = @full_raw_excel_content_file_path
  end
  
  def teardown
    FileUtils.rm_rf(@full_raw_excel_content_file_path) if File.exist?(@full_raw_excel_content_file_path)
  end
  
  def test_should_mark_queued_after_created_card_import
    import_text = %{name
      card name
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    assert_equal "queued", import.status
  end

  def test_import_existed_card_type
    story_type = @project.card_types.create :name => 'story'
    import_text = %{name\ttype
      card name\t#{story_type.name}
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    
    @project.reload
    
    assert_equal 1, @project.cards.size
    assert_equal 'story', @project.cards.first.card_type_name
  end
  
  def test_should_create_card_type_when_card_type_not_exist
    login_as_admin
    type_not_exist = 'story'
    import_text = %{name\ttype
      card name\t#{type_not_exist}
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    
    @project.reload
    assert_equal 1, @project.cards.size
    assert_equal type_not_exist, @project.cards.first.card_type_name
    
    assert_not_nil @project.card_types.find_by_name(type_not_exist)
  end
  
  def test_should_use_first_card_type_in_project_if_card_type_is_not_specified_while_importing
    @project.card_types.create :name => 'story'
    @project.card_types.create :name => 'bug'
    
    first_card_type_name = @project.reload.card_types.first.name
    import_text = %{name
      card name
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    
    @project.reload
    assert_equal 1, @project.cards.size
    assert_equal first_card_type_name, @project.cards.first.card_type_name
  end
  
  def test_should_make_new_property_available_to_card_type_when_its_card_has_value_of_the_property
    login_as_admin
    story_type = @project.card_types.create :name => 'story'
    bug_type = @project.card_types.create :name => 'bug'
    import_text = %{name\ttype\tstatus
      card name\tstory\topen
      card name\tbug\t
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    assert_equal [], import.error_details
    @project = Project.current.reload
    assert_equal ['story'], @project.find_property_definition('status').card_types.collect(&:name)
  end
  
  def test_should_make_property_available_to_card_type_when_card_type_is_new_and_its_card_has_value_of_the_property
    login_as_admin
    import_text = %{name\ttype\tstatus
      card name\tnew type\topen
      card name\tanother new type\topen
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    assert_equal [], import.error_details
    @project.reload
    assert_equal ['status'], @project.card_types.find_by_name('new type').property_definitions.collect(&:name)
    assert_equal ['status'], @project.card_types.find_by_name('another new type').property_definitions.collect(&:name)
  end
  
  def test_should_not_make_property_available_to_card_type_when_card_type_is_new_but_its_card_has_no_value_of_the_property
    login_as_admin
    import_text = %{name\ttype\tstatus
      card name\tnew type\t
      card name\tanother new type\t
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    assert_equal [], import.error_details
    @project.reload
    assert_equal [], @project.card_types.find_by_name('new type').property_definitions.collect(&:name)
    assert_equal [], @project.card_types.find_by_name('another new type').property_definitions.collect(&:name)
  end
  
  def test_should_not_change_relationship_between_existed_property_and_card_type
    setup_property_definitions :status => ['new', 'open']
    story_type = @project.card_types.create :name => 'story'
    bug_type = @project.card_types.create :name => 'bug'
    story_type.add_property_definition @project.find_property_definition(:status)
    story_type.save!
    
    import_text = %{name\ttype\tstatus
      card name\tstory\t
      card name\tbug\topen
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    assert_equal [], import.error_details
    
    story_type.reload
    bug_type.reload
    assert_equal ['status'], story_type.property_definitions.collect(&:name)
    assert_equal [], bug_type.property_definitions.collect(&:name)
  end
  
  def test_should_raise_error_and_no_card_imported_when_importing_two_same_cp_property
    import_text = %{name\tfooBar\tFOOBAR
      card one\tnew\told
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    assert_equal 1, import.error_count
    assert_equal 0, import.created_count
    assert_equal 0, import.updated_count
    assert_equal [CardImport::DUPLICATE_HEADER_ERROR], import.error_details

    assert @project.reload.cards.empty?
  end
  
  def test_should_not_raise_error_and_import_column_as_description_when_importing_column_with_square_brackets
    login_as_admin
    import_text = %{name\t[fooBar]
      card one\tnew
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)  
    import.process!
    assert_equal 'new', @project.reload.cards.first.description
  end
  
  def test_import_processes_rows
    import_text = %{Number\tNameLike
      1\tNew Funky Name for Card One
      781\tCard Seven Eighty-One
      782\tShould be deleted
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path, {'Number' => 'number', 'NameLike' => 'name'}, [3])  
    import.process!
    assert_equal 'New Funky Name for Card One', @project.cards.find_by_number(1).name
    assert_equal 'Card Seven Eighty-One', @project.cards.find_by_number(781).name
    assert_nil @project.cards.find_by_number(782)
  end
  
  def test_request_should_remember_the_ignores_and_mappings
    mapping = {"Name"=>"name", "Priority"=>"description", "Description"=>"description"}
    ignore = [2, 3]
    write_content('')
    import = create_card_importer!(@project, @raw_excel_content_file_path, mapping, ignore)
    assert_equal mapping, import.mapping
    assert_equal ignore, import.ignore
  end
  
  def test_good_rows_still_imported_when_bad_rows
    setup_property_definitions :status => ['new', 'open']
    status = @project.find_property_definition('status')
    status.update_attribute(:restricted, true)
    
    create_card!(:name => 'pre-existing card', :number => 900)
    
    import_text = %{Number\tName\tStatus
      1\tNew Funky Name for Card One\topen
      781\tCard Seven Eighty-One\tillegal 
      782\tCard Seven Eighty-Two\tnew
      900\tNow Card 900\topen
    }
    write_content(import_text)
    import = create_card_importer!(@project.reload, @raw_excel_content_file_path, {'Number' => 'number', 'Name' => 'name', 'Status' => CardImport::Mappings::TEXT_LIST_PROPERTY})
    import.process!
    
    import.reload
    
    assert_equal 4, import.total
    assert_equal 1, import.error_count
    assert_equal 2, import.created_count
    assert_equal 1, import.updated_count
    assert_equal ["Row 2: Validation failed: #{'status'.bold} is restricted to #{'new'.bold} and #{'open'.bold}"], import.reload.error_details
    assert_equal 'New Funky Name for Card One', @project.cards.find_by_number(1).name
    assert_equal 'Card Seven Eighty-Two', @project.cards.find_by_number(782).name
    assert_nil @project.cards.find_by_number(781)
    assert_equal 'Now Card 900', @project.cards.find_by_number(900).name
  end
  
  def test_status_changed_along_with_processing
    import_text = %{Number\tName
      1\tNew Funky Name for Card One
      781\tCard Seven Eighty-One 
      782\tCard Seven Eighty-Two
      900\tNow Card 900\topen
    }
    write_content(import_text)
    import = create_card_importer!(@project.reload, @raw_excel_content_file_path)
    assert_equal 'queued', import.status
    import.process!
    assert_equal 'completed successfully', import.status
  end
  
  def test_no_rows_imported_when_bad_card_numbers
    import_text = %{Number\tName
      1\tNew Funky Name for Card One
      781d\tCard Seven Eighty-One 
    }
    write_content(import_text)
    import = create_card_importer!(@project.reload, @raw_excel_content_file_path)
    import.process!
    assert_nil @project.cards.find_by_number(1)
    
    assert_equal ["Cards were not imported. #{'781d'.bold} is not a valid card number."], import.error_details  
    assert_equal 'completed failed', import.status
  end
  
  def test_should_update_card_number_sequence_after_excel_import
    import_text = %{Number\tName
      1\tNew Funky Name for Card One
      781\tCard Seven Eighty-One 
    }
    write_content(import_text)
    create_card_importer!(@project.reload, @raw_excel_content_file_path).process!
    assert_equal 782, create_card!(:name => 'new after card import').number
  end
  
  def test_error_detail_should_be_empty_if_no_errors
    write_content('')
    assert_equal [], create_card_importer!(@project, @raw_excel_content_file_path).error_details
  end
  
  def test_error_detail_contains_useful_message_when_unable_to_create_a_custom_property
    login_as_admin
    too_long_name = "toolongttoolongttoolongttoolongttoolongttoolongttoolongttoolongttoolong"
    with_new_project do |project|
      import_text = %{Number\t#{too_long_name}
        1\tlow
        2\thigh 
      }
      write_content(import_text)
      import = create_card_importer!(project, @raw_excel_content_file_path)
      import.process!
      assert_nil project.cards.find_by_number(1)
      assert_equal ["Unable to create property #{too_long_name.bold}. Property Name is too long (maximum is 40 characters)."], import.error_details  
      assert_equal 'completed failed', import.status  
    end
  end
  
  def test_should_give_informative_warning_message_for_user_import
    login_as_admin
    with_new_project do |project|
      setup_user_definition 'developer'
      setup_user_definition 'tester'

      import_text = %{name\ttester\tdeveloper
        card one\tjennifer\tbar@bar.com
        card two\tfoo\tscott
      }
      write_content(import_text)
      import = create_card_importer!(project, @raw_excel_content_file_path)
      import.process!
      assert import.failed?
      assert_equal 0, project.cards.size
      assert_include "Row 1: Error with developer and tester columns. Project team does not include bar@bar.com and jennifer. User property values must be set to current team member logins.",
                     import.error_details
      assert_include "Row 2: Error with developer and tester columns. Project team does not include foo and scott. User property values must be set to current team member logins.",
                     import.error_details
    end
  end
  
  def test_should_provide_warning_but_still_save_cards_when_ignoring_properties_that_are_not_applicable_to_card_type
    login_as_admin
    with_new_project do |project|
      setup_property_definitions(:status => ['new', 'open'], :iteration => ['1', '2'], :release => ['3', '4'], :priority => ['high', 'low'])
      setup_card_type(project, 'story', :properties => ['status', 'iteration', 'release'])
      setup_card_type(project, 'bug', :properties => ['status', 'priority'])
      import_text = %{number\ttype\tstatus\titeration\trelease\tpriority
        1\tstory\tnew\t1\t4\tlow
        2\tstory\topen\t2\t3
        3\tbug\topen\t2\t4\tlow
      }
      write_content(import_text)
      import = create_card_importer!(project, @raw_excel_content_file_path)
      import.process!
      assert_equal 3, project.cards.size
      warning_details = import.warning_details
      assert_equal 2, warning_details.size
      assert_equal warning_details[0], "Row 1: #{'priority'.bold} ignored due to not being applicable to card type #{'story'.bold}."
      assert_equal warning_details[1], "Row 3: #{'iteration, release'.bold} ignored due to not being applicable to card type #{'bug'.bold}."
    end
  end
  
  def test_should_import_columns_with_ampersands_in_their_heading_as_description
    login_as_admin
    with_new_project do |project|
      import_text = %{name\tnotes & acceptance criteria\tcomments
        this story is about doing everything\tby doing this story I get everything\tand then I do not have to do anything else
        this story is about doing nothing\tby doing this story I get nothing\tand then I have to do everything else
      }
      write_content(import_text)
      import = create_card_importer!(project, @raw_excel_content_file_path)
      import.process!
      assert_equal "h3. notes & acceptance criteria\n\np(. by doing this story I get nothing\n\nh3. comments\n\np(. and then I have to do everything else", project.cards.find_by_name('this story is about doing nothing').description
    end
  end
  
  def test_should_process_when_the_propery_definition_is_transition_only_and_the_user_is_member
     login_as_member
     setup_property_definitions :status => ['open', 'close']
     status = @project.find_property_definition('status')
     status.update_attribute(:transition_only, true)
     card_1 = create_card!(:name => 'I am card 1')
     card_2 = create_card!(:name => 'I am card 2')
     card_2.update_attribute(:cp_status, 'open')
     import_text = %{number\tname\tstatus
        \tI am imported card\topen
        #{card_1.number}\tI am card 1\tclose
        #{card_2.number}\tI am card 2\tclose
     }
     write_content(import_text)
     import = create_card_importer!(@project, @raw_excel_content_file_path)
     import.process!
     assert_equal 0,  import.error_details.size
     assert_equal 3, @project.cards.size
     assert_equal 'open', @project.cards.find_by_name('I am imported card').cp_status
     assert_equal nil, card_1.reload.cp_status
     assert_equal 'open', card_2.reload.cp_status
  end
  
  def test_should_replace_columns_with_defaults_when_no_column_is_specified_and_when_cards_do_not_exist
    login_as_member
    
    setup_property_definitions :status => ['open', 'closed']
    status = @project.find_property_definition('status')
    
    setup_property_definitions :material => ['wood', 'gold']
    material = @project.find_property_definition('material')
    
    card_defaults = @project.card_types.find_by_name('Card').card_defaults
    default_description = 'default description'
    
    card_defaults.description = default_description
    card_defaults.update_properties(:status => 'open', :material => 'gold')
    card_defaults.save!
    
    new_name_1 = "new name 1"
    new_name_2 = "new name 2"
    new_name_3 = "new name 3"
    
    existing_name_1 = "existing name 1"
    existing_description_1 = "existing description 1"
    existing_name_2 = "existing name 2"
    existing_description_2 = "existing description 2"
    card_1 = create_card!(:name => existing_name_1, :description => existing_description_1)
    card_2 = create_card!(:name => existing_name_2, :description => existing_description_2)
    card_2.update_attribute(:cp_material, 'wood')
    
    import_text = %{number\tname\tstatus
       \t#{new_name_1}\topen
       \t#{new_name_2}\t
       \t#{new_name_3}\tclosed
       #{card_1.number}\t#{card_1.name}\topen
       #{card_2.number}\t#{card_2.name}\t
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!
    
    assert_equal 0, import.error_details.size
    
    assert_equal 5, @project.cards.size
    assert_equal 'open', @project.cards.find_by_name(new_name_1).cp_status
    assert_equal nil, @project.cards.find_by_name(new_name_2).cp_status
    assert_equal 'closed', @project.cards.find_by_name(new_name_3).cp_status
    assert_equal 'open', @project.cards.find_by_name(existing_name_1).cp_status
    assert_equal nil, @project.cards.find_by_name(existing_name_2).cp_status

    assert_equal 'gold', @project.cards.find_by_name(new_name_1).cp_material
    assert_equal 'gold', @project.cards.find_by_name(new_name_2).cp_material
    assert_equal 'gold', @project.cards.find_by_name(new_name_3).cp_material
    assert_equal nil, @project.cards.find_by_name(existing_name_1).cp_material
    assert_equal 'wood', @project.cards.find_by_name(existing_name_2).cp_material

    assert_equal default_description, @project.cards.find_by_name(new_name_1).description
    assert_equal default_description, @project.cards.find_by_name(new_name_2).description
    assert_equal default_description, @project.cards.find_by_name(new_name_3).description
    assert_equal existing_description_1, @project.cards.find_by_name(existing_name_1).description
    assert_equal existing_description_2, @project.cards.find_by_name(existing_name_2).description
  end
  
  def test_defaults_change_according_to_imported_card_type
    login_as_member
    
    story_type = @project.card_types.create :name => 'story'
    story_defaults = story_type.card_defaults
    story_default_description = 'story default description'
    story_defaults.description = story_default_description
    story_defaults.save!
    
    card_defaults = @project.card_types.find_by_name('Card').card_defaults
    card_default_description = 'card default description'
    card_defaults.description = card_default_description
    card_defaults.save!
    
    new_name_1 = "new name 1"
    new_name_2 = "new name 2"
    new_name_3 = "new name 3"
    new_name_4 = "new name 4"
    import_text = %{number\tname\ttype
       \t#{new_name_1}\tstory
       \t#{new_name_2}\tCard
       \t#{new_name_3}\tCard
       \t#{new_name_4}\tstory
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!
    
    assert_equal 0, import.error_details.size
    
    assert_equal 4, @project.cards.size
    assert_equal 'story', @project.cards.find_by_name(new_name_1).card_type.name
    assert_equal 'Card', @project.cards.find_by_name(new_name_2).card_type.name
    assert_equal 'Card', @project.cards.find_by_name(new_name_3).card_type_name
    assert_equal 'story', @project.cards.find_by_name(new_name_4).card_type_name

    assert_equal story_default_description, @project.cards.find_by_name(new_name_1).description
    assert_equal card_default_description, @project.cards.find_by_name(new_name_2).description
    assert_equal card_default_description, @project.cards.find_by_name(new_name_3).description
    assert_equal story_default_description, @project.cards.find_by_name(new_name_4).description
  end
  
  def test_should_import_free_numeric_properties
    login_as_admin
    import_text = <<-CSV
      Title\tId\tNumber
      Card 1\t1\t1
      Card 2\t2\t2
      Card 3\t3\t3
      Card 4\t4\t4
      Card 5\t5\t5
      Card 6\t6\t6
      Card 7\t7\t7
      Card 8\t8\t8
      Card 9\t9\t9
      Card 9\t10\t10
      Card 9\t11\t11
      Card 9\t12\t12
    CSV
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!
    @project.all_property_definitions.reload
    assert_equal TextPropertyDefinition, @project.find_property_definition('Id').class
    assert @project.find_property_definition('Id').numeric?
    assert_equal '4', @project.cards.find_by_number(4).cp_id
  end  

  def test_should_import_cards_without_errors_in_properties
    login_as_admin
    setup_date_property_definition 'new dates'
    import_text = <<-CSV
      new dates
      22/2/77
      sdfdsf
      01/2/02
    CSV
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!

    assert_equal 2, @project.cards.size
  end  
  
  def test_should_notify_users_of_errors_in_bad_dates
    login_as_admin
    import_text = <<-CSV
      Title\tNumber\tEnds On
      Card 1\t1\t10 Mar 2004
      Card 2\t2\tfifteen green bottles
    CSV
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path, {'Title' => 'name', 'Number' => 'number', 'Ends On' => 'date property'})
    import.process!
    
    assert_equal 1, @project.cards.size
    assert_equal 1, import.error_count
    assert_equal 1, import.created_count
    assert_equal ["Row 2: Ends On: #{'fifteen green bottles'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property."], import.reload.error_details
  end
  
  def test_should_throw_error_when_invalid_dates_are_imported_into_an_existing_date_property
    start_date = setup_date_property_definition('start date')
    some_date = setup_date_property_definition('some date')
    
    import_text = <<-CSV
      Number\tstart date\tsome date
      1\t12 Aug 2007\tinvalid
      2\tblah\t13 Aug 2008
      3\tnot a date\tinvalid
    CSV
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!
    
    assert_equal 0, @project.cards.size
    assert_equal 3, import.error_count
    assert_equal 0, import.created_count

    errors = import.reload.error_details
    
    row_1_error = "Row 1: some date: #{'invalid'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property."
    assert_match row_1_error, errors.first

    row_2_error = "Row 2: start date: #{'blah'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property."
    assert_match row_2_error, errors[1]

    row_3_first_error = "start date: #{'not a date'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property."
    assert_match(row_3_first_error, errors.last)

    row_3_second_error = "some date: #{'invalid'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property."
    assert_match(row_3_second_error, errors.last)
  end

  #bug 3620
  def test_should_not_be_able_to_create_parenthesised_enum_values
    setup_property_definitions :status =>[]
    @project.reload
    status = @project.find_property_definition('status')
    status.update_attributes(:hidden => true)

    import_text = %{Number\tStatus
      3\t(high)
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!

    assert_equal 0, @project.cards.size
    assert_equal 1, import.error_count

    expected_errors = ["Row 1: Validation failed: status: #{'(high)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."]
    assert_equal expected_errors, import.reload.error_details
  end

  #bug 3627
  def test_should_not_be_able_to_create_parenthesised_values_for_free_text_properties
    setup_text_property_definition 'free text'
    @project.reload
    free_text = @project.find_property_definition('free text')
    free_text.update_attributes(:hidden => true)

    import_text = %{Number\tfree text
      3\t(high)
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!

    assert_equal 0, @project.cards.size
    assert_equal 1, import.error_count

    expected_errors = ["Row 1: Validation failed: free text: #{'(high)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."]
    assert_equal expected_errors, import.reload.error_details
  end

  def test_should_save_checklist_items_for_imported_card
    incomplete_items = %w(incomplete_item1 incomplete_item2)
    completed_items = %w(completed_item1 completed_item2 completed_item3)
    import_text = %{Name\tIncomplete Checklist Items\tCompleted Checklist Items
      card with checklist\t#{incomplete_items.join("\r")}\t#{completed_items.join("\r")}
    }
    write_content(import_text)
    import = create_card_importer!(@project, @raw_excel_content_file_path)
    import.process!
    card = @project.cards.first

    assert_equal 1, @project.cards.count
    assert_equal 5, card.checklist_items.count
    assert card.checklist_items.all? { |checklist_item| !checklist_item.new_record? }
    assert_equal incomplete_items, card.incomplete_checklist_items.collect(&:text)
    assert_equal completed_items, card.completed_checklist_items.collect(&:text)
  end

  def test_should_overwrite_existing_checklists_on_import
    with_new_project do |project|
      login_as_admin
      card = project.cards.create(:name => 'card with checklist', :card_type_name => 'Card')
      incomplete_checklists = ['first incomplete', 'second incomplete']
      completed_checklists = ['first completed']
      card.add_checklist_items({'incomplete checklist items' => incomplete_checklists, 'completed checklist items' => completed_checklists})

      completed_checklists.push('new checklist')
      import_text = %{Number\tName\tIncomplete Checklist Items\tCompleted Checklist Items
        #{card.reload.number}\tcard with checklist\t#{incomplete_checklists.join("\r")}\t#{completed_checklists.join("\r")}
      }

      write_content(import_text)
      import = create_card_importer!(project, @raw_excel_content_file_path)
      import.process!
      imported_card = project.cards.find_by_number(card.number)

      assert_equal 4, imported_card.checklist_items.count
      assert card.checklist_items.all? { |checklist_item| !checklist_item.new_record? }
      assert_equal incomplete_checklists, imported_card.incomplete_checklist_items.collect(&:text)
      assert_equal completed_checklists, imported_card.completed_checklist_items.collect(&:text)
    end
  end

  private

  def write_content(content)
    FileUtils.mkdir_p File.dirname(@full_raw_excel_content_file_path) unless File.exist?(File.dirname(@full_raw_excel_content_file_path))
    File.open(@full_raw_excel_content_file_path, "w") do |file|
      file.write(content)
    end
  end
end
