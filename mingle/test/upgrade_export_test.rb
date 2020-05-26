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

# Tests that exports are upgraded properly and that migrations don't mess with
# with production data when this happens. This tests recreates the test database
# so needs to run in a completely separate test run from all other tests. Because
# the upgrade process uses all migrations it will test these as well.

$LOAD_PATH.unshift(File.dirname(__FILE__))
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

require 'test_help'
require 'memcache_stub'
require 'mocks/license_decrypt'
silence_warnings { Object.const_set "CACHE", MemcacheStub.new }
silence_warnings { ActionController::Base.cache_store = MemcacheStub.new, {} }
ElasticSearch.disable
Messaging.disable

require File.expand_path(File.dirname(__FILE__) + "/unit/unit_test_data_loader")

raise 'you must have your test_upgrade_export env set up for running upgrading test' unless ActiveRecord::Base.configurations['test_upgrade_export']

silence_warnings {
  RAILS_ENV = ENV["RAILS_ENV"] = "test_upgrade_export"
  Rails.send(:remove_instance_variable, :@_env)
}

# connect_to_upgrade_test_db
ActiveRecord::Base.establish_connection

class UpgradeExportTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false

  def setup
    recreate_upgrade_test_database

    if user = User.find_by_email('mingle@example.com')
      user.destroy_without_callbacks
    end

    User.current = User.create!(:name => 'Mingle Admin', :login => 'mingle',
      :email => 'mingle@example.com', :password => 'mingle1-',
      :password_confirmation => 'mingle1-')
  end

  def test_can_import_projects_with_tables_with_extraneous_columns
    imported_project = test_upgrade('extraneous_columns.mingle')
  end

  def test_upgrade_mingle_1_1
    imported_project = test_upgrade('mingle_1_1_export_project.mingle')

    overview_page = imported_project.pages.find_by_name('Overview Page')
    with_file_existence_assertion(:overview_page_attachment => overview_page.attachments.first.file) do
      assert_equal(['Bug', 'Card'], imported_project.card_types.collect(&:name).sort)
      assert_equal(["bug 3518 rename enum values with parenth", "owner", "status"], imported_project.card_types.find_by_name('Card').property_definitions.collect(&:name).sort)
      assert_equal(["bug 3518 rename enum values with parenth", "bug only date", "owner", "status"], imported_project.card_types.find_by_name('Bug').property_definitions.collect(&:name).sort)
      assert_equal(['card one', 'card two'], imported_project.cards.collect(&:name).sort)
      assert_equal(4, imported_project.cards.find_by_name('card one').version)
      assert_equal(1, imported_project.cards.find_by_name('card two').version)
      assert_equal(4, imported_project.cards.find_by_name('card one').versions.size)
      assert_equal(1, imported_project.cards.find_by_name('card two').versions.size)

      all_enum_values = imported_project.find_all_enumeration_values.values.flatten.collect(&:value)
      assert all_enum_values.include?('|Hello|_1')
      assert all_enum_values.include?('|Hello|_2')
      assert_equal(["bug 3518 rename enum values with parenth", "bug only date", "owner", "status"], imported_project.all_property_definitions.collect(&:name).sort)
      assert_equal(['EnumeratedPropertyDefinition', 'DatePropertyDefinition', 'UserPropertyDefinition', 'EnumeratedPropertyDefinition'], imported_project.all_property_definitions.sort_by(&:name).collect { |pd| pd['type'] })
      assert_equal("card, #, bug", imported_project.card_keywords.to_s)
      assert_equal(10, imported_project.precision)
      assert_equal('Beijing', imported_project.time_zone)
      assert_equal(1, imported_project.users.size)
    end
  end

  def test_upgrade_template_that_need_to_be_upgraded_to_numeric_properties
    imported_project = test_upgrade('import_numeric_property.mingle')
    assert imported_project.find_property_definition('Iteration Added').numeric?
    assert !imported_project.find_property_definition('functional area').numeric?
  end

  def test_upgrade_mingle_2_2_project
    test_upgrade('2_2_exported_project.mingle')
  end

  def test_project_structure_template
    test_upgrade('project_structure_template.mingle')
  end

  #bug #12553
  def test_should_only_run_migrations_that_was_in_the_file_to_import_then_run_rest_migrations_to_upgrade
    test_upgrade('exported_from_331bf1.mingle')
  end

  def test_upgrade_sets_numeric_flag_correctly_for_formulas
    imported_project = test_upgrade('3_0_formula_project.mingle')

    # bug 8765
    date_minus_date = imported_project.find_property_definition('date minus date')
    assert_equal true, date_minus_date['is_numeric']

    # bug 8838
    three_times_mixed_case_numnum = imported_project.find_property_definition('three times mixed case numnum') # this formula property has target pd 'Mixed Case Numnum' but refers to it as 'mixed case numnum' in the actual formula
    assert_equal true, three_times_mixed_case_numnum['is_numeric']
  end

  def test_upgrade_mingle_2_2_template
    test_upgrade('2_2_exported_template.mingle')
  end

  def test_upgrade_project_with_renamed_table_for_project_variable_property_definitions
    test_upgrade('agilista_template.mingle')
  end

  def test_upgrade_should_remove_all_its_temporary_tables
    test_upgrade('version_1_0.mingle')
    assert_equal [], ActiveRecord::Base.connection.tables.select{ |table| table =~ /mi_/ }
  end

  def test_import_into_oracle_from_export_made_with_another_db
    if oracle?
      upgraded_template = test_upgrade('agile_template_not_exported_with_oracle.mingle')
      upgraded_template.with_active_project do

        # test data in column_name column of property_definitions is shortened
        dev_completed_in_iteration = upgraded_template.find_property_definition('Development Completed in Iteration')
        assert (dev_completed_in_iteration.column_name.size <= 30), "Expected #{dev_completed_in_iteration.column_name} to be shorter than 30 characters"
      end
    end
  end

  def test_should_creating_missing_events_with_time_order_for_old_project_export
    project = test_upgrade('2_2_exported_project.mingle')
    assert_equal 124, project.events_without_eager_loading.count
    assert_in_asc_order(project.events.collect(&:created_at))
    project.cards.each do |card|
      assert_in_asc_order(card.versions.sort_by(&:version).collect(&:event).collect(&:id))
    end

    project.pages.each do |page|
      assert_in_asc_order(page.versions.sort_by(&:version).collect(&:event).collect(&:id))
    end

  end

  # bug #10311
  def test_should_include_icons_when_importing_project_that_requires_upgrade
    project = test_upgrade('project_3_2_with_user_icons.mingle')
    user_with_icon = project.users.find_by_login('admin')
    assert File.exists?(user_with_icon.icon)
    assert File.exists?(project.icon)
  end

  # bug #12137
  def test_upgrade_mingle_with_user_and_group
    test_upgrade('project_3_3_with_groups_and_lot_of_users.mingle')
  end

  # bug 11103
  def test_can_import_project_which_results_in_over_1000_users_being_created
    test_upgrade('1001users_project.mingle')
    assert User.count > 1000
  end

  # bug 14405
  def test_redcloth_should_be_true_in_pre_13_2_imported_card_defaults
    imported_project = test_upgrade 'exported_from_331bf1.mingle'
    assert imported_project.card_types.first.card_defaults.redcloth
  end

  # bug 12384
  def test_upgrade_mingle_project_exported_from_a_version_after_changed_projects_table_to_deliverables
    test_upgrade('bug_12384_test_project.mingle')
  end

  # bug 13000
  def test_should_shorten_pd_column_name_while_invalid_mql_in_aggregate_property
    test_upgrade('shorten_pd_column_name_bug.mingle').with_active_project do |project|
      prop = project.find_property_definition('count condition with semi colon')
      assert Card.new.respond_to?(prop.column_name)
    end
  end

  def test_bug14913
    project = test_upgrade('bug_14913.mingle')
    prop = project.property_definitions.first
    assert prop.value(project.cards.first)
  end

  #bug 11089
  def test_should_fix_duplicated_ruby_name_for_property_definitions
    test_upgrade('bug_11089.mingle').with_active_project do |project|
      ruby_names = project.all_property_definitions.collect(&:ruby_name)
      assert_equal ruby_names.size, ruby_names.uniq.size, "#{ruby_names.inspect} is not uniq"
    end
  end

  #bug #12386
  def test_should_import_project_with_identifier_with_leading_underscore_and_cards_table_without_leading_underscore_correctly
    test_upgrade('_underscore_old_from_oracle.mingle').with_active_project do |project|
      assert project
      assert_equal 1, project.cards.count
      assert_equal 1, project.cards.first.versions.count
    end
  end

  #bug #12386
  def test_should_import_project_with_identifier_with_leading_underscore_and_cards_table_with_leading_underscore_correctly
    test_upgrade('underscore_postgres.mingle').with_active_project do |project|
      assert project
      assert_equal 1, project.cards.count
      assert_equal 1, project.cards.first.versions.count
    end
  end

  #bug #11316
  def test_should_not_throw_error_when_loading_a_grid_view_favorite_containing_pure_number_lanes
    test_upgrade('jruby_yaml_bug.mingle').with_active_project do |project|
      assert_equal "0,1,2,3", project.card_list_views.find_by_name('buggy').params[:lanes]
      assert_equal "0,1,2,3", project.user_defined_tab_favorites.collect(&:favorited).detect { |v| v.name == 'buggy' }.params[:lanes]
    end
  end

  def test_should_import_mingle_3_2_data_with_jvyaml_successfully
    test_upgrade('project_3_2_old_yaml_data.mingle')
  end

  def test_bug_minglezy_589
    LicenseDecrypt.reset_license
    u = User.create!(:login => 'xli',
                    :email => 'xli@thoughtworks.com',
                    :name => 'xiao',
                    :password => 'test123!',
                    :password_confirmation => 'test123!')
    test_upgrade('bug_minglezy_589.mingle')
  end

  def test_should_update_cards_redcloth_column_for_project_upgraded_from_13_1_1
    test_upgrade('bug_15281.mingle').with_active_project do |project|
      card = project.cards.first
      assert card.redcloth
      assert card.latest_version_object.redcloth
    end
  end

  private

  def assert_in_asc_order(collection)
    assert_equal collection.sort, collection
  end

  def with_file_existence_assertion(files)
    begin
      files.each { |key, file| assert_file_exists(key, file) }
      yield
    ensure
      files.each { |key, file| FileUtils.rm(file, :force => true) }
    end
  end

  def assert_file_exists(key, file_name)
    begin
      File.open(file_name) {} # block ensures file is closed
    rescue Exception => e
      raise "No such file or directory - #{file_name} - for #{key}"
    end
  end

  def test_upgrade(file_name)
    new_project = UnitTestDataLoader.unique_project_name
    project_importer = UnitTestDataLoader.create_project_importer!(User.current, "#{Rails.root}/test/data/#{file_name}", new_project, new_project)
    project_importer.process!
    assert_equal project_importer.total, project_importer.completed
    assert [], ActiveRecord::Base.connection.tables
    assert_nil User.find_by_login('upgrade')
    assert Project.find_by_identifier(new_project)
    return Project.find_by_identifier(new_project)
  end

  def recreate_upgrade_test_database
    if RUBY_PLATFORM =~ /java/
      connect_to_upgrade_test_db
      recreate_database_by_dropping_all_tables

      ActiveRecord::Base.connection.drop_sequence("card_id_sequence") rescue nil
      ActiveRecord::Base.connection.drop_sequence("card_version_id_sequence") rescue nil
      ActiveRecord::Base.connection.drop_sequence("luau_transaction_counter") rescue nil

      connect_to_upgrade_test_db
      assert [], ActiveRecord::Base.connection.tables  # does recreate_database_by_dropping_all_tables really work ???
    else
      if oracle?
        ActiveRecord::Base.connection.tables.each{ |table| ActiveRecord::Base.connection.drop_table(table) }
        ActiveRecord::Base.connection.drop_sequence("card_id_sequence") rescue nil
        ActiveRecord::Base.connection.drop_sequence("card_version_id_sequence") rescue nil
      else
       ActiveRecord::Base.connection.disconnect!
       drop_cmd = "dropdb -U #{db_config['username']} #{db_config['database']}"
       create_cmd = "createdb -U #{db_config['username']} #{db_config['database']}"
        output = %x[#{drop_cmd}]
        raise "did not drop database: #{output}" unless $? == 0
        system create_cmd
        connect_to_upgrade_test_db
      end

    end
    begin
      ActiveRecord::Migrator.migrate(File.join(Rails.root, 'db', 'migrate'))
      Install::PluginMigrations.new.do_migration
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
    end
  end

  def postgres?
    db_config['adapter'] =~ /postgres/ || db_config['url'] =~ /postgres/
  end

  def oracle?
    db_config['adapter'] =~ /oracle/ || db_config['url'] =~ /oracle/
  end

  def db_name
    return db_config['username'] if oracle?
    db_name = db_config['url'].split('/').last
  end

  def recreate_database_by_dropping_all_tables
    ActiveRecord::Base.connection.tables.each {|table| ActiveRecord::Base.connection.drop_table(table)}
  end

  def db_config
    ActiveRecord::Base.configurations['test_upgrade_export']
  end

  def connect_to_upgrade_test_db
    ActiveRecord::Base.connection.disconnect!
    ActiveRecord::Base.establish_connection
  end

end
