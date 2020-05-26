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

class MappingsTest < ActiveSupport::TestCase
  
  def setup
    first_project.activate
    login_as_admin
    @excel_content_file = SwapDir::CardImportingPreview.file(first_project)
  end
  
  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_should_understand_heuristics_based_mappings
    mappings = ::CardImport::Mappings.new(['Like A Number', 'Note', 'Group'], reader(%{Like A Number\tNote\tGroup\n} + %{1\tSome Name\tValue}))
    assert_equal 0, mappings.index_of_attribute('number')
    assert_equal 1, mappings.index_of_attribute('name')
  end  
  
  def test_should_understand_column_with_many_words_as_description
    mappings = ::CardImport::Mappings.new(['Like A Number', 'Details', 'Title'], reader(%{
      Like A Number\tDetails\tTitle
      1\tThis is a very interesting case\tCard One
      2\tThis is a rather boring    case\tCard Two
    }))
    assert_equal 0, mappings.index_of_attribute('number')
    assert_equal [1], mappings.index_of_attribute('description')
    assert_equal 2, mappings.index_of_attribute('name')
  end

  def test_should_include_checklist_mappings
    mappings = ::CardImport::Mappings.new(['Tags','Incomplete checklist items','Completed checklist items'], reader(%{Tags\tIncomplete checklist items\tCompleted checklist items\n1erwy6ertu\tabhs\tcajhcjh}))
    assert_equal 0, mappings.index_of_attribute('tags')
    assert_equal 1, mappings.index_of_attribute('incomplete checklist items')
    assert_equal 2, mappings.index_of_attribute('completed checklist items')
  end

  def test_should_map_invalid_property_definition_names_as_description
    mappings = ::CardImport::Mappings.new(['id', 'Notes & Comments', 'Titles = such'], reader(%{
      id\tNotes & Comments\tTitles = such
      1\tThis is a very interesting case\tAnd the old woman in the shoe agrees
      2\tThis is a rather boring    case\tBut no one else thinks so
    }))
    assert_equal [1, 2], mappings.index_of_attribute('description')
  end  
  
  def test_should_understand_that_a_column_with_very_large_numbers_cannot_be_number
    mappings = ::CardImport::Mappings.new(['Big Number', 'Title'], reader(%{
      Big Number\tTitle
      12345678912345\tAnd the old woman in the shoe agrees
      1234567891223312345678912233\tBut no one else thinks so
    }))
    assert_equal nil, mappings.index_of_attribute('number')
    assert_equal nil, mappings.index_of_attribute('name')
    assert_equal [1], mappings.index_of_attribute('description')
  end  
  
  def test_columns_with_explicit_names_take_precedence_over_heuristics
    mappings = ::CardImport::Mappings.new(['Name'], reader(%{
      Name
      10
      11
      12
    }))
    assert_equal nil, mappings.index_of_attribute('number')
    assert_equal 0, mappings.index_of_attribute('name')
  end  
  
  def test_should_understand_overrides_taking_precedence_over_heuristics
    mappings = ::CardImport::Mappings.new(['Like A Number', 'Note', 'Group'], reader(%{
      Like A Number\tNote\tGroup
      1\tSome Name\tValue
    }, 
    'Like A Number' => 'name', 'Note' => 'description', 'Group' => 'description'))
    assert_equal nil, mappings.index_of_attribute('number')
    assert_equal 0, mappings.index_of_attribute('name')
    assert_equal [1,2], mappings.index_of_attribute('description')
  end  
  
  def test_should_create_mappings_for_ignored_columns
    mappings = ::CardImport::Mappings.new(['Like A Number', 'Details', 'Title'], reader(%{
      Like A Number\tDetails\tTitle
      1\tThis is a very interesting case\tCard One
      2\tThis is a rather boring    case\tCard Two
    },
    'Like A Number' => 'number', 'Details' => 'ignore', 'Title' => 'name'))
    assert_equal 0, mappings.index_of_attribute('number')
    assert_equal ::CardImport::Mappings::IGNORE, mappings.sort_by_index[1].import_as
    assert_equal 2, mappings.index_of_attribute('name')
  end  

  def test_unless_the_very_first_column_is_a_numeric_column_heuristics_will_not_infer_it_to_be_number_bug312
    mappings = ::CardImport::Mappings.new(['NotANumber', 'Ticket', 'Note'], reader(%{
      NotANumber\tTicket\tNote
      one\t1\tSomeName}))
    assert_not_equal 1, mappings.index_of_attribute('number')
    assert !mappings.maps?('Ticket' => 'number')
    assert mappings.maps?('Ticket' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)
  end  
  
  def test_multi_word_column_headers_are_properly_mapped_to_attributes
    mappings = ::CardImport::Mappings.new(['Like A Number', 'Note', 'Tag Group'], reader(%{
      Like A Number\tNote\tTag Group
      1\tSome Name\tTag Value}))
    assert mappings.maps?('Tag Group' => CardImport::Mappings::TEXT_LIST_PROPERTY)  
  end  
  
  def test_should_not_attempt_to_import_bad_column_names_as_property_definitions_but_as_definitions_instead
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Property&Like', 'text=like'], reader(%{
      Number\tName\tPropert&Like\ttext=like
      1\tSome Name\tstory\tsome story
      2\tSome Other Name\tbug\tanother bug
    }))
    assert mappings.maps?('Property&Like' => 'description')
    assert mappings.maps?('text=like' => 'description')  
  end
  
  def test_should_generate_property_definitions_for_custom_property_mappings
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Like A Number', 'Note', 'Testing Priority', 'Testing Status'], reader(%{
        Like A Number\tNote\tTesting Priority\tTesting Status
        1\tSome Name\tstory\1
        2\tSome Other Name\tbug\1
      }))
      mappings.create_property_definitions(project)
      assert_equal ['Testing Priority', 'Testing Status'], project.reload.property_definitions.collect(&:name)
    end  
  end
  
  def test_should_map_columns_with_more_than_ten_distinct_values_as_text_property_when_property_exists
    mappings = ::CardImport::Mappings.new(['Title', 'Id', 'Number'], reader(%{
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
    }))
    assert mappings.maps?('Title' => 'name')
    assert mappings.maps?('Id' => CardImport::Mappings::ANY_TEXT_PROPERTY)
    assert mappings.maps?('Number' => 'number')
  end

  def test_should_generate_text_property_definitions
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Title', 'Id', 'Number'], reader(%{
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
      }))
      mappings.create_property_definitions(project)
      
      assert_equal TextPropertyDefinition, project.reload.find_property_definition("Id").class
      assert_equal 1, project.property_definitions.size      
    end
    
  end  
  
  def test_should_not_map_multiple_columns_as_name_even_if_they_look_similar
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Looks like a name'], reader(%{
      Number\tName\tLooks like a name
      1\tSome  Name\tFake Name
      2\tOther Name\tStub Name
    })) 
    assert mappings.maps?('Name' => 'name')
    assert mappings.maps?('Looks like a name' => CardImport::Mappings::TEXT_LIST_PROPERTY)
  end  
  
  def test_should_not_map_dashes_for_either_custom_properties_or_standard_fields
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Status'], reader(%{
      Number\tName\tStatus
      1\tSome  Name\t-
      2\t-\tClosed
    }))
    assert_nil mappings.to_attributes(['1', 'Some Name', '-'])["Status"]
    assert_nil mappings.to_attributes(['2', '-', 'Closed'])["name"]
  end  
  
  def test_should_map_date_like_fields_as_date_property_using_heuristics
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Started On'], reader(%{
      Number\tName\tStarted On
      1\tSome  Name\t12 Aug 2007
      2\t-\t14 Aug 2007
    }))
    assert mappings.maps?('Started On' => 'date property')
  end
  
  def test_should_not_map_numeric_fields_if_bogus_numbers_using_heuristics
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Estimated'], reader(%{
      Number\tName\tEstimated
      1\tSome  Name\t10.2.3
    }))
    assert !mappings.maps?('Estimated' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)
  end
  
  def test_should_map_existing_date_property_as_date
    with_new_project do |project|
      setup_date_property_definition 'Named On'
      mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Named On'], reader(%{
        Number\tName\tNamed On
        1\tSome  Name\t12 Aug 2007
        2\t-\t14 Aug 2007
      }))
      assert mappings.maps?('Named On' => 'date property')
    end  
  end
  
  def test_should_find_numeric_free_properties_for_drop_down_options
    with_new_project do |project|
      setup_numeric_text_property_definition 'Estimated'
      mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Estimated'], reader(%{
        Number\tName\tEstimated
        1\tSome  Name\t12.5
        2\t-\t10
      }))
      estimated_mapping = mappings.sort_by_index[2]
      assert_equal [["(ignore)", "ignore"], ["as existing property", CardImport::Mappings::ANY_NUMERIC_PROPERTY]], estimated_mapping.mapping_options_sorted
      assert_equal CardImport::Mappings::ANY_NUMERIC_PROPERTY, estimated_mapping.import_as
    end
  end
  
  def test_should_find_numeric_list_properties_for_drop_down_options
    with_new_project do |project|
      setup_numeric_property_definition 'Estimated', ['10.2']
      mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Estimated'], reader(%{
        Number\tName\tEstimated
        1\tSome  Name\t12.5
        2\t-\t10
      }))
      estimated_mapping = mappings.sort_by_index[2]
      assert_equal [["(ignore)", "ignore"], ["as existing property", CardImport::Mappings::NUMERIC_LIST_PROPERTY]], estimated_mapping.mapping_options_sorted
      assert_equal CardImport::Mappings::NUMERIC_LIST_PROPERTY, estimated_mapping.import_as
    end
  end
  
  def test_mapping_options_sorted_should_include_numeric_list_property_when_the_property_is_new_and_numeric
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Number', 'Name', 'New estimated'], reader(%{
        Number\tName\tNew estimated
        1\tSome  Name\t12.5
        2\t-\t10
      }))
      estimated_mapping = mappings.sort_by_index[2]
      assert estimated_mapping.mapping_options_sorted.include?(["as new #{CardImport::Mappings::NUMERIC_LIST_PROPERTY}", CardImport::Mappings::NUMERIC_LIST_PROPERTY])
      assert estimated_mapping.mapping_options_sorted.include?(["as new #{CardImport::Mappings::ANY_NUMERIC_PROPERTY}", CardImport::Mappings::ANY_NUMERIC_PROPERTY])
      assert_equal CardImport::Mappings::NUMERIC_LIST_PROPERTY, estimated_mapping.import_as
    end
  end
  
  def test_should_generate_text_property_definitions
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Title', 'Id', 'Number'], reader(%{
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
      }))
      mappings.create_property_definitions(project)
      
      assert_equal TextPropertyDefinition, project.reload.find_property_definition("Id").class
      assert_equal 1, project.property_definitions.size      
    end
    
  end  
  
  def test_should_map_columns_with_more_than_ten_distinct_numeric_values_as_numeric_free_property_when_property_exists
    with_new_project do |project|
      setup_numeric_property_definition 'Id', []
      mappings = ::CardImport::Mappings.new(['Title', 'Id', 'Number'], reader(%{
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
        Card 9\t9\t12
      }))
      assert mappings.maps?('Title' => 'name')
      assert mappings.maps?('Id' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)
      assert mappings.maps?('Number' => 'number')
    end
  end
  
  def test_should_generate_new_numeric_free_property_definitions_when_more_than_ten_distinct_numeric_values
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Title', 'Id', 'Number'], reader(%{
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
        Card 9\t9\t12
        Card 9\t \t12
      }))
      assert mappings.maps?('Id' => CardImport::Mappings::ANY_NUMERIC_PROPERTY)
      
      mappings.create_property_definitions(project)
      id = project.reload.find_property_definition("Id")
      assert_equal TextPropertyDefinition, id.class
      assert id.numeric?
      assert_equal 1, project.property_definitions.size
      
      assert_equal "1", mappings.to_attributes(['Card 1', '1', '1'])['Id']
    end
  end
  
  def test_should_generate_new_free_property_definitions_when_more_than_ten_distinct_values_with_numeric_non_numeric_and_empty_values_present
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Title', 'Id', 'Number'], reader(%{
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
        Card 9\t9\t12
        Card 9\t \t12
        Card 9\ta\t12
      }))
      assert mappings.maps?('Id' => CardImport::Mappings::ANY_TEXT_PROPERTY)
      
      mappings.create_property_definitions(project)
      id = project.reload.find_property_definition("Id")
      assert_equal TextPropertyDefinition, id.class
      assert !id.numeric?
      assert_equal 1, project.property_definitions.size      
    end
  end
    
  def test_should_generate_new_numeric_list_property_definitions
    with_new_project do |project|
      mappings = ::CardImport::Mappings.new(['Title', 'Size', 'Number'], reader(%{
        Title\tSize\tNumber
        Card 1\t1\t1
        Card 2\t2\t2
      }))
      assert mappings.maps?('Size' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)

      mappings.create_property_definitions(project)
      size = project.reload.find_property_definition("size")
      assert_equal EnumeratedPropertyDefinition, size.class
      assert size.numeric?
      assert_equal 1, project.property_definitions.size      
    end
  end  
  
  def test_should_yield_the_mapping_progress_when_block_is_given_for_initialize_without_mapping_overrides
    with_new_project do |project|
      progress = []
      
      ::CardImport::Mappings.new(['Title', 'Size', 'Number'], reader(%{
        Title\tSize\tNumber
        Card 1\t1\t1
      })) do |header_cell, total, size|
        progress << [header_cell, total, size]
      end
      assert_equal [['Title', 3, 0], ['Size', 3, 1], ['Number', 3, 2]], progress
    end
  end
  
  def test_should_not_yield_the_mapping_analysing_progress_when_initialize_with_mapping_overrides
    with_new_project do |project|
      progress = []
      ::CardImport::Mappings.new(['Title', 'Size', 'Number'], reader(%{
        Title\tSize\tNumber
        Card 1\t1\t1
      }, {'Title' => 'Name'})) do |header_cell, total, size|
        progress << header_cell
      end
      assert_equal [], progress
    end
  end
  
  def test_should_map_formula_properties_as_ignored_columns
    with_new_project do |project|
      setup_numeric_property_definition 'size', [1,2,4,8]
      project.create_formula_property_definition!(:name => 'real size', :formula => '3 * size')
      mappings = ::CardImport::Mappings.new(['name', 'size', 'real size'], OpenStruct.new(:current_tree_columns => []))
      
      assert !mappings.to_attributes(['Card 1', '1', '3']).member?('real size')
    end
  end
  
  def test_should_map_empty_columns_to_text_list_property
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Empty', 'NotEmpty'], reader(%{
      Number\tName\tEmpty\tNotEmpty
      1\tName\t\tsomething}))
    assert mappings.maps?('Empty' => CardImport::Mappings::TEXT_LIST_PROPERTY)
  end
  
  def test_should_map_columns_with_empty_values_and_numbers_to_numeric_list_property
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Numero', 'NotEmpty'], reader(%{
      Number\tName\tNumero\tNotEmpty
      1\tName\t  \tsomething
      1\tName\t2.5\tsomething
      1\tName\t\tsomething
    }))
    assert mappings.maps?('Numero' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)
  end
  
  def test_should_do_map_to_text_field_when_numeric_and_non_numeric_and_empty_values_intermixed
    mappings = ::CardImport::Mappings.new(['name', 'type', 'status'], reader(%{
      name\ttype\tstatus
      card name\tstory\topen
      card name\tstory\t5
      card name\tbug\t
     }))
    assert mappings.maps?('status' => CardImport::Mappings::TEXT_LIST_PROPERTY)
  end 
  
  def test_should_map_existing_card_relationship_properties_as_such
    with_card_query_project do |project|
      mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Related Card'], reader(%{
        Number\tName\tRelated Card
        67\tName\t#{project.cards.first.number_and_name}}))
      assert mappings.maps?('Related Card' => CardImport::Mappings::CARD_RELATIONSHIP_PROPERTY)
    end
  end

  def test_should_map_incomplete_checklist_item_as_attributes
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Incomplete Checklist Items'], reader(%{
      Number\tName\tIncomplete Checklist Items
      12\tCard With Checklist\tincomplet_item}))
    assert_equal ['incomplete_item'], mappings.to_attributes([12,'Card With Checklist', 'incomplete_item'])['incomplete checklist items']
  end

  def test_should_map_multiple_incomplete_checklist_items_as_attributes
    incomplete_items = %w(incomplet_item1 incomplete_items2 incomplete_items3)
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Incomplete Checklist Items'], reader(%{
      Number\tName\tIncomplete Checklist Items
      12\tCard With Checklist\t#{incomplete_items.join("\r")}}))
    assert_equal incomplete_items, mappings.to_attributes([12,'Card With Checklist', incomplete_items.join("\r")])['incomplete checklist items']
  end

  def test_should_exclude_empty_checklist_items
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Incomplete Checklist Items'], reader(%{
      Number\tName\tIncomplete Checklist Items
      12\tCard With Checklist\tfoo\r\rbar\r}))
    assert_equal %w(foo bar), mappings.to_attributes([12,'Card With Checklist', "foo\r\rbar\r"])['incomplete checklist items']
  end

  def test_should_map_all_checklist_item_types_as_attributes
    incomplete_items = %w(incomplet_item1 incomplete_items2 incomplete_items3)
    completed_items = %w(completed_item1 completed_items2)
    mappings = ::CardImport::Mappings.new(['Number', 'Name', 'Incomplete Checklist Items', 'Completed Checklist Items'], reader(%{
      Number\tName\tIncomplete Checklist Items\tCompleted Checklist Items
      12\tCard With Checklist\t#{incomplete_items.join("\r")}\t#{completed_items.join("\r")}}))
    mappings_to_attributes = mappings.to_attributes([12, 'Card With Checklist', incomplete_items.join("\r"), completed_items.join("\r")])
    assert_equal incomplete_items, mappings_to_attributes['incomplete checklist items']
    assert_equal completed_items, mappings_to_attributes['completed checklist items']
  end

  def test_should_check_if_mapping_is_for_checklist_items
    mappings = ::CardImport::Mappings.new(['Number','Incomplete Checklist Items','Completed Checklist Items'], reader(%{
      Number\tIncomplete Checklist Items\tCompleted Checklist Items
      12\tfoor\tbar}))

    assert !mappings.get_by_index(0).checklist_items?
    assert mappings.get_by_index(1).checklist_items?
    assert mappings.get_by_index(2).checklist_items?
  end

  def reader(content,  mapping_overrides=nil)
    @excel_content_file.write(content)
    excel_content = CardImport::ExcelContent.new(@excel_content_file.pathname)
    OpenStruct.new(:excel_content => excel_content, :original_mapping_overrides => mapping_overrides, :current_tree_columns => [])
  end
end
