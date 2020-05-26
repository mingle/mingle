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

class HeaderTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
  end
  
  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end
  
  def test_miss_type_warning                
    assert CardImport::Header.new(["name","description"], reader(%{name\tdescription\n} + %{name\tdesc})).missing_type_warning
    assert !CardImport::Header.new(["name", "description", 'type'], reader(%{name\tdescription\ttype\n} + %{name\tdesc\tstory})).missing_type_warning
  end
  
  def test_formula_columns_warning
    with_new_project do |project|
      formula_prop_def = setup_formula_property_definition('formula', '1 + 2')
      assert CardImport::Header.new(["name", "description", "formula"], reader(%{name\tdescription\tformula\n} + %{name\tdesc\t6})).formula_columns_warning
      assert !CardImport::Header.new(["name", "description", "type"], reader(%{name\tdescription\ttype\n} + %{name\tdesc\tstory})).formula_columns_warning
    end
  end
  
  def test_header_knows_if_there_is_number_column_in_import_data 
    header = CardImport::Header.new(["name","description"], reader(%{name\tdescription\n} + %{Updated first card\tUpdated this is the first card.}))
    assert !header.number_column_defined?
    header = CardImport::Header.new(["number","description"], reader(%{number\tdescription\n} + %{1\tUpdated this is the first card.}))
    assert header.number_column_defined?
    header = CardImport::Header.new(["no","description"], reader(%{no\tdescription\n} + %{1\tUpdated this is the first card.}))
    assert header.number_column_defined?
  end
  
  def test_header_knows_column_mappings
    header = CardImport::Header.new(['Number', 'Name', 'Size'], reader(%{Number\tName\tSize\n} + %{1\tSomeName\t45}))
    assert header.maps?('Number' => 'number')
    assert header.maps?('Name' => 'name')
    assert header.maps?('Size' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)
  end  
  
  def test_header_can_build_indices_from_provided_mappings
    header = CardImport::Header.new(['Number', 'Summary', 'Note', 'Size'], reader(%{Number\tSummary\tNote\tSize\n} + %{1\tblahblah\tSomeName\t8}, {"Number" => "number", "Summary" => "description", "Note" => "name", "Size" => CardImport::Mappings::TEXT_LIST_PROPERTY}))
    assert header.maps?('Number' => 'number')
    assert header.maps?('Summary' => 'description')
    assert header.maps?('Note' => 'name')
    assert header.maps?('Size' => CardImport::Mappings::TEXT_LIST_PROPERTY)
  end  
  
  def test_header_can_ignore_mappings
    header = CardImport::Header.new(['Number', 'Summary', 'Note', 'Size'], reader(%{Number\tSummary\tNote\tSize\n} + %{1\tblahblah\tSomeName\t8}, {"Number" => "number", "Summary" => "description", "Note" => "name", "Size" => "ignore"}))
    assert !header.maps?('Size' => CardImport::Mappings::TEXT_LIST_PROPERTY)
    assert !header.maps?('Size' => 'ignore')
  end  
  
  def test_header_can_append_multiple_columns_into_a_single_description_field
    header = CardImport::Header.new(
      ['Number', 'Name', 'As a', 'I want to', 'So that'], 
      reader(%{
        Number\tName\tAs a\tI want to\tSo that
        1\tcard one\tdocumentation user\taccess old records\tI can reproduce old invoices
      }, 
      {"Number" => "number", "Name" => "name", "As a" => "description", "I want to" => "description", "So that" => 'description'}))
    attributes = header.attributes_for(['1', 'card one', 'documentation user', 'access old records', 'I can reproduce old invoices'])
    assert_equal "h3. As a\n\np(. documentation user\n\nh3. I want to\n\np(. access old records\n\nh3. So that\n\np(. I can reproduce old invoices", attributes['description']
    assert attributes['as_a'].nil?
    assert attributes['i_want_to'].nil?
    assert attributes['so_that'].nil?
  end  
  
  def test_unless_the_very_first_column_is_a_numeric_column_heuristics_will_not_infer_it_to_be_number_bug312
    header = CardImport::Header.new(['NotANumber', 'Ticket', 'Note'], reader(%{NotANumber\tTicket\tNote\n} + %{one\t1\tSomeName}))
    assert !header.maps?('Ticket' => 'number')
    assert header.maps?('Ticket' => CardImport::Mappings::NUMERIC_LIST_PROPERTY)
  end  
  
  def test_can_return_all_enumeration_values_for_each_property
    header = CardImport::Header.new(
      ['Number', 'Name', 'Status', 'size', 'Discovered in iteration', 'Release'], reader(%{
        Number\tName\tStatus\tsize\tDiscovered in iteration\tRelease
        1\tname1\tOpen\t8\t10\t1
        2\tname2\tclosed\t4\t11\t2
        3\tname3\topen\t2\t9\t1
        4\tname4\tCLOSED\t1\t8\t1
        5\tname5\tin progress\t16\t4\t1
      }))
      assert_equal ['Discovered in iteration', 'Release', 'Status', 'size'], header.all_enumeration_values_and_card_types.keys.sort
      assert_equal ['Open', 'closed', 'in progress'], header.all_enumeration_values_and_card_types['Status']
      assert_equal ['8', '4', '2', '1', '16'], header.all_enumeration_values_and_card_types['size']
  end
  
  def test_all_enumeration_values_does_not_include_text_properties
    header = CardImport::Header.new(['Title', 'Id', 'Number'], reader(%{
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

    assert_equal({}, header.all_enumeration_values_and_card_types)
  end

  def test_header_knows_if_there_is_checklist_column_in_import_data
    header = CardImport::Header.new(['name', 'description', 'completed checklist items'], reader(%{name\tdescription\tcompleted checklist items\n} + %{card\tcard description.\titem}))
    assert header.checklist_items_defined?
    header = CardImport::Header.new(['number', 'description', 'incomplete checklist items'], reader(%{number\tdescription\tincomplete checklist items\n} + %{1\tcard description.\titem}))
    assert header.checklist_items_defined?
    header = CardImport::Header.new(%w(no description), reader(%{no\tdescription\n} + %{1\tUpdated this is the first card.}))
    assert !header.checklist_items_defined?
  end

  def reader(content,  mapping_overrides=nil)
    @excel_content_file.write(content)
    excel_content = CardImport::ExcelContent.new(@excel_content_file.pathname)
    OpenStruct.new(:project => Project.current, :excel_content => excel_content, :original_mapping_overrides => mapping_overrides, :current_tree_columns => [])
  end
end
