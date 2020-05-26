#encoding: UTF-8

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

class CardSchemaTest < ActiveSupport::TestCase
  def setup
    @project = create_project
    @project.activate
    @card_schema = @project.card_schema
  end

  def test_generate_uniqu_column_name_with_suffix
    assert_equal 'cp_new_property_user_id', @card_schema.unique_column_name_from_name('New Property', 'cp', 'user_id')
    setup_user_definition 'Exist Property'
    assert_equal 'cp_exist_property_1_user_id', @card_schema.unique_column_name_from_name('Exist Property', 'cp', 'user_id')
  end

  def test_should_format_none_english_character_when_generate_uniqu_column_name
    assert_equal 'cp_1', @card_schema.unique_column_name_from_name('状态', 'cp')
    assert_equal 'cp_1', @card_schema.unique_column_name_from_name('tree-迭代', 'cp')
    assert_equal 'cp_card_type', @card_schema.unique_column_name_from_name('card_type', 'cp')
    assert_equal 'cp_card_type', @card_schema.unique_column_name_from_name('card-type', 'cp')
    assert_equal 'cp_card_type', @card_schema.unique_column_name_from_name("card'type", 'cp')
  end

  def test_drop_card_schema_should_clear_all_card_tables
    @card_schema.drop
    assert !Project.connection.table_exists?(Card.table_name)
    assert !Project.connection.table_exists?(Card.versioned_table_name)
  end

  def test_update_names_should_rename_all_card_tables
    login_as_admin
    old_card_table_name, old_version_table_name = Card.table_name, Card.versioned_table_name
    @project.update_attribute(:identifier, 'new_identifier')

    new_card_table_name, new_version_table_name = Card.table_name, Card.versioned_table_name

    assert_not_equal old_card_table_name, new_card_table_name
    assert_not_equal old_version_table_name, new_version_table_name

    assert !Project.connection.table_exists?(old_card_table_name)
    assert !Project.connection.table_exists?(old_version_table_name)

    assert Project.connection.table_exists?(new_card_table_name)
    assert Project.connection.table_exists?(new_version_table_name)
  end

  def test_add_column_to_card
    @card_schema.add_column('apple_test', :string, false)
    assert_card_has_column('apple_test')
  end

  def test_update_schema_should_put_defined_columns_to_card_and_version_table
    @project.create_text_list_definition!(:name => 'story')
    assert @card_schema.column_defined?('cp_story')
    assert_card_has_column('cp_story')
  end

  def test_column_name_should_not_be_sql_key_word
    %w(select id type number).each do |column_name|
      assert_raise CardSchema::ColumnInvalidException do
        @card_schema.add_column(column_name, :string, false)
      end
    end
  end

  def test_column_name_with_question_should_be_invalid
    ['type?', 'cp_number?'].each do |column_name|
      assert_raise CardSchema::ColumnInvalidException do
        @card_schema.add_column(column_name, :string, false)
      end
    end
  end

  def test_remove_column
    @card_schema.add_column('some_new_column', :string, false)
    assert_card_has_column('some_new_column')
    @card_schema.remove_column('some_new_column')
    assert_card_not_has_column('some_new_column')
  end

  def test_telling_not_insync_property_definition_columns
    setup_property_definitions :iteration  => [1, 2, 3], :status => ['open', 'close']
    @card_schema.remove_column('cp_iteration')
    @card_schema.remove_column('cp_status')
    assert_equal ['iteration', 'status'], @card_schema.column_not_insync_properties.collect(&:name)
  end

  def test_rename_column_value
    login_as_member
    setup_property_definitions :status => ['close', 'open']
    card = Card.create!(:project_id => @project.id, :name => 'first_card', :cp_status => 'close', :card_type_name => 'card')
    open_card = Card.create!(:project_id => @project.id, :name => 'open_card', :cp_status => 'open', :card_type_name => 'card')


    @card_schema.rename_column_value('cp_status', 'close', 'closed')
    assert_equal 'closed', card.reload.cp_status
    assert_equal 'closed', card.versions.first.cp_status
    assert_equal 'open', open_card.reload.cp_status
  end

  def test_card_table_name_generation_removes_leading_underscores_for_oracle
    identifier = "__the_project"
    with_new_project(:identifier => identifier) do |project|
      for_postgresql do
        assert_equal "__the_project_cards", CardSchema.generate_cards_table_name(identifier)
        assert_equal "__the_project_card_versions", CardSchema.generate_card_versions_table_name(identifier)
      end

      for_oracle do
        assert_equal "the_project_cards", CardSchema.generate_cards_table_name(identifier)
        assert_equal "the_project_card_versions", CardSchema.generate_card_versions_table_name(identifier)
      end
    end
  end

  def test_should_not_generate_columns_with_same_ruby_name
    with_new_project do |project|
      card_pd_1 = setup_card_property_definition('test', project.card_types.first)
      card_pd_1.update_attributes(:name => 'related tests')
      user_pd = setup_user_definition('test')
      user_pd.update_attributes(:name => 'related user')
      card_pd_2 = setup_card_property_definition('test', project.card_types.first)
      assert_equal ['cp_test', 'cp_test_1', 'cp_test_2'], [card_pd_1, user_pd, card_pd_2].collect(&:ruby_name)
    end
  end
end
