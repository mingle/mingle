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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

class ImportExportUsersTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def test_newly_created_users_from_import_should_not_have_passwords_and_api_key_populated
    @user = login_as_member
    with_new_project do |project|
      timmy = create_user!(:login => 'tunit', :name => 'timmy')
      timmy.update_api_key
      assert timmy.api_key
      project.add_member(@user)
      project.add_member(timmy)
      export_file = create_project_exporter!(project, @user).export
      project.remove_member timmy
      timmy.destroy
      project_import = create_project_importer!(User.current, export_file)
      project_import.process!

      timmy = User.find_by_login('tunit')
      assert_nil timmy.password
      assert_nil timmy.api_key
    end
  end

  def test_import_user_memberships_with_auto_enroll
    @user = login_as_member
    export_file = nil
    with_new_project do |project|
      timmy = create_user!(:login => 'tunit', :name => 'timmy')

      project.add_member(@user)
      project.add_member(timmy)
      export_file = create_project_exporter!(project, @user).export
      project.destroy
    end

    with_new_project(:auto_enroll_user_type => 'full') do |project|
      project_import = create_project_importer!(User.current, export_file)
      project_import.project = project
      project_import.process!

      assert_equal User.count, project.users.size
    end
  end

  def test_should_carry_icon_of_exported_users
    login_as_admin
    @project = create_project
    user = create_user!(:icon => sample_attachment('user_icon.gif'))
    @project.add_member(user)

    export = create_project_exporter!(@project, User.current)
    @export_file = export.export

    User.delete(user.id)
    assert_nil User.find_by_login(user.login)

    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    @project_importer.reload

    imported_user = User.find_by_login(user.login)
    assert_not_nil imported_user
    assert_not_nil imported_user.icon
    assert File.exists?(imported_user.icon)
  end

  # Bug4627
  def test_should_import_user_as_what_it_is_in_the_imported_project_even_though_the_email_is_empty
    @user = login_as_member
    @project = create_project(:users => [@user])

    login = "bug4627".uniquify[0..20]

    new_user = create_user!(:login => login, :email => nil)

    @project.add_member new_user
    export_file = create_project_exporter!(@project, User.current, :template => false).export
    @project.remove_member new_user

    new_user.destroy
    assert User.find_by_login(login).nil?

    imported_project = create_project_importer!(User.current, export_file).process!

    assert User.find_by_login(login)
    assert imported_project.member?(User.find_by_login(login))
  end

  # Bug12839
  def test_should_map_to_an_existing_user_when_email_matches
    @user = login_as_member
    @project = create_project(:users => [@user])

    old_login = "old_user".uniquify[0..20]
    old_user = create_user!(:login => old_login, :email => "same@email.com")

    @project.add_member old_user
    export_file = create_project_exporter!(@project, User.current, :template => false).export
    @project.remove_member old_user

    old_user.destroy
    assert User.find_by_login(old_login).nil?

    new_login = "new_user".uniquify[0..20]
    new_user = create_user!(:login => new_login, :email => "same@email.com")

    imported_project = create_project_importer!(User.current, export_file).process!

    assert User.find_by_login(new_login)
    assert imported_project.member?(User.find_by_login(new_login))
  end

  def test_should_maintain_user_roles_and_memberships_when_doing_full_project_exports
    @user = login_as_member
    with_new_project do |project|
      proj_admin = create_user!(:login => 'party_animal', :email => nil)
      regular_member = create_user!(:login => 'surfer', :email => nil)
      assert_not_equal proj_admin, regular_member

      project.add_member(proj_admin, :project_admin)
      project.add_member(regular_member)
      export = create_project_exporter!(project, User.current).export

      imported_project = create_project_importer!(User.current, export).process!.reload
      assert_equal 2, imported_project.users.size

      assert imported_project.project_admin?(proj_admin)
      assert imported_project.full_member?(regular_member)
    end
  end

  def test_should_resolve_values_for_user_property_definitions_correctly_based_on_login
    @user = login_as_member
    if dev = User.find_by_login('foo01')
      dev.destroy
    end
    if tester = User.find_by_login('bar01')
      tester.destroy
    end
    with_new_project do |project|
      setup_user_definition 'owner'

      user_foo = User.create!(:email => 'foo@foo.com', :login => 'foo01', :name => 'foo', :password => 'foo123.', :password_confirmation => 'foo123.')
      user_bar = User.create!(:email => 'bar@bar.com', :login => 'bar01', :name => 'bar', :password => 'bar123.', :password_confirmation => 'bar123.')
      project.add_member(user_foo)
      project.add_member(user_bar)

      project.cards.create!(:name => 'card one', :number => 42, :card_type_name => project.card_types.first.name, :cp_owner => user_foo)
      project.cards.create!(:name => 'card two', :number => 43, :card_type_name => project.card_types.first.name, :cp_owner => user_bar)

      exported_project = create_project_exporter!(project, User.current, :template => false).export

      #swap the ids of users foo and bar
      highest_id_user_in_db = User.find(:all).collect(&:id).max
      temp_user_id = highest_id_user_in_db + 10;
      old_user_foo_id = user_foo.id
      old_user_bar_id = user_bar.id
      change_user_id(temp_user_id, user_foo.id)
      change_user_id(old_user_foo_id, user_bar.id)
      change_user_id(old_user_bar_id, temp_user_id)

      create_project_importer!(User.current, exported_project).process!.reload.with_active_project do |imported_project|
        assert_equal 'foo01', imported_project.cards.find_by_number(42).cp_owner.login
        assert_equal 'bar01', imported_project.cards.find_by_number(43).cp_owner.login
      end
    end
  end

  # bug 11104
  def test_newly_created_users_from_import_should_be_deleted_if_import_fails
    @user = login_as_admin
    assert_no_difference 'User.count' do
      with_new_project do |project|
        timmy = create_user!(:login => 'tobeadded', :name => 'UserWillBeAdded')
        project.add_member(@user)
        project.add_member(timmy)
        export_file = create_project_exporter!(project, @user).export
        project.remove_member timmy
        timmy.destroy
        project_import = create_project_importer!(User.current, export_file)
        def project_import.import_attachments(*args)
          raise 'Exception!'
        end

        project_import.process!

        assert_nil User.find_by_login(timmy.login)
      end
    end
  end

  def test_delete_user_after_export_the_project_should_still_have_login_access_for_that_user_after_reimport_the_project_back
    member = create_user!
    login_as_admin
    project = with_new_project { |project| project.add_member(member) }
    export_file = create_project_exporter!(project, User.current).export

    project.with_active_project { |project| project.remove_member(member) }
    assert member.destroy
    assert_nil LoginAccess.find_by_user_id(member.id)

    imported_project = create_project_importer!(User.current, export_file).process!
    assert_not_nil User.find_by_login(member.login).login_access
  end

  def test_should_not_emit_salt_as_part_of_exported_mingle_file
    @user = login_as_member
    @project = create_project(:users => [@user])
    @project.with_active_project do |p|
      p.users.each { |m| m.login_access.update_attributes(:login_token => 'junk') }
      assert User.select_by_project_sql['salt'].blank?
    end
  end

  # bug 6073
  def test_import_project_should_know_the_users_have_the_same_name_but_different_login
    @user = login_as_member
    @project = create_project(:users => [@user])
    lixiao = create_user!(:login => 'lixiao', :name => 'lixiao')
    lixiao2 = create_user!(:login => 'lixiao2', :name => 'lixiao')
    @project.add_member(lixiao)
    @project.add_member(lixiao2)
    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    lixiao2.destroy_without_callbacks
    create_project_importer!(User.current, @export_file).process!
    assert User.find_by_login('lixiao2')
  ensure
    destroy_user('lixiao')
    destroy_user('lixiao2')
  end

  # Bug 6600
  def test_importing_project_with_auto_enroll_should_include_users_that_did_not_exist_when_export_was_created
    @user = login_as_member
    new_project = create_project
    new_project.with_active_project do |project|
      project.update_attribute(:auto_enroll_user_type, 'full')
      export_file = create_project_exporter!(project, @user).export

      jimmy = create_user!(:login => 'jimmy', :name => 'jimmy')

      project_import = create_project_importer!(@user, export_file)
      imported_project = project_import.process!
      begin
        assert imported_project.member?(jimmy)
      ensure
        imported_project.update_attribute(:auto_enroll_user_type, nil)
        imported_project.destroy
      end
    end
  ensure
    new_project.update_attribute(:auto_enroll_user_type, nil)
    new_project.destroy
  end

  # bug 6551
  def test_import_project_that_has_brand_new_user_should_be_added_to_all_existing_auto_enroll_projects
    @user = login_as_member
    export_project  = with_new_project do |project|
      @panda = create_user!(:login => 'chu')
      project.add_member @panda
      login(@panda.email)
      create_card!(:name => 'Creating history.')
      project.remove_member @panda
    end
    login_as_member
    export_file = create_project_exporter!(export_project, @panda).export
    destroy_user @panda.login

    auto_enroll_project = with_new_project do |project|
      project.update_attribute(:auto_enroll_user_type, 'full')
    end

    create_project_importer!(User.current, export_file).process!
    auto_enroll_project.reload
    new_panda = User.find_by_login('chu')
    assert new_panda
    assert auto_enroll_project.users.include?(new_panda)
  ensure
    destroy_user 'chu'
    auto_enroll_project.activate
    auto_enroll_project.update_attribute(:auto_enroll_user_type, nil)
    auto_enroll_project.destroy
  end

  def test_system_user_should_be_transfered_if_not_exist
    user = User.create_or_update_system_user(:login => 'sa'.uniquify[0..20], :name => 'System Administrator')

    export_project  = with_new_project do |project|
      User.with_current(user) do
        create_card!(:name => 'Creating history.')
      end
    end
    login_as_member

    export = create_project_exporter!(export_project, User.current)
    @export_file = export.export

    assert_not_nil User.find_by_login(user.login)
    ActiveRecord::Base.connection.execute("DELETE FROM #{User.table_name} WHERE id=#{user.id}")
    assert_nil User.find_by_login(user.login)

    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    @project_importer.reload

    imported_user = User.find_by_login(user.login)
    assert imported_user.system?
    assert_false imported_user.activated?
    assert imported_user.locked_against_delete?
  end


  def test_should_sync_new_user_created_to_profile_server_if_it_configured
    logined_user = login_as_member
    with_new_project do |project|
      timmy = create_user!(:login => 'tunit', :name => 'timmy',
                           :email => 'tunit@tw.com', :password => 'test123!',
                           :password_confirmation => 'test123!')
      project.add_member(timmy)
      export_file = create_project_exporter!(project, logined_user).export
      project.remove_member timmy
      timmy.destroy

      with_profile_server_configured("https://profile.server", 'parsley') do |http_stub|
        project_import = create_project_importer!(User.current, export_file)
        project_import.process!
        assert_equal 1, http_stub.requests.size
        assert_equal :post, http_stub.last_request.http_method
        assert_equal "https://profile.server/organizations/parsley/users/sync.json", http_stub.last_request.url
        post_attrs = JSON.parse(http_stub.last_request.body)["user"]
        assert_equal 'timmy', post_attrs['name']
        assert_equal 'tunit',  post_attrs['login']
        assert_equal 'tunit@tw.com',  post_attrs['email']
        assert_equal nil,  post_attrs['password']
        assert_equal nil,  post_attrs['salt']
      end
    end
  end

  def test_should_rollback_user_change_if_sync_to_profile_server_failed
    logined_user = login_as_member
    with_new_project do |project|
      timmy = create_user!(:login => 'tunit', :name => 'timmy',
                           :email => 'tunit@tw.com', :password => 'test123!',
                           :password_confirmation => 'test123!')
      project.add_member(timmy)
      export_file = create_project_exporter!(project, logined_user).export
      project.remove_member timmy
      timmy.destroy

      with_profile_server_configured("https://profile.server", 'parsley') do |http_stub|
        http_stub.set_error({:post => ProfileServer::NetworkError.new("boom!") })
        project_import = create_project_importer!(User.current, export_file)
        project_import.process!
        assert_equal ['boom!'], project_import.error_details
        assert_nil User.find_by_login("tunit")
      end
    end

  end
end
