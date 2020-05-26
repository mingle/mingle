# -*- coding: utf-8 -*-

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

class CardReaderTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_admin
    @project = create_project(:users => [User.find_by_login('first')])
    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
    @excel_content = CardImport::ExcelContent.new(@excel_content_file.pathname)
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_should_provide_warning_when_importing_without_type_column
    import = import(%{name
      Card
    }, @project)

    assert_equal "Some cards being imported do not have a card type. If you continue, Mingle will provide the first card type which is  #{'Card'.bold} in current project.", import.warnings
  end

  def test_import_mapping_for_card_type
    import = import(%{type
      Card
    }, @project)

    assert_equal 'type', find_mapping_by_cell(import, 'type').import_as
  end

  def test_available_mappings_for_card_type_when_column_name_is_type
    import = import(%{type
      Card
      Story
    }, @project)

    assert_equal({"(ignore)"=>"ignore", "as card type"=>"type"}, find_mapping_by_cell(import, 'type').mapping_options)
  end

  def test_available_mappings_for_an_existing_date_property
    with_new_project do |project|
      start_date = setup_date_property_definition('start date')
      import = import(%{Number\tstart date
        1\t12 Aug 2007
        2\t13 Aug 2008
      }, project)
      assert_equal({"(ignore)"=>"ignore", "as existing property"=>"date property"}, find_mapping_by_cell(import, 'start date').mapping_options)
      import.each(&:save!)
      assert_equal "12 Aug 2007", project.reload.cards.find_by_number(1).display_value(start_date)
      assert_equal "13 Aug 2008", project.reload.cards.find_by_number(2).display_value(start_date)
    end  
  end

  def test_should_not_allow_multi_type_columns
    content = %{type\tanother_type
      bug\tstory
    }
    write_content(content)
    reader = CardImport::CardReader.new(@project, @excel_content, {'type' => 'type', 'another_type' => 'type'})
    
    assert_raise CardImport::CardImportException do
      reader.validate
    end
  end

  def test_should_handle_content_end_with_tab
    setup_property_definitions 'a b' => ['a', 'b']
    import = %{Number	Name	Description	a b	
      1	card 1	description	a	}
    write_content(import)
    @card_import = CardImport::CardReader.new(@project, @excel_content)
    lines = @card_import.excel_content.cells.collect { |line| line }
    assert_equal 1, lines.length
    assert_equal '1', lines[0][0]
    assert_equal 'card 1', lines[0][1]
    assert_equal 'description', lines[0][2]
    assert_equal 'a', lines[0][3]
  end
  
  #for bug 1422
  def test_should_handle_space_inside_property_name
    setup_property_definitions 'a b' => ['a', 'b']
    import = %{Number	Name	Description	a      b	
      1	card 1	description	a	}
    write_content(import)
    @card_import = CardImport::CardReader.new(@project, @excel_content)
    lines = @card_import.excel_content.cells.collect { |line| line }
    assert_equal 1, lines.length
    assert_equal '1', lines[0][0]
    assert_equal 'card 1', lines[0][1]
    assert_equal 'description', lines[0][2]
    assert_equal 'a', lines[0][3]
  end
  
  def test_should_throw_exception_if_excel_content_is_blank
    assert_raise(CardImport::CardImportException) do
      import(nil)
    end
    assert_raise(CardImport::CardImportException) do
      import('')
    end
    assert_raise(CardImport::CardImportException) do
      import(" \n\t \n")
    end
  end

  def test_should_know_number_of_cards_in_content
    assert_equal 4, simple_import.size
  end

  def test_should_produce_three_new_cards_for_simple_content
    setup_property_definitions :iteration => []
    create_card!(:name => 'This is the original name', :number => 1, :iteration => 'one')
    assert_equal 3, simple_import.select {|card| card.new_record?}.size
  end

  def test_should_produce_one_existing_card_for_simple_content
    setup_property_definitions :iteration => []
    create_card!(:name => 'This is the original name', :number => 1, :iteration => 'one')
    assert_equal 1, simple_import.select {|card| !card.new_record?}.size
  end
  
  def test_should_identify_unknown_column_as_custom_property
    assert_equal 2, complex_import.select {|card| card.cp_old_type == 'story'}.size
    assert_equal 1, complex_import.select {|card| card.cp_old_type == 'bug'}.size
  end
  
  def test_identifies_first_numeric_column_as_card_number
    assert_equal 3, complex_import[0].number
    assert_equal 5, complex_import[1].number
  end

  def test_identifies_first_likely_column_with_text_as_name
    assert_equal 'This should be an updated name', complex_import[0].name
    assert_equal 'Updated first card', complex_import[1].name
    assert_equal 'Music', complex_import[2].name
  end
  
  def test_identifies_first_likely_column_with_text_as_description
    assert_equal 'This is an updated description.', complex_import[0].description
    assert_equal 'Updated this is the first card.', complex_import[1].description
    assert_equal 'Updated this is the second card.', complex_import[2].description
  end
  
  def test_overriding_mapping_with_complex_data
    mappings = {'LikeANumber' => CardImport::Mappings::TEXT_LIST_PROPERTY, 'Junk' => 'name', 'Name' => 'ignore', 'Description' => 'description', 'old_type' => CardImport::Mappings::TEXT_LIST_PROPERTY}
    assert_equal '2', complex_import(mappings)[0].name
    assert_equal '8', complex_import(mappings)[1].name
    assert_equal 'foo', complex_import(mappings)[2].name
  end
  
  def test_providing_overrides_with_array_instead_of_hash_for_complex_data
    mappings = [CardImport::Mappings::TEXT_LIST_PROPERTY, 'name', 'ignore', 'description', CardImport::Mappings::TEXT_LIST_PROPERTY]
    assert_equal '2', complex_import(mappings)[0].name
    assert_equal '8', complex_import(mappings)[1].name
    assert_equal 'foo', complex_import(mappings)[2].name
  end
  
  def test_ignoring_mappings_with_complex_data
    mappings = {'LikeANumber' => 'ignore', 'Junk' => 'name', 'Name' => 'ignore', 'Description' => 'description', 'old_type' => 'ignore'}
  
    assert_equal '2', complex_import(mappings)[0].name
    assert_equal '8', complex_import(mappings)[1].name
    assert_equal 'foo', complex_import(mappings)[2].name
  
    assert_equal '', complex_import(mappings)[0].tag_list
    assert_equal '', complex_import(mappings)[1].tag_list
    assert_equal '', complex_import(mappings)[2].tag_list
  end
  
  def test_can_load_cards_if_number_column_has_prefixed_hashes
    assert_equal 4087, trac_import[0].number
  end
  
  def test_if_non_standard_column_is_recognized_it_should_not_be_considered_again_as_a_tag
    assert !trac_import[0].tagged_with?('ticket-#4087')
  end
  
  def test_should_throw_import_exception_when_import_with_invalid_card_number
    begin
        import(<<-CSV
            Number\tName\tDescription
      dada\tUpdated first card\tUpdated this is the first card.
          CSV
          )
      fail "duplicate card numbers not causing exception"
    rescue CardImport::CardImportException => e
      assert e.message.include?("dada")
    end
  end
  
  def test_should_throw_import_exception_when_import_with_duplicate_card_number
    begin
        import(<<-CSV
            Number\tName\tDescription
      1\tUpdated first card\tUpdated this is the first card.
      4\tUpdated second card\tUpdated this is the second card.
      #1\tNew card\tThis is a new card.
          CSV
          )
      fail "duplicate card numbers not causing exception"
    rescue CardImport::CardImportException => e
      assert e.message.include?("#1")
    end
  end
  
  def test_should_throw_import_exception_when_non_admin_imports_with_new_card_type
    login_as_member
    begin
        import(<<-CSV
            Number\tName\tType
      1\tUpdated first card\tCard
      4\tUpdated second card\tCard
      5\tNew card\tNewType
          CSV
          )
      fail "new card type by non-admin member should cause exception"
    rescue CardImport::CardImportException => e
      assert_equal "Card type #{'NewType'.bold} does not exist.  Please change card types or contact your project administrator to create this card type.", e.message
    end
    
    begin
        import(<<-CSV
            Number\tName\tType
      1\tUpdated first card\tCard
      4\tUpdated second card\tNewType1
      5\tNew card\tNewType2
          CSV
          )
      fail "new card type by non-admin member should cause exception"
    rescue CardImport::CardImportException => e
      assert_equal "Card types #{'NewType1'.bold} and #{'NewType2'.bold} do not exist.  Please change card types or contact your project administrator to create these card types.", e.message
    end
    
    login_as_admin
    begin
        import(<<-CSV
            Number\tName\tType
      1\tUpdated first card\tCard
      4\tUpdated second card\tCard
      5\tNew card\tNewType
          CSV
          )
    rescue CardImport::CardImportException => e
      fail "new card type by admin should not cause exception"
    end
    
    # bug 5003
    @project.add_member(User.find_by_login('proj_admin'), :project_admin)
    login_as_proj_admin
    begin
        import(<<-CSV
            Number\tName\tType
      1\tUpdated first card\tCard
      4\tUpdated second card\tCard
      5\tNew card\tNewType
          CSV
          )
    rescue CardImport::CardImportException => e
      fail "new card type by project admin should not cause exception"
    end
  end 
  
  def test_duplicate_mapping_should_result_in_exception
    mappings = {'LikeANumber' => CardImport::Mappings::TEXT_LIST_PROPERTY, 'Junk' => 'name', 'Name' => 'name', 'Description' => 'description', 'old_type' => CardImport::Mappings::TEXT_LIST_PROPERTY}
    assert_raise CardImport::CardImportException do
      complex_import(mappings)
    end  
  end
   
  def test_import_with_empty_columns_should_not_blow_up_bug344
    assert_equal 'Foo', import(%{Number\tName\t
      1\tFoo\t
    })[0].name
  end  
  
  def test_import_with_quoted_contents_should_not_blow_up_bug338
    assert_equal "This \"should\" be a name", content_with_quotes_and_multiline_values[0].name
    assert_equal "This should\nbe a name too", content_with_quotes_and_multiline_values[1].name
  end  
  
  def test_import_without_description_should_not_cause_description_to_be_same_as_name_bug335
    assert_nil import(%{Name\tfeature\ttags
      testing story\ttesting\tfeature
    })[0].description
  end  
  
  def test_tag_values_should_not_get_lost_during_import_bug334
    assert_equal "iteration", import(%{Name\titeration\ttags
      another task\t4\titeration
    })[0].tag_list
  end  
  
  def test_importing_multiple_columns_with_the_same_values_but_different_headings_should_import_bug333_i
    import = import(%{Number\tName\titeration\tstatus\trelease
      23\temail story\t1\tnew\t1
      24\tspam filter\t2\told\t2
    })
    iteration = @project.find_property_definition('iteration')
    status = @project.find_property_definition('status')
    release = @project.find_property_definition('release')
    
    assert_equal '1', iteration.value(import[0])
    assert_equal 'new', status.value(import[0])
    assert_equal '1', release.value(import[0])
  end  
  
  def test_importing_multiple_columns_with_the_same_values_but_different_headings_should_import_bug333_ii
    import = import(%{Number\tName\titeration\tstatus\trelease
      1\trss feed\t1\tfixed\t1
      2\tadd address\t2\tnew\t2
    })
    iteration = @project.find_property_definition('iteration')
    status = @project.find_property_definition('status')
    release = @project.find_property_definition('release')
    
    assert_equal 1, import[0].number
    assert_equal '1', iteration.value(import[0]) 
    assert_equal 'fixed',status.value(import[0]) 
    assert_equal '1', release.value(import[0])
  end  
  
  def test_importing_multiple_columns_with_the_same_values_but_different_headings_should_import_bug333_iii
    import = import(%{summary\tname\tkind
      story\tnew funct\tstory
    })
    summary = @project.find_property_definition('summary')
    kind = @project.find_property_definition('kind')
    assert_equal 'new funct', import[0].name
    assert_equal 'story', summary.value(import[0])
    assert_equal 'story', kind.value(import[0])
  end  
  
  def test_importing_of_columns_called_id_with_non_integer_values_should_be_accepted_bug331
    import = import(%{id\tname
      0.1\tnew funct
    })
    id = @project.find_property_definition('id')
    assert_equal 'new funct', import[0].name
    assert_equal '0.1', id.value(import[0])
  end  
  
  def test_importing_of_columns_called_version_should_be_accepted_bug329
    import = import(%{id\tname\tversion
      1\tnew funct\t0.1
    })
    assert_equal 1, import[0].number
    assert_equal 'new funct', import[0].name
    assert_equal '0.1', import[0].cp_version
  end  
  
  def test_should_not_allow_hyphens_in_header_bug_325_reversed_in_bug_1426_which_now_allows_hyphens
    card = import(%{id\tname\thyphenated-header
      1\tnew funct\tfixed
    })[0]
    assert_equal 'fixed', card.cp_hyphenated_header
  end
  
  def test_should_convert_property_name_with_square_brackets_to_description
    card = import(%{name\t[fooBar]
      card one\tnew
    })[0]
    assert_equal 'new', card.description
  end
   
  def test_importing_duplicate_headers_should_warning_message_bug332
    content = %{name\tstatus\tdescription\tStatus\ttype
      another story\told\tmore stories\tfixed\tCard
    }
    write_content(content)
    @excel_content.reset
    reader = ::CardImport::CardReader.new(@project, @excel_content, nil).tap do |reader|
      reader.update_schema
    end
    
    assert_equal CardImport::DUPLICATE_HEADER_ERROR, reader.warnings
    
    content = %{name\ttype\tsta      tus\tdescription\tSta tus
      another story\tCard\told\tmore stories\tfixed
    }
    write_content(content)
    @excel_content.reset
    reader = ::CardImport::CardReader.new(@project, @excel_content, nil).tap do |reader|
      reader.update_schema
    end
    
    assert_equal CardImport::DUPLICATE_HEADER_ERROR, reader.warnings
    
    content = %{name\ttype\tstatus\tdescription\tSta   tus
      another story\tCard\told\tmore stories\tfixed
    }
    write_content(content)
    @excel_content.reset
    reader = ::CardImport::CardReader.new(@project, @excel_content, nil).tap do |reader|
      reader.update_schema
    end
    
    assert_equal '', reader.warnings
  end
  
  def test_importing_formula_column_should_show_warning_message
    setup_formula_property_definition('three', '1 + 2')
    setup_formula_property_definition('four', '1 + 3')
    content = %{name\ttype\tthree\tfour
      another story\tCard\t7\t8
    }
    write_content(content)
    reader =  ::CardImport::CardReader.new(@project, @excel_content, nil).tap do |reader|
      reader.update_schema
    end
    
    assert_equal "Cannot set value for formula properties: #{'three'.bold} and #{'four'.bold}", reader.warnings
  end
  
  def test_import_ignores_column_values_that_are_solely_dashes_bug323
    setup_property_definitions :milestone => [1, 2]
    milestone = @project.find_property_definition('milestone')
    assert_equal nil, milestone.value(trac_import[0])
    assert !trac_import[0].tagged_with?('milestone--')
  end  
  
  def test_automatic_inference_of_multiple_columns_as_description_from_heuristics
    import = import(%{LikeANumber\tJunk\tName\tAs a\tI want to\tSo that
      3\t2\tThis should be an updated name\tSenior regional sales manager\tsee my sales history\tI know if I am meeting my targets
      5\t8\tUpdated first card\tsenior sales manager\tsee all my sales managers history\tto know who should be getting raises
    })
    assert_equal "h3. As a\n\np(. Senior regional sales manager\n\nh3. I want to\n\np(. see my sales history\n\nh3. So that\n\np(. I know if I am meeting my targets", import[0].description
  end  
   
  def test_warn_users_about_generated_card_names_if_no_column_is_marked_name
    import = import(%{LikeANumber\tName\tSummary\ttype
      3\t\tMake me happy\tCard
      5\t\tMake me happier still\tCard
    })
    assert_equal "Some cards being imported do not have a card name. If you continue, Mingle will provide a generic card name.", import.warnings
  end  
  
  def test_error_out_if_user_chooses_a_column_with_very_large_numbers_as_card_number
    begin
      import = import(%{Number\tName
        8327423944484783274239444847\tNew card
      })
      fail('Should not be able to import a column with a huge number as card number')
    rescue CardImport::CardImportException => e
      assert_equal '8327423944484783274239444847 is too large to be used as a card number.', e.message
    end  
  end  
  
  def test_can_import_pre_existing_custom_properties_with_spaces_in_name
    setup_property_definitions :'Assigned to' => ['Jon']
    assigned_to = @project.find_property_definition('Assigned to')
    content = %{Number\tName\tAssigned To
      3\tfoo\tBadri
      5\tbar\tJon
    }
    write_content(content)
    import = CardImport::CardReader.new(@project, @excel_content)
    import.update_schema
    import.each(&:save!)
    assert_equal 'Jon', assigned_to.value(@project.cards.find_by_number(5))
    assert_equal 'Badri', assigned_to.value(@project.cards.find_by_number(3))
  end
   
  def test_fields_exceed_limit_error_message
    message_prefix = "Cards were not imported. All fields other than #{'Card Description'.bold} are limited to 255 characters. "
    
    single_field = {1 => ['group']}
    error = CardImport.fields_exceed_limit(single_field)
    assert_equal "The following field is too long: Row 1 (#{'group'.bold})", error.message[message_prefix.length..-1]
    
    multiple_fields_single_row = {1 => ['group', 'name']}
    error = CardImport.fields_exceed_limit(multiple_fields_single_row)
    assert_equal "The following fields are too long: Row 1 (#{'group'.bold} and #{'name'.bold})", error.message[message_prefix.length..-1]
    
    multiple_fields_multiple_rows = {1 => ['group', 'name'], 12 => ['iteration']}
    error = CardImport.fields_exceed_limit(multiple_fields_multiple_rows)
    assert_equal "The following fields are too long: Row 1 (#{'group'.bold} and #{'name'.bold}), Row 12 (#{'iteration'.bold})", error.message[message_prefix.length..-1]     
  end
  
  def test_import_fails_with_fields_exceeding_limit
    too_long = "a" * 512
    begin
      import = import(%{Number\tName\tDescription\tGroup
        3\t#{too_long}\ta description\t#{too_long}
        7\t"This should\nbe a name too"\tUpdated this is the second card.\t#{too_long}
      })
      fail "should have thrown exception due to fields being too long"
    rescue CardImport::CardImportException => e
      assert e.message.index("Row 1 (#{'Name'.bold})")
    end  
  end
   
  def test_should_not_destroy_properties_that_are_not_available_when_updating_cards_through_import
    setup_property_definitions :status =>['open', 'fixed'], :old_type => ['card', 'bug']
    card3 = create_card!(:number => 3, :name => 'old card 3', :description => 'old card 3 description', :status => 'open', :old_type => 'card')
    card5 = create_card!(:number => 5, :name => 'old card 5', :description => 'old card 5 description', :status => 'fixed', :old_type => 'bug')
    import(%{Number\tStatus\tpriority
      3\tclosed\thigh
      7\tnew\tlow
    }, @project).each(&:save!)
    assert_equal 3, @project.reload.cards.size
    assert_equal 'old card 3', card3.reload.name
    assert_equal 'old card 3 description', card3.description
    assert_equal 'closed', card3.cp_status
    assert_equal 'high', card3.cp_priority

    assert_equal 'old card 5', card5.reload.name
    assert_equal 'old card 5 description', card5.description
    assert_equal 'fixed', card5.cp_status
    assert_nil card5.cp_priority

    card7 = @project.cards.find_by_number(7)
    assert_equal 'Card 7', card7.name
    assert_nil card7.description
    assert_equal 'low', card7.cp_priority
    assert_equal 'new', card7.cp_status
  end
   
  def test_should_destroy_properties_that_are_available_but_not_set_when_updating_cards_through_import
    setup_property_definitions :status =>['open', 'fixed'], :old_type => ['card', 'bug']
    card3 = create_card!(:number => 3, :name => 'old card 3', :description => 'old card 3 description', :status => 'open', :old_type => 'card')
    card5 = create_card!(:number => 5, :name => 'old card 5', :description => 'old card 5 description', :status => 'fixed', :old_type => 'bug')
    import(%{Number\tStatus\tpriority
      3\t\thigh
      7\t\tlow
    }, @project).each(&:save!)
    assert_equal 3, @project.reload.cards.size
    assert_equal 'old card 3', card3.reload.name
    assert_equal 'old card 3 description', card3.description
    assert card3.cp_status.blank?
    assert_equal 'high', card3.cp_priority

    assert_equal 'old card 5', card5.reload.name
    assert_equal 'old card 5 description', card5.description
    assert_equal 'fixed', card5.cp_status
    assert_nil card5.cp_priority

    card7 = @project.cards.find_by_number(7)
    assert_equal 'Card 7', card7.name
    assert_nil card7.description
    assert card7.cp_status.blank?
    assert_equal 'low', card7.cp_priority
  end  
  
  def test_importing_columns_with_multiple_spaces_and_weird_data_works_fine
    import(%{Number\tName\tAnalysis   Done   In Iteration\tstory   status\tqu'oted
      1\tGabriel\t1\tIn   Progress\tcom,ma
      2\tUriel\t2\tin progress\t"qval2"
      3\tMichael\t2\tuh   ?\t'qval3'
      4\tAnael\t3\tUH ?    \tcamelCaseVariant1
      5\tRaphael\t3\tU,H\tCamelCasevariant1
      6\tSamael\t3\tu,h\tquoted'val
    }, @project).each(&:save!)
    assert @project.property_definitions.collect(&:name).contains_all?(['Analysis Done In Iteration', 'story status', "qu'oted"])
    assert_equal ['1', '2', '3'], @project.find_property_definition('Analysis Done In Iteration').enumeration_values.collect(&:value).smart_sort
    assert_equal ['In Progress', 'U,H', 'uh ?'], @project.find_property_definition('story status').enumeration_values.collect(&:value).smart_sort
    assert_equal ["'qval3'", "camelCaseVariant1", "com,ma", "quoted'val", "qval2"], @project.find_property_definition("qu'oted").enumeration_values.collect(&:value).smart_sort
  end  
  
  def test_mappings_options_for_different_property_types
    setup_user_definition 'developer'
    setup_text_property_definition 'Id'
    import = import(%{Number\tName\tStatus\tDeveloper\tId
      1\tCard 1\topen\tadmin@email.com\tFoo
      2\tCard 2\tclosed\tbob@email.com\tBar
    }, @project)
    
    status_mapping = find_mapping_by_cell(import, 'Status')
    assert status_mapping.mapping_options.values.include?(CardImport::Mappings::TEXT_LIST_PROPERTY)
    assert !status_mapping.mapping_options.values.include?(CardImport::Mappings::USER_PROPERTY)
    assert status_mapping.mapping_options.values.include?(CardImport::Mappings::ANY_TEXT_PROPERTY)
    
    id_mapping = find_mapping_by_cell(import, 'Id')
    assert id_mapping.mapping_options.values.include?(CardImport::Mappings::ANY_TEXT_PROPERTY)
    assert !id_mapping.mapping_options.values.include?(CardImport::Mappings::USER_PROPERTY)
    assert !id_mapping.mapping_options.values.include?(CardImport::Mappings::TEXT_LIST_PROPERTY)
  
    developer_mapping = find_mapping_by_cell(import, 'Developer')
    assert_equal [CardImport::Mappings::IGNORE, CardImport::Mappings::USER_PROPERTY].sort, developer_mapping.mapping_options.values.sort
  
    assert_equal CardImport::Mappings::TEXT_LIST_PROPERTY, status_mapping.import_as
    assert_equal CardImport::Mappings::USER_PROPERTY, developer_mapping.import_as
    assert_equal CardImport::Mappings::ANY_TEXT_PROPERTY, id_mapping.import_as
  end  

  def test_default_selected_values_for_enumerated_and_user_properties_when_properties_do_not_exist
    import = import(%{Number\tName\tStatus\tDeveloper
      1\tCard 1\topen\tadmin@email.com
      2\tCard 2\tclosed\tbob@email.com
    }, @project)
    status_mapping = find_mapping_by_cell(import, 'Status')
    assert !status_mapping.mapping_options.values.include?(CardImport::Mappings::USER_PROPERTY)
    assert_equal CardImport::Mappings::TEXT_LIST_PROPERTY, status_mapping.import_as
    
    developer_mapping = find_mapping_by_cell(import, 'Developer')
    assert !developer_mapping.mapping_options.values.include?(CardImport::Mappings::USER_PROPERTY)
    assert_equal CardImport::Mappings::TEXT_LIST_PROPERTY, developer_mapping.import_as
  end  
  
  #bug 1431
  def test_should_not_create_empty_enum_values
    setup_property_definitions :status =>['open', 'fixed'], :old_type => ['card', 'bug']
    import(%{Number\tStatus\tpriority
      3\t\thigh
      7\t\tlow
    }, @project).each(&:save!)
    assert !@project.find_property_definition('status').enumeration_values.collect(&:value).any?(&:blank?)
  end  
  
  def test_can_import_user_logins_in_columns_for_user_propeperties
    setup_user_definition 'dev'
    import(%{Number\tName\tStatus\tdev
      37\tCard 1\topen\t#{@project.users.first.login}
      43\tCard 2\tclosed\t#{@project.users.last.login}
    }).each(&:save!)
    dev = @project.find_property_definition('dev')
    assert_equal @project.users.first, dev.value(@project.cards.find_by_number(37))
    assert_equal @project.users.last, dev.value(@project.cards.find_by_number(43))
  end
  
  def test_ensure_property_definition_and_value_should_not_add_new_value_for_locked_property_when_the_user_is_project_member
    login_as_member
    setup_property_definitions :status =>['open']
    status = @project.find_property_definition('status')
    status.update_attribute(:restricted, true)
    assert_raise(ActiveRecord::RecordInvalid){
     import = import(%{Number\tName\tStatus
        37\tCard 1\tclosed},@project).each(&:save!)
    }
    assert_equal 1, status.enumeration_values.size
  end
  
  def test_import_tab_separated_cards_without_number
    import(<<-CSV, @project).each(&:save!)
      Name\tDescription
      First card\tThis is the first card.
      Second card\tThis is the second card.
    CSV
    cards = @project.cards.all(:order => :id)
    assert_equal 2, cards.count
    assert_equal 'First card', cards[0].name
    assert_equal 'This is the first card.', cards[0].description      
    assert_equal 'Second card', cards[1].name
    assert_equal 'This is the second card.', cards[1].description
  end
  
  def test_import_tab_separated_cards_with_empty_cells
    import(<<-CSV, @project).each(&:save!)
      Name\tDescription\tRelease
      First card\tThis is the first card.\t
      Second card\tThis is the second card.\t1
    CSV
    assert_equal 2, @project.cards.count
    assert_equal 'Second card', @project.cards[0].name
    assert_equal 'This is the second card.', @project.cards[0].description      
    assert_equal 'First card', @project.cards[1].name
    assert_equal 'This is the first card.', @project.cards[1].description
  end
  
  def test_can_import_tags
    import(<<-CSV, @project).each(&:save!)
      Number\tName\tTags
      1\tName\trss, luke
      5\tName\tfoobar, rss
    CSV
    assert_equal 'luke rss', @project.cards.find_by_number(1).tag_list
    assert_equal 'foobar rss', @project.cards.find_by_number(5).tag_list
  end
  
  def test_import_tab_separated_cards_updating_when_numbers_are_present
    create_card!(:number => 1, :name => 'New card')
    create_card!(:number => 2, :name => 'New card')
    create_card!(:number => 3, :name => 'New card')
    create_card!(:number => 4, :name => 'New card')
    
    import(<<-CSV, @project).each(&:save!)
        Number\tName\tDescription
  1\tUpdated first card\tUpdated this is the first card.
  4\tUpdated second card\tUpdated this is the second card.
  7\tNew card\tThis is a new card.
      CSV

    cards = @project.cards.all(:order => 'id desc')
    assert_equal 5, cards.size

    assert_equal 'Updated first card', cards[4].name
    assert_equal 'Updated this is the first card.', cards[4].description
    
    assert_equal 'Updated second card', cards[1].name
    assert_equal 'Updated this is the second card.', cards[1].description       
  
    assert_equal 'New card', cards[0].name
    assert_equal 'This is a new card.', cards[0].description  
     
  end
  
  def test_unknown_column_values_become_custom_properties
    create_card!(:name => 'Old name', :number=>3, :description=>'old description')
    import(<<-CSV, @project).each(&:save!)
      LikeANumber\tJunk\tName\tDescription\tTags\told_type
      3\t2\tThis should be an updated name\tThis is an updated description.\titeration-1\tstory
      5\t8\tUpdated first card\tUpdated this is the first card.\titeration-2\tbug
      7\tfoo\tMusic\tUpdated this is the second card.\titeration-3\tstory
    CSV
    assert_equal 'story', @project.cards.find_by_number(3).cp_old_type
    assert_equal '2', @project.cards.find_by_number(3).cp_junk
    assert_equal 'This is an updated description.', @project.cards.find_by_number(3).description
  end
  
  def test_should_not_wipe_out_description_when_updating_a_card_if_description_from_excel_is_empty_bug1654
    card = create_card!(:name => 'Old name', :number=>3, :description=>'old description')
    import(<<-CSV, @project).each(&:save!)
      Numbert\tName\tDescription\told_type
      3\tNew name\t\tbug
    CSV
    assert_equal 'New name', card.reload.name
    assert_equal 'bug', card.cp_old_type
    assert_equal 'old description', card.description
  end
  
  def test_should_not_wipe_out_tags_when_updating_a_card_if_there_is_no_tag_column_bug1652
    card = create_card!(:name => 'Old name', :number=>7, :description=>'old description')
    card.tag_with('rss, wiki').save!
    import(<<-CSV, @project).each(&:save!)
      Numbert\tName\tDescription\told_type
      7\tNew name\t\tbug
    CSV
    assert_equal ['rss', 'wiki'], card.reload.tags.collect(&:name)
  end
  
  def test_should_wipe_out_tags_when_updating_a_card_if_there_is_a_empty_tag_coulumn
    card = create_card!(:name => 'Old name', :number=>7, :description=>'old description')
    card.tag_with('rss, wiki').save!
    import(<<-CSV, @project).each(&:save!)
      Numbert\tName\tDescription\tTags
      7\tNew name\t\t
    CSV
    assert_equal [], card.reload.tags.collect(&:name)
  end
  
  def test_should_assign_numbers_to_cards_when_importing_if_the_number_column_is_partially_empty_bug_1697
    import(<<-CSV, @project).each(&:save!)
      number\tname\tstatus
      1\tupdate email\topen
      \tnew stuff\tnew
      2\tmore and more
    CSV
    assert_equal 'new stuff', @project.cards.find_by_number(3).name
  end
  
  def test_should_import_free_text_properties
    import(<<-CSV, @project).each(&:save!)
      Title\tId\tNumber
      Card 1\tOne\t1
      Card 2\tTwo\t2
      Card 3\tThree\t3
      Card 4\tFour\t4
      Card 5\tFive\t5
      Card 6\tSix\t6
      Card 7\tSeven\t7
      Card 8\tEight\t8
      Card 9\tNine\t9
      Card 9\tTen\t10
      Card 9\tEleven\t11
      Card 9\tNine\t12
    CSV
    assert_equal 'Four', @project.cards.find_by_number(4).cp_id
  end  
  
  def test_should_import_free_numeric_properties
    import(<<-CSV, @project).each(&:save!)
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
    assert_equal TextPropertyDefinition, @project.find_property_definition('Id').class
    assert @project.find_property_definition('Id').numeric?
    assert_equal '4', @project.cards.find_by_number(4).cp_id
  end  
  
  def test_should_import_date_properties
    import(<<-CSV, @project).each(&:save!)
      Title\tNumber\tEnds On
      Card 1\t1\t10 Mar 2004
      Card 2\t2\t10-05-2004
    CSV
    ends_on = @project.find_property_definition('ends on')
    assert_equal '10 Mar 2004', @project.cards.find_by_number(1).display_value(ends_on)
    assert_equal '10 May 2004', @project.cards.find_by_number(2).display_value(ends_on)
  end  
  
  # bug 11530
  def test_column_containing_more_than_ten_unique_dates_should_import_as_a_new_date_property
    with_new_project do |project|
      import(<<-CSV, project).each(&:save!)
      Type	Put in Dev Queue On
      Story	1-Jan-08
      Story	2-Jan-08
      Story	3-Jan-08
      Story	4-Jan-08
      Story	5-Jan-08
      Story	6-Jan-08
      Story	7-Jan-08
      Story	8-Jan-08
      Story	9-Jan-08
      Story	10-Jan-08
      Story	11-Jan-08
    CSV
    assert_equal DatePropertyDefinition, project.all_property_definitions.find_by_name('Put in Dev Queue On').class
    end
  end
  
  
  def test_can_set_hidden_property
     setup_property_definitions(:iteration => [], :status => [])
     iteration = @project.find_property_definition('Iteration')
     iteration.update_attribute(:hidden, true)
     @project.reload
     status = @project.find_property_definition('status')
     
     import = import(%{Number\tName\titeration\tstatus
        23\temail story\t1\tnew
        24\tspam filter\t2\told
      })     

     assert_equal '1', iteration.value(import[0])
     assert_equal 'new', status.value(import[0])
  end
  
  def test_should_not_strip_out_leading_spaces_in_description
    description_with_leading_spaces = %{foo foo foo
    bar bar bar
    baz baz baz}
    @project.cards.create!(:name => 'One', :description => description_with_leading_spaces,:card_type_name => 'Card')
    export_content = @project.export_csv_cards(CardListView.construct_from_params(@project, {:style => 'list'}), true, false)
    assert_match description_with_leading_spaces, export_content
  end
  
  def test_aviable_trees_should_contain_any_tree_that_has_tree_columns_completed_in_header
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      reader = import <<-DATA, project
        Number\tName\tDescription\tType\tfeature\tPlanning\tPlanning release\tPlanning iteration
        1560\tadd\t\tstory\t\tyes\t\t
      DATA
      assert_equal [configuration], reader.available_trees
      reader = import <<-DATA, project
        Number\tName\tDescription\tType\tfeature\tPlanning
        1560\tadd\t\tstory\t\tyes
      DATA
      assert_equal [], reader.available_trees
    end
  end
  
  def test_tree_columns_should_be_ignored_initially
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      reader = import <<-DATA, project
        Number\tName\tDescription\tType\tfeature\tPlanning\tPlanning release\tPlanning iteration
        1560\tadd\t\tstory\t\tyes\t\t
      DATA
      
      assert_equal(ignore, reader.mapping_overrides['Planning'])
      assert_equal(ignore, reader.mapping_overrides['Planning release'])
      assert_equal(ignore, reader.mapping_overrides['Planning iteration'])
    end
  end
  
  def test_override_tree_columns_with_ignore
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      overrides = {'Planning' => ignore, 'Planning release' => ignore, 'Planning iteration' => ignore }
      reader = import <<-DATA, project, overrides
        Number\tName\tDescription\tType\tfeature\tPlanning\tPlanning release\tPlanning iteration
        1560\tadd\t\tstory\t\tyes\t\t
      DATA
      assert_equal(ignore, reader.mapping_overrides['Planning'])
      assert_equal(ignore, reader.mapping_overrides['Planning release'])
      assert_equal(ignore, reader.mapping_overrides['Planning iteration'])
      
      assert_equal(ignore, reader.headers.mappings['Planning'])
      assert_equal(ignore, reader.headers.mappings['Planning release'])
      assert_equal(ignore, reader.headers.mappings['Planning iteration'])
    end
  end
  
  
  def test_current_tree_column_group
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      overrides = {'Planning' => ignore, 'Planning release' => ignore, 'Planning iteration' => ignore }
      reader = import <<-DATA, project, overrides, configuration
        Number\tName\tDescription\tType\tfeature\tPlanning\tPlanning release\tPlanning iteration
        1560\tadd\t\tstory\t\tyes\t\t
      DATA
      assert_equal('Planning', reader.current_column_group.tree_config.name)
      assert_equal(['Planning', 'Planning release', 'Planning iteration'], reader.current_column_group.columns.collect(&:name))
      assert_equal([5, 6, 7], reader.current_column_group.indexes)
    end
  end
  
  def test_should_be_able_to_tell_which_column_is_incompleted_tree_column
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      reader = import <<-DATA, project
        Number\tName\tDescription\tType\tfeature\tPlanning release\tPlanning iteration
        1560\tadd\t\tstory\t\tyes\t\t
      DATA
      assert !reader.incompleted_tree_column?(0)
      assert !reader.incompleted_tree_column?(4)
      assert reader.incompleted_tree_column?(5)
      assert reader.incompleted_tree_column?(6)
    end    
  end
  
  def test_available_mappings_for_an_existing_card_relationship_property
    with_new_project do |project|
      related_card = setup_card_relationship_property_definition('related card')
      existing_card = create_card!(:name => 'existing card', :number => 1)
      
      import = import(%{Number\trelated card
        2\t#{existing_card.number_and_name}
      }, project)
      assert_equal({"(ignore)"=>"ignore", "as existing property"=>::CardImport::Mappings::CARD_RELATIONSHIP_PROPERTY}, find_mapping_by_cell(import, 'related card').mapping_options)
    end  
  end
  
  def test_values_imported_for_an_existing_card_relationship_property
    with_new_project do |project|
      related_card = setup_card_relationship_property_definition('related card')
      existing_card1 = create_card!(:name => 'existing card', :number => 1)
      existing_card2 = create_card!(:name => 'existing card', :number => 2)
      
      import(%{Number\trelated card
        3\t#{existing_card1.number_and_name}
        4\t#{existing_card2.number_and_name}
      }, project).each(&:save!)
      
      assert_equal existing_card1.number_and_name, project.reload.cards.find_by_number(3).display_value(related_card)
      assert_equal existing_card2.number_and_name, project.reload.cards.find_by_number(4).display_value(related_card)
    end  
  end

  def test_should_import_checklist_items
    expected_incomplete_items = %w(foo1 foo2)
    expected_completed_items = %w(foo3)
    card_with_checklist = checklist_import(expected_incomplete_items, expected_completed_items)[0]
    assert_equal 3, card_with_checklist.checklist_items.size
    assert_equal expected_incomplete_items, card_with_checklist.incomplete_checklist_items.map(&:text)
    assert_equal expected_completed_items, card_with_checklist.completed_checklist_items.map(&:text)
  end

  def test_should_import_checklist_items
    begin
      checklist_import('item'*65,'')[0]
    rescue CardImport::CardImportException => e
      expected_exception_message = "Cards were not imported. All fields other than #{'Card Description'.bold} are limited to 255 characters. The following field is too long: Row 0 (#{'incomplete checklist items'.bold.to_sentence})"
      assert_equal  expected_exception_message, e.message
    end
  end

  def ignore
    CardImport::Mappings::IGNORE
  end
  
  def import(string, project=@project, overrides=nil, tree_conifg=nil)
    write_content(string)
    @excel_content.reset
    ::CardImport::CardReader.new(project, @excel_content, overrides, User.current, tree_conifg).tap do |reader|
      reader.validate
      reader.update_schema
    end
  end  
  
  def write_content(content)
    @excel_content_file.write(content)
  end
  
  def simple_import
    import(%{Number\tName\tDescription\tTags
      1\tThis should be an updated name\tThis is an updated description.\trelease-one
      2\tUpdated first card\tUpdated this is the first card.\trelease-one
      3\tUpdated second card\tUpdated this is the second card.\trelease-two
      4\tNew card\tThis is a new card.\trelease-two})
  end

  def checklist_import(incomplete_items, completed_items)
    import(%{Number\tName\tDescription\tTags\tIncomplete Checklist Items\tCompleted Checklist Items
      1\tThis card contains checklist\tChecklist description\tchecklist\t#{incomplete_items}\t#{completed_items}})
  end

  def complex_import(overrides = nil)
    import(%{LikeANumber\tJunk\tName\tDescription\told_type
      3\t2\tThis should be an updated name\tThis is an updated description.\tstory
      5\t8\tUpdated first card\tUpdated this is the first card.\tbug
      7\tfoo\tMusic\tUpdated this is the second card.\tstory
    }, @project, overrides)
  end
  
  def content_with_quotes_and_multiline_values
    import(%{Number\tName\tDescription
      3\tThis "should" be a name\tThis is an updated description.
      7\t"This should\nbe a name too"\tUpdated this is the second card.
    })
  end  
  
  def trac_import
    import(%{Ticket \t Summary \tComponent \tVersion \tMilestone \told_type \tSeverity \tOwner \tCreated
      #4087\tUnable to attach SilverCity-0.9.5.win32-py2.4.exe to Wiki site\tspamfilter\t0.10\t-\tdefect\tmajor\tmgood\t11/06/2006
      #4086\tlogging in out in w/ ldap\tgeneral\t0.10\t-\tdefect\tblocker\tjonas\t11/06/2006
      #3958\tthispage = hdf.getValue(‘wiki.page_name’, ’’)\twiki\tdevel\t0.11\tdefect\tnormal\tcboos *\t10/18/2006
      #3957\tunhandled exception – socket\tgeneral\tdevel\t0.11\tdefect\tnormal\tjonas\t10/18/2006})
  end
  
  def find_mapping_by_cell(import, header_cell)
    import.headers.mappings.sort_by_index.find{|mapping| mapping.original == header_cell}
  end
end
