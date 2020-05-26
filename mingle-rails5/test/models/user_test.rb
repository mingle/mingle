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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Tags: user, favorites
class UserTest < ActiveSupport::TestCase
  def setup
    @admin = create(:admin)
    create(:user, login: :member)
    Authenticator.password_format = :strict
    #view_helper.default_url_options = { :host => 'example.com' }
  end

  def teardown
   # cleanup_repository_drivers_on_failure
    reset_license
    super
  end

  def test_should_not_be_able_to_create_current_user
    user = build(:user, name: PropertyType::UserType::CURRENT_USER, login: 'very_new')
    user.save
    assert_equal "Name cannot be set to #{'(current user)'}", user.errors.full_messages.join
  end

  def test_auth
    assert_equal  create(:user, login: :second_bob), User.authenticate('second_bob', MINGLE_TEST_DEFAULT_PASSWORD)
    assert_nil    User.authenticate('nonbob', MINGLE_TEST_DEFAULT_PASSWORD)
  end

  def test_users_created_from_import_which_do_not_have_salt_nor_password_should_fail_authentication
    user = create(:user, login: 'newbob')

    ActiveRecord::Base.connection.execute SqlHelper.sanitize_sql('UPDATE users SET salt = NULL, password = NULL WHERE id = ?', user.id)
    assert_nil User.authenticate('newbob', MINGLE_TEST_DEFAULT_PASSWORD)
  end

  def test_password_should_not_be_restricted_except_being_empty_when_password_format_is_nil
    Authenticator.password_format = nil
    user = build(:user, password: 'p', password_confirmation: 'p')
    assert user.valid?
    user = build(:user, password: '', password_confirmation: '')
    assert !user.valid?
  end

  def test_password_confirmation_needs_only_be_checked_when_password_is_changed
    Authenticator.password_format = nil
    user = create(:user)
    user.password = 'ppp'

    assert !user.valid?

    user.password = MINGLE_TEST_DEFAULT_PASSWORD
    assert user.valid?
  end

  def test_change_password_should_set_login_access_lost_password_key_to_nil_and_returns_true
    user = create(:user)
    user.login_access.generate_lost_password_ticket!
    assert user.change_password!(:password => 'p@y B1ll', :password_confirmation => 'p@y B1ll')
    assert_nil user.login_access.lost_password_key
    assert_nil user.login_access.lost_password_reported_at
  end

  def test_invalid_password_change_should_not_set_login_access_lost_password_key_to_nil_and_returns_false
    user = create(:user)
    user.login_access.generate_lost_password_ticket!
    assert_false user.change_password!(:password => 'pay bill', :password_confirmation => 'pay bill')
    assert_not_nil user.login_access.lost_password_key
    assert_not_nil user.login_access.lost_password_reported_at
  end

  def test_validate_email
    u = User.new

    assert_is_valid_email(nil, u)
    assert_is_valid_email('valid@email.com', u)
    assert_is_valid_email('your-NAME@your-company.com', u)
    assert_is_valid_email('your.NAME@your-company.com', u)
    assert_is_valid_email('your.NAME@your.company.com', u)

    assert_is_invalid_email('invalid email', u)
    assert_is_invalid_email('your_name@your_company.com', u)
    assert_is_invalid_email('invalid@@email.com', u)
  end

  def test_bad_logins
    u = User.new
    u.email = 'newbob@example.com'
    u.name = 'name'
    u.password = u.password_confirmation = 'bobs_secure_password1.'

    u.login = 'b'*256
    assert !u.save
    assert 'Login is invalid', u.errors.full_messages.join(' ')

    u.login = ''
    assert !u.save
    assert 'Login is invalid', u.errors.full_messages.join(' ')

    u.login = 'b,o,b'
    assert !u.save
    assert 'Login is invalid', u.errors.full_messages.join(' ')

    u.login = 'okbob'
    assert u.save
    assert 'Login is invalid', u.errors.full_messages.join(' ')

  end

  def test_can_update_user_that_password_is_blank
    u = build(:user, login: 'u', name: 'U',password:'', password_confirmation:'')
    u.save(validate:false)
    assert u.update_attributes(name: 'U updated')
  end

  def test_login_formats
    assert_ok_login_format('chet.tester@example.com')
    assert_ok_login_format('chet+tester')
    assert_ok_login_format('chat@foo.com')
    assert_ok_login_format('c-h-e-t_tester@examle.com')
    assert_ok_login_format('chester')
    assert_ok_login_format('012_foo@example.com')

    assert_bad_login_format('chester&tester')
    assert_bad_login_format('chster*tester')
    assert_bad_login_format('chester~tester')
    assert_bad_login_format('chester#tester')
    assert_bad_login_format('chester%tester')
  end

  def assert_ok_login_format(login)
    user = build(:user, name: 'name', login: login, email: nil)
    assert user.save
  end

  def assert_bad_login_format(login)
    user = build(:user, name: 'name', login: login, email:nil)
    assert !user.save
    assert 'Login is invalid', user.errors.full_messages.join(' ')
  end

  def test_collision
    create(:user, login: 'existingbob')

    user = build(:user, name: 'name', email: 'existingbob@email.com')
    assert !user.save

    user = build(:user, name: 'name', login: 'existingbob')
    assert !user.save
  end

  def test_password_must_present
    assert_false build(:user, password:nil).valid?
  end

  def test_should_hash_password_after_creation
    user = create(:user)
    hashed_password = Digest::SHA256.hexdigest(user.salt + Digest::SHA1.hexdigest("mingle--#{MINGLE_TEST_DEFAULT_PASSWORD}--"))
    assert_equal hashed_password, user.password
  end

  def test_should_trim_name_when_save_user
    sam = create(:user, name: 'Sam')
    assert_equal 'Sam', sam.name
    assert_equal 'Jon', User.update(sam.id, name: ' Jon').name
  end

  def test_user_should_be_the_sole_admin_if_user_is_only_one_admin_that_activated
    create(:user, login: 'new_member')

    assert_equal 1, User.admins.size
    assert @admin.sole_admin?
    assert !User.find_by_login('new_member').sole_admin?
    assert !User.find_by_login('new_member').admin?

    User.find_by_login('new_member').update_attributes(:admin =>  true)
    assert !@admin.sole_admin?
    assert !User.find_by_login('new_member').sole_admin?

    User.find_by_login('new_member').update_attributes(:activated => false)
    assert @admin.sole_admin?
    assert !User.find_by_login('new_member').sole_admin?

  end

  def test_cannot_make_the_last_admin_a_non_admin
    assert @admin.sole_admin?
    @admin.update_attributes(:admin => false)

    assert_equal "Administrator #{@admin.name} cannot be removed as they are the last admin", @admin.errors.full_messages.join
  end

  def test_cannot_deactivate_last_admin
    @admin.update_attributes(:activated => false)
    assert_equal "Administrator #{@admin.name} cannot be deactivated as they are the last admin", @admin.errors.full_messages.join
  end

  def test_cannot_remove_last_admin
    assert @admin.sole_admin?
    @admin.destroy
    assert @admin.id
  end

  def test_password_is_checked_for_basic_quality_when_password_format_is_strict
    assert_equal 'is too short (minimum is 5 characters)', User.create(password:'a1.').errors.messages[:password].join
    assert_equal 'needs at least one digit', User.create(:password => 'banan.').errors.messages[:password].join
    assert_equal 'needs at least one special character symbol (e.g. ".", "," or "-")',
    User.create(:password => 'banan1').errors.messages[:password].join
    assert_false User.create(:password => 'banan1.').errors.messages.key?(:password)
  end

  # def test_has_subscribed_target_history
  #   user = create_user!(login: 'beachblanketbingo', :email => 'beachblanketbingo@email.com', name: 'beach blanket bingo')
  #   project = create_project
  #   setup_text_property_definition('status')
  #   filter_params = HistoryFilterParams.new('acquired_filter_properties[status]=new').serialize
  #   assert !user.has_subscribed_history?(project, filter_params)
  #
  #   project.history_subscriptions.create(:user => user, :filter_params => filter_params,
  #     :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
  #   assert user.has_subscribed_history?(project, filter_params)
  #   assert user.has_subscribed_history?(project, filter_params + '&period=today')
  #   assert !user.has_subscribed_history?(project, HistoryFilterParams.new('acquired_filter_properties[status]=open').serialize)
  #
  #   assert !user.has_subscribed_history?(project, '')
  #   project.history_subscriptions.create(:user => user, :filter_params => nil,
  #     :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
  #   assert user.has_subscribed_history?(project, '')
  # end

  def test_should_strip_on_both_password_and_password_confirmation
    password = "    #{MINGLE_TEST_DEFAULT_PASSWORD}   "
    user = create(:user, password_confirmation: password, password: password)

    assert_equal user.password, User.sha_password(user.salt, MINGLE_TEST_DEFAULT_PASSWORD)
  end

  def test_login_should_be_stored_as_downcase
    user = create(:user, login: 'LoGin')
    assert_equal 'login', user.login

    user.update_attribute(:login, 'LoGiN')
    user.save
    assert_equal 'login', user.login

    assert User.authenticate('LoGin', MINGLE_TEST_DEFAULT_PASSWORD)
  end

  def test_the_min_length_of_login_is_one
    user = User.new(name: 'u', login: 'u', :password => 'pass123.', :password_confirmation => 'pass123.', :email => 'email@email.com')
    user.valid?
    assert_false user.errors.messages.key?(:login)
  end

  def test_should_return_true_when_password_is_changed
    user  = create(:user)
    assert_false user.password_changed?
    user.password = user.password_confirmation = 'new-password'
    assert user.password_changed?
    user.save
    assert_false User.find_by_id(user.id).password_changed?
  end

  def test_should_return_true_when_password_is_changed_for_system_user
    system_user  = create(:user, system: true)
    assert_false system_user.password_changed?
    system_user.password = system_user.password_confirmation = 'new-password'
    assert system_user.password_changed?
    system_user.save
    assert_false User.find_by_id(system_user.id).password_changed?
  end
  # def test_should_not_create_generate_revision_changes_event_when_did_not_update_user_version_control_user_name
  #   Event.find(:all).each(&:destroy)
  #   with_first_project do |project|
  #     Revision.create :project_id => project.id, :number => 1, :commit_message => 'haha', :commit_time => Time.now, :commit_user => 'xli'
  #     member = User.find_by_login('member')
  #     User.current = member
  #
  #     member.update_attribute :version_control_user_name, 'xli'
  #     member.save!
  #     project.activate
  #     project.add_member member
  #     project.save!
  #     project.deactivate
  #
  #     events = Event.find(:all)
  #     member.remember_me_in({})
  #     member.save!
  #     member.forget_me({})
  #     member.save!
  #     assert_equal events, Event.find(:all)
  #   end
  # end

  # def test_should_update_card_list_view_when_updating_user_login
  #   @member = create_user!
  #   create_project(:users => [@member]) do |project|
  #     setup_property_definitions :status => ['new', 'open', 'close']
  #     setup_user_definition('dev')
  #     @view = CardListView.find_or_construct(project, {name: 'user login test', :filters => ["[dev][is][#{@member.login}]"]})
  #     @view.save!
  #     project.reload
  #     @member.update_attribute(:login, 'new_login')
  #     @view = project.card_list_views.find_by_name('user login test')
  #     assert_equal ['[dev][is][new_login]'], @view.to_params[:filters]
  #   end
  # end
#
#   def test_should_update_card_list_view_when_updating_user_login_using_admin_update_profile
#     @member = create_user!
#     create_project(:users => [@member]).with_active_project do |project|
#       setup_property_definitions :status => ['new', 'open', 'close']
#       setup_user_definition('dev')
#       @view = CardListView.find_or_construct(project, {name: 'user login test', :filters => ["[dev][is][#{@member.login}]"]})
#       @view.save!
#       @member.admin_update_profile login: 'new_login'
#       project.reload
#       @view = project.card_list_views.find_by_name('user login test')
#       assert_equal ['[dev][is][new_login]'], @view.to_params[:filters]
#     end
#   end
#
  def test_member_of
    member = User.find_by_login('member')
    create(:project) do |project|
      project.add_member(member)
      project.remove_member(@admin)

      assert member.reload.member_of?(project)
      assert !@admin.reload.member_of?(project)
    end
  end

#   def test_to_xml_for_mingle_admin
#     Project.current.deactivte rescue nil
#     login_as_admin
#     user = User.new(name: 'to_xml test user', login: 'to_xml_test', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :email => 'to_xml_test@email.com', :version_control_user_name => 'xxx')
#     user.save!
#     user.login_access.update_attribute(:last_login_at, Time.parse('Mon Oct 18 10:20:30 UTC 2010'))
#
#     expected = <<-EXPECTED
# <user>
#   <name>to_xml test user</name>
#   <version_control_user_name>xxx</version_control_user_name>
#   <admin type="boolean">false</admin>
#   <activated type="boolean">true</activated>
#   <login>to_xml_test</login>
#   <id type="integer">#{user.id}</id>
#   <email>to_xml_test@email.com</email>
#   <light type="boolean">#{user.light}</light>
#   <last_login_at type="datetime">2010-10-18T10:20:30Z</last_login_at>
# </user>
# EXPECTED
#     result = user.to_xml(:with_last_login_time => true, :view_helper => view_helper)
#     #jruby has different output order for hash keys, so we can't just compare them.
#     expected.split("\n").each do |line|
#       assert result.include?(line), "<#{result}> doesn't include: #{line}"
#     end
#   end
#
#   def test_xml_icon_url_should_be_full_file_column_url_if_user_upload_icon
#     login_as_admin
#     user = create_user!(:icon => sample_attachment('user_icon.jpg'))
#     xml = user.to_xml(:view_helper => view_helper)
#     assert_equal "http://test.host#{user.icon_path}", Hash.from_xml(xml)['user']['icon_url'].split('?').first
#   ensure
#     ActionController::Base.asset_host = nil
#   end
#
#   def test_xml_icon_url_should_be_initial_icon_if_user_did_not_upload_icon
#     login_as_admin
#     ActionController::Base.asset_host = 'http://assets.host'
#     user = create_user!(name: 'Joe', :icon => nil)
#     xml = user.to_xml(:view_helper => view_helper)
#     assert_equal 'http://assets.host/images/avatars/j.png', Hash.from_xml(xml)['user']['icon_url'].split('?').first
#   ensure
#     ActionController::Base.asset_host = nil
#   end
#
#   def test_xml_icon_url_should_be_full_gravatar_url_if_user_gravatar_feature_is_on
#     login_as_admin
#     MingleConfiguration.overridden_to(:multitenancy_mode => true) do
#       user = create_user!(name: 'Joe', :icon => nil, :email => 'joedon@foo.com')
#       fallback = CGI.escape view_helper.image_url('avatars/j.png')
#       xml = user.to_xml(:view_helper => view_helper)
#       assert_equal "https://www.gravatar.com/avatar/54c08d59b61641309edcda50618f1f4c?d=#{fallback}&s=48", Hash.from_xml(xml)['user']['icon_url']
#     end
#   end
#
#
#
#   def test_to_xml_for_project_admin
#     login_as_admin
#     user = User.create!(name: 'to_xml test user', login: 'to_xml_test', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :email => 'to_xml_test@email.com', :version_control_user_name => 'xxx')
#     user.login_access.update_attribute(:last_login_at, Time.parse('Mon Oct 18 10:20:30 UTC 2010'))
#
#     login_as_proj_admin
#     assert User.current.project_admin?
#
#     expected = <<-EXPECTED
# <user>
#   <name>to_xml test user</name>
#   <version_control_user_name>xxx</version_control_user_name>
#   <admin type="boolean">false</admin>
#   <activated type="boolean">true</activated>
#   <login>to_xml_test</login>
#   <id type="integer">#{user.id}</id>
#   <email>to_xml_test@email.com</email>
#   <light type="boolean">#{user.light}</light>
# </user>
# EXPECTED
#     result = user.to_xml(:view_helper => view_helper)
#     #jruby has different output order for hash keys, so we can't just compare them.
#     expected.split("\n").each do |line|
#       assert result.include?(line), "<#{result}> doesn't include: #{line}"
#     end
#   end
#
#   def test_anonymous_user_should_have_access_to_all_anonymous_projects
#     assert_equal [], User.anonymous.projects
#     set_anonymous_access_for(first_project, true)
#     assert_equal [first_project], User.anonymous.accessible_projects
#   end
#
#   def test_anonymous_user_should_not_be_a_project_admin
#     assert_false User.anonymous.project_admin?
#   end
#
#   def test_anonymous_user_should_not_have_access_to_hidden_projects
#     login_as_admin
#     create(:project, identifier:'dharmenn1abcd')
#     create(:project, identifier:'dharmenn10abcd')
#     create(:project, identifier:'dharmenn2abcd')
#     assert_equal [], User.anonymous.projects
#     hidden_project = Project.create!(name: 'a1', :identifier => 'a1', :hidden => true)
#     set_anonymous_access_for(hidden_project, true)
#     assert_equal [], User.anonymous.accessible_projects
#   end
#
#   def test_anonymous_user_should_not_belongs_to_any_project
#     assert_equal [], User.anonymous.projects
#     set_anonymous_access_for(first_project, true)
#     assert_equal [], User.anonymous.projects
#   end
#
#   def test_anonymouse_user_should_have_login_access
#     login_access = User.anonymous.login_access
#     assert_nil login_access.login_token
#     assert_nil login_access.last_login_at
#     assert_nil login_access.lost_password_key
#     assert_nil login_access.lost_password_reported_at
#     assert_nothing_raised { login_access.update_attribute(:blah, 'blah') }
#   end
#
#   def test_accessible_projects_for_normal_member_should_contains_project_it_belongs_to_plus_anonymous_accessibles
#     change_license_to_allow_anonymous_access
#     bob = User.find_by_login('bob')
#     anonymous_accessible_project = create_project :anonymous_accessible => true
#     assert_include first_project, bob.accessible_projects
#     assert_include anonymous_accessible_project, bob.accessible_projects
#   end
#
#   def test_accessible_templates_should_include_all_templates_for_admins
#     login_as_bob
#     custom_template = Project.create!(name: 'a2', :identifier => 'a2', :template => true)
#     admin = @admin
#     assert admin.accessible_templates.map(&:identifier).include?(custom_template.identifier)
#   end
#
#   def test_accessible_templates_should_include_templates_non_admin_user_is_a_member_of
#     login_as_admin
#     custom_template = Project.create!(name: 'a3', :identifier => 'a3', :template => true)
#     bob = User.find_by_login('bob')
#     custom_template.add_member(bob)
#     assert bob.accessible_templates.include?(custom_template)
#   end
#
#   def test_accessible_templates_should_not_include_templates_non_admin_is_not_a_member_of
#     login_as_admin
#     custom_template = Project.create!(name: 'a4', :identifier => 'a4', :template => true)
#     bob = User.find_by_login('bob')
#     assert !bob.accessible_templates.include?(custom_template)
#   end
#
#   def test_accessible_templates_should_not_include_hidden_templates
#     login_as_admin
#     bob = User.find_by_login('bob')
#     admin = @admin
#     hidden_template = Project.create!(name: 'a5', :identifier => 'a5', :template => true, :hidden => true)
#     hidden_template.add_member(bob)
#     assert !bob.accessible_templates.include?(hidden_template)
#     assert !admin.accessible_templates.include?(hidden_template)
#   end
#
#   def test_accessible_templates_should_be_smart_sorted_for_admins_and_non_admins
#     login_as_admin
#     bob = User.find_by_login('bob')
#     admin = @admin
#     custom_template_names = %w{B a c D}
#     custom_template_names.each do |template_name|
#       template = Project.create!(name: template_name, :identifier => template_name.downcase, :template => true)
#       template.add_member(bob)
#     end
#     custom_template_names = custom_template_names.smart_sort
#     assert_equal custom_template_names, admin.accessible_templates.collect(&:name).select { |template_name| custom_template_names.include?(template_name) }
#     assert_equal custom_template_names, bob.accessible_templates.collect(&:name)
#   end
#
#   def test_accessible_projects_should_not_include_hidden_projects
#     login_as_admin
#     hidden = Project.create!(name: 'hidden', :identifier => 'hidden', :hidden => true)
#     not_hidden = Project.create!(name: 'not_hidden', :identifier => 'not_hidden')
#     accessible_project_names = @admin
#.accessible_projects.collect(&:name)
#     assert !accessible_project_names.include?('hidden')
#     assert accessible_project_names.include?('not_hidden')
#   end
#
#   def test_project_admin_should_not_have_duplicate_entry_for_accessible_projects
#     proj_admin = User.find_by_login('proj_admin')
#     anonymous_accessible_project = create_project :anonymous_accessible => true, :admins => [proj_admin]
#     assert_equal proj_admin.accessible_projects.uniq.size, proj_admin.accessible_projects.size
#   end
#
#   def test_mingle_admin_should_have_accessibility_to_all_projects
#     project_member_of = create_project(:users => [User.first_admin])
#     project_not_member_of = create_project()
#     project_anonymous_accessible = create_project(:anonymous_accessible => true)
#
#     [project_member_of, project_not_member_of, project_anonymous_accessible].each do |project|
#       assert_include project, User.first_admin.accessible_projects
#     end
#   end
#
#   def test_project_admin
#     member = User.find_by_login('member')
#     with_new_project { |project| project.add_member(member, :project_admin) }
#     assert member.project_admin?
#   end
#
#   def test_mingle_admin_should_always_be_project_admin
#     mingle_admin = @admin
#     assert mingle_admin.admin?
#     assert mingle_admin.project_admin?
#   end
#
#   def test_mingle_admin_should_be_any_projects_admin_except_templates
#     mingle_admin = @admin
#     p1 = create_project
#     p2 = create_project(:template => true)
#
#     assert mingle_admin.admin_project_ids.include?(p1.id)
#     assert_false mingle_admin.admin_project_ids.include?(p2.id)
#   end
#
#   def test_admin_projects_should_not_include_hidden_projects
#     mingle_admin = @admin
#     p1 = create_project
#     p2 = create_project(:hidden => true)
#
#     assert p2.reload.hidden?
#
#     assert mingle_admin.admin_project_ids.include?(p1.id)
#     assert_false mingle_admin.admin_project_ids.include?(p2.id)
#   end
#
#   def test_should_remove_user_from_administrator_when_set_user_to_light
#     user = create_user!(:admin => true)
#     project = first_project
#     assert user.admin?
#
#     user.light = true
#     user.save!
#     project.reload
#     assert user.light?
#     assert !user.admin?
#   end
#
#   def test_light_column_is_null_should_count_towards_activated_full_users
#     activated_full_users = User.activated_full_users
#
#     u = create_user!(name: 'boboo', :light => nil)
#
#     assert_equal nil, u.light
#     assert_equal activated_full_users + 1, User.activated_full_users
#   end
#
#   def test_activated_users_is_full_plus_light
#     assert_equal User.activated_users, User.activated_full_users + User.activated_light_users
#   end
#
#   def test_first_user_should_be_admin_and_dont_check_license
#     User.find(:all).each(&:destroy_without_callbacks)
#     clear_license
#     first = create_user!
#
#     assert first.admin?
#   end
#
#   def test_should_create_deactivated_user_when_license_is_full
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users)
#
#     create_user!(:activated => false, name: 'deactivated new user')
#
#     assert User.find_by_name('deactivated new user')
#   end
#
#   def test_should_not_create_full_user_if_max_full_user_reached
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users + 1)
#
#     assert_raise ActiveRecord::RecordInvalid do
#       create_user!(login: 'new_user', :light => false)
#     end
#     assert_nil User.find_by_login('new_user')
#
#     create_user!(login: 'light_user', :light => true)
#     assert User.find_by_login('light_user')
#   end
#
#   def test_should_not_create_light_user_if_max_full_and_max_light_reached
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users)
#     assert_raise ActiveRecord::RecordInvalid do
#       create_user!(login: 'new_user', :light => true)
#     end
#     assert_nil User.find_by_login('new_user')
#   end
#
#   def test_should_create_light_user_if_max_light_reached_but_full_available
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     create_user!(login: 'new_user', :light => true)
#     assert User.find_by_login('new_user')
#   end
#
#   def test_should_not_create_light_user_if_max_light_reached_and_max_full_reached_with_full_as_light
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     create_user!(login: 'light_user', :light => true)
#
#     assert_raise ActiveRecord::RecordInvalid do
#       create_user!(login: 'dont_create', :light => true)
#     end
#
#     assert_nil User.find_by_login('dont_create')
#   end
#
#   def test_should_not_allow_activate_light_user_when_max_full_and_max_light_reached_and_full_user_used_As_light
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     create_user!(login: 'new_user', :light => true)
#
#     user = create_user!(login: 'deactivate_user', :light => true, :activated => false)
#     user.activated = true
#     user.save
#
#     assert !User.find_by_login('deactivate_user').activated
#   end
#
#   def test_should_allow_deactivate_light_user_when_max_full_and_max_light_reached_and_full_user_used_As_light
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     user = create_user!(login: 'new_user', :light => true)
#
#     user.activated = false
#     user.save
#
#     assert !User.find_by_login('new_user').activated
#   end
#
#   def test_should_switch_user_from_light_to_admin
#     user = create_user!(:light => true)
#     assert !user.admin?
#
#     user.admin = true
#     user.save!
#     assert !user.light?
#     assert user.admin?
#   end
#
#   def test_should_allow_change_light_user_to_full_if_max_full_and_max_light_reached_and_full_user_used_As_light
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     user = create_user!(login: 'new_user', :light => true)
#
#     user.light = false
#     user.save
#
#     assert !User.find_by_login('new_user').light
#   end
#
#   def test_should_allow_change_full_user_to_light_if_max_full_and_max_light_reached
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     user = create_user!(login: 'new_user')
#
#     user.light = true
#     user.save
#
#     assert User.find_by_login('new_user').light
#   end
#
#   def test_should_allow_change_admin_user_to_full_if_max_full_and_max_light_reached
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     user = create_user!(login: 'new_user', :admin  => true)
#
#     user.admin = false
#     user.save
#
#     assert !User.find_by_login('new_user').admin?
#   end
#
#   def test_should_allow_change_admin_user_to_full_if_max_full_and_max_light_not_reached
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users + 1)
#     user = create_user!(login: 'new_user', :admin  => true)
#
#     user.admin = false
#     user.save
#
#     assert !User.find_by_login('new_user').admin?
#   end
#
#   def test_should_allow_change_light_user_to_admin_if_borrrowing
#     register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
#     user = create_user!(login: 'new_user', :light  => true)
#
#     user.admin = true
#     user.save
#
#     assert User.find_by_login('new_user').admin?
#   end
#
#   def test_should_not_allow_light_to_admin_when_full_full_and_light_full
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users + 1)
#     user = create_user!(login: 'new_user', :light => true)
#
#     user.admin = true
#     user.save
#
#     assert !User.find_by_login('new_user').admin?
#   end
#
#   def test_should_not_allow_change_light_user_to_full_if_max_full_reached_not_reached_full
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users + 2)
#     user = create_user!(login: 'new_user', :light => true)
#
#     user.light = false
#     user.save
#
#     assert User.find_by_login('new_user').light?
#   end
#
#   def test_should_not_allow_change_light_user_to_full_if_max_full_reached_and_full_light_and_no_full_as_light
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users+1)
#     user = create_user!(login: 'new_user', :light => true)
#
#     user.light = false
#     user.save
#
#     assert User.find_by_login('new_user').light?
#   end
#
#   def test_can_set_user_type
#     u = create_user!(:user_type => 'light')
#     assert u.light?
#
#     u = create_user!(:user_type => 'admin')
#     assert u.admin?
#
#     u = create_user!(:user_type => 'full')
#     assert !u.light?
#     assert !u.admin?
#
#     u = create_user!
#     assert !u.light?
#     assert !u.admin?
#   end
#
#   #5734
#   def test_should_unsubscribe_all_history_filter_when_deactivate_user
#     SmtpConfiguration.load
#     @project = first_project
#     @project.activate
#     member = create_user!(name: 'Cheech')
#     @project.add_member member
#
#     assert_equal true, member.activated
#
#     history_filter_params = {:involved_filter_properties => {'old_type' => 'card'}}
#     subscription = @project.create_history_subscription(member,
#         HistoryFilterParams.new(history_filter_params).serialize)
#     HistoryMailer.deliver_subscribe(subscription)
#
#     assert_equal 1, @project.reload.history_subscriptions.size
#     member.update_attribute(:activated, false)
#     member.save
#
#     assert_equal 0, @project.reload.history_subscriptions.size
#   end
#
#   def test_should_allow_update_user_profile_when_licensed_max_active_user_size_reached
#     register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users)
#     user = User.find(:all).first
#     user.update_attribute('login', 'newloginname')
#     assert user.save
#   end
#
#   def test_create_user_with_icon
#     user = create_user!(:icon => sample_attachment('user_icon.jpg'))
#     user.reload
#     assert_match /user_icon\.jpg$/,  user.icon_relative_path
#   end
#
#
#   def test_can_not_update_another_user_using_id_hack
#     u1 = create_user!(login: 'u1')
#     u2 = create_user!(login: 'u2')
#
#     u2.update_profile(:id => u1.id)
#
#     u1.reload
#     u2.reload
#     assert_equal 'u1', u1.login
#     assert_equal 'u2', u2.login
#   end
#
#   def test_update_profile_should_not_include_sensitive_fields
#     user = create_user!(login: 'u1', :admin => false, :light => false, :activated => false)
#
#     [:admin, :light, :activated].each do |key|
#       user.update_profile(key => true)
#       assert_false user.send(key)
#     end
#
#     [:password, :password_confirmation].each do |key|
#       user.update_profile(key => 'blabla')
#       assert_not_equal 'blabla', user.send(key)
#     end
#
#     [:lost_password_key, :last_login_at].each do |key|
#       user.update_profile(key => 'blabla')
#       assert_not_equal 'blabla', user.login_access.send(key)
#     end
#   end
#
#   def test_should_validate_icon_file_extensions
#     user = User.new(name: 'new user', login: 'very_new', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :email => 'verynew@email.com', :icon => sample_attachment('user_icon.txt'))
#     assert !user.save
#     assert user.errors.invalid?(:icon)
#     assert_not_nil user.errors[:icon]
#   end
#
#   def test_should_validate_icon_file_size
#     user = User.new(name: 'new user', login: 'very_new', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :email => 'verynew@email.com', :icon => uploaded_file(icon_file_path('bigger_than_100K.jpg')))
#     assert !user.save
#     assert user.errors.invalid?(:icon)
#     assert_not_nil user.errors[:icon]
#   end
#
#   def test_update_and_reset_icon_at_same_time_should_replace_the_icon
#     user = create_user!
#     user.update_profile(:icon => sample_attachment('new_user_icon.png'), :reset_user_icon => 'true')
#
#     assert_not_nil user.icon
#   end
#
#   def test_reset_user_icon
#     user = create_user!(:icon => sample_attachment('user_icon.png'))
#     user.reset_user_icon = 'true'
#     user.save!
#     user.reload
#     assert_nil user.icon
#   end
#
#   def test_should_be_able_to_fetch_personal_card_list_view_favorites_for_user
#     member = login_as_member # member is a member of both first_project & card_query_project
#     first_project_member = first_project.users.find_by_login('bob')
#     card_query_project_member = card_query_project.users.find_by_login('proj_admin')
#
#     with_first_project do |project|
#       @member_first_project_view = project.card_list_views.create_or_update(:view => {name: 'personal view'}, :style => 'list', :user_id => member.id)
#       @bob_first_project_view = project.card_list_views.create_or_update(:view => {name: 'team view'}, :tagged_with => 'rss', :user_id => first_project_member.id)
#     end
#     with_card_query_project do |project|
#       @member_cq_project_view = project.card_list_views.create_or_update(:view => {name: 'personal view'}, :style => 'list', :user_id => member.id)
#       @proj_admin_cq_project_view = project.card_list_views.create_or_update(:view => {name: 'team view'}, :tagged_with => 'rss', :user_id => card_query_project_member.id)
#     end
#
#     with_first_project do |p|
#       assert_equal [@member_first_project_view], member.personal_views_for(p)
#     end
#   end
#
#   def test_should_be_able_to_fetch_personal_page_favorites_for_user
#     member = login_as_member # member is a member of both first_project & card_query_project
#     first_project_member = first_project.users.find_by_login('bob')
#     card_query_project_member = card_query_project.users.find_by_login('proj_admin')
#
#     with_first_project do |project|
#       page = project.pages.first
#       @member_first_project_page = project.favorites.personal(member).create(:favorited  => page)
#       @bob_first_project_page = project.favorites.personal(first_project_member).create(:favorited => page)
#     end
#     with_card_query_project do |project|
#       page = project.pages.create!(name: 'card_query_project_page')
#       @member_cq_project_page = project.favorites.personal(member).create(:favorited => page)
#       @proj_admin_cq_project_page = project.favorites.personal(first_project_member).create(:favorited => page)
#     end
#
#     with_first_project do |p|
#       assert_equal [@member_cq_project_page, @member_first_project_page].collect(&:name), member.personal_pages.collect(&:name)
#     end
#   end
#
#   def test_personal_views_should_be_able_to_sort_personal_favorites_by_project_name
#     member = login_as_member
#     with_new_project do |project|
#       project.update_attribute(:name, 'project2')
#       project.add_member(member)
#       @view1 = project.card_list_views.create_or_update(:view => {name: 'view1'}, :style => 'list', :user_id => member.id)
#     end
#
#     with_new_project do |project|
#       project.update_attribute(:name, 'project1')
#       project.add_member(member)
#       @view2 = project.card_list_views.create_or_update(:view => {name: 'view2'}, :style => 'list', :user_id => member.id)
#     end
#     assert_equal [@view2, @view1].collect(&:name), member.personal_views.collect(&:name)
#   end
#
#   def test_personal_views_should_be_able_to_sort_personal_favorites_by_favorite_name_when_project_name_are_equal
#     member = login_as_member
#     with_first_project do |project|
#       @view2 = project.card_list_views.create_or_update(:view => {name: 'view2'}, :style => 'list', :user_id => member.id)
#       @view1 = project.card_list_views.create_or_update(:view => {name: 'view1'}, :style => 'list', :user_id => member.id)
#       @view3 = project.card_list_views.create_or_update(:view => {name: 'view3'}, :style => 'list', :user_id => member.id)
#       assert_equal [@view1, @view2, @view3].collect(&:name), member.personal_views.collect(&:name)
#     end
#   end
#
#   def test_personal_views_should_not_inlcude_readonly_member_projects_views
#     member = login_as_member
#     with_new_project do |project|
#       project.add_member(member)
#       @view1 = project.card_list_views.create_or_update(:view => {name: 'view1'}, :style => 'list', :user_id => member.id)
#       project.add_member(member, :readonly_member)
#     end
#
#     with_new_project do |project|
#       project.add_member(member)
#       @view2 = project.card_list_views.create_or_update(:view => {name: 'view2'}, :style => 'list', :user_id => member.id)
#     end
#     assert_equal [@view2.name], member.personal_views.collect(&:name)
#   end
#
#   def test_remove_admin_ship_should_remove_personal_favorites
#     admin = login_as_admin
#     with_new_project do |project|
#       project.card_list_views.create_or_update(:view => {name: 'view1'}, :style => 'list', :user_id => admin.id)
#     end
#     admin.update_attribute :admin, false
#     assert_nil CardListView.find_by_name('view1')
#   end
#
#   def test_remove_admin_ship_should_not_remove_personal_favorites_when_he_is_a_member
#     admin = login_as_admin
#     with_new_project do |project|
#       project.add_member(admin)
#       @view = project.card_list_views.create_or_update(:view => {name: 'view1'}, :style => 'list', :user_id => admin.id)
#     end
#     admin.update_attribute :admin, false
#     assert_equal [@view], admin.personal_views
#   end
#
#   def test_remove_admin_ship_should_remove_personal_page_favorites
#     admin = login_as_admin
#     with_new_project do |project|
#       @project = project
#       page = project.pages.create(name: 'wiki')
#       project.favorites.personal(admin).create(:favorited => page)
#     end
#     admin.update_attribute :admin, false
#     @project.activate do |project|
#       assert @project.favorites.empty?
#     end
#   end
#
#   def test_remove_admin_ship_should_not_remove_personal_page_favorites_when_he_is_a_member
#     admin = login_as_admin
#     with_new_project do |project|
#       project.add_member(admin)
#       @page = project.pages.create(name: 'wiki')
#       project.favorites.personal(admin).create(:favorited => @page)
#     end
#     admin.update_attribute :admin, false
#     assert_equal [@page], admin.personal_pages
#   end
#
#   def test_should_create_login_access_when_creating_user
#     new_user = create(:user)
#     assert_not_nil User.find(new_user.id).login_access
#   end
#
#   def test_should_destroy_login_acces_when_deleting_user
#     new_user = create_user!
#     new_user.destroy
#     assert_nil LoginAccess.find_by_user_id(new_user.id)
#   end
#
#   def test_update_last_login
#     new_user = create_user!
#     Clock.now_is(:year => 2004, :month => 1, :day => 1, :hour => 23) do |now|
#       new_user.update_last_login
#       assert_equal now, new_user.login_access.last_login_at
#     end
#
#     Clock.now_is(:year => 2004, :month => 1, :day => 2, :hour => 23, :min => 0, :sec => 10) do |now|
#       new_user.update_last_login
#       assert_equal now, new_user.login_access.last_login_at
#     end
#
#   end
#
#   def test_should_update_last_login_once_per_hour
#     new_user = create_user!
#
#     now = Clock.fake_now(:year => 2004, :month => 1, :day => 1, :hour => 22)
#     new_user.update_last_login
#     assert_equal now, new_user.login_access.last_login_at
#
#     Clock.fake_now(:year => 2004, :month => 1, :day => 1, :hour => 22, :min => 22)
#     new_user.update_last_login
#     assert_equal now, new_user.login_access.last_login_at
#
#     new_hour = Clock.fake_now(:year => 2004, :month => 1, :day => 1, :hour => 23, :min => 1)
#     new_user.update_last_login
#     assert_equal new_hour, new_user.login_access.last_login_at
#
#   end
#
#   def test_set_first_login
#     new_user = create_user!
#
#     first_login_time = nil
#     Clock.now_is(:year => 2004, :month => 1, :day => 1, :hour => 23) do |now|
#       new_user.update_last_login
#       assert_equal now, new_user.login_access.first_login_at
#       first_login_time = now
#     end
#
#     Clock.now_is(:year => 2004, :month => 1, :day => 2, :hour => 23) do |now|
#       new_user.update_last_login
#       assert new_user.login_access.first_login_at
#       assert_equal first_login_time, new_user.login_access.first_login_at
#     end
#
#   end
#
#
#   # bug #10599 last login gets updated by deactivated user's attempt to login
#   def test_should_not_update_last_login_at_when_user_is_deactivated
#     Clock.now_is(:year => 2004, :month => 1, :day => 1, :hour => 23) do |now|
#       new_user = create_user!
#       new_user.update_attribute :activated, false
#       new_user.update_last_login
#       assert_nil new_user.login_access.last_login_at
#     end
#   end
#
#   #bug #10799 iLuau app when using feed events API gives a 500, related to user's login_access not updateable
#   def test_update_last_login_should_do_nothing_when_record_is_new
#     assert_nothing_raised do
#       assert_nil User.new.update_last_login
#     end
#   end
#
#   def test_projects_visible_to_hides_non_administered_projects_from_project_admins
#     with_card_query_project do |project|
#       user = create_user!
#       proj_admin = create_user!
#       first_project.add_member(user)
#       project.add_member(user)
#       first_project.add_member(proj_admin, :project_admin)
#       assert_equal [first_project], user.projects_visible_to(proj_admin)
#     end
#   end
#
#   def test_all_users_projects_should_be_visible_to_themselves
#     user = User.find_by_login('first')
#     assert user.projects.count > 0
#     assert_equal user.projects.count, user.projects_visible_to(user).count
#   end
#
#   def test_projects_visible_to_project_admin_include_project_admins_non_administered_projects
#     proj_admin = create_user!
#     first_project.add_member(proj_admin, :project_admin)
#     card_query_project.add_member(proj_admin)
#     assert proj_admin.projects_visible_to(proj_admin).include?(first_project)
#     assert proj_admin.projects_visible_to(proj_admin).include?(card_query_project)
#   end
#
#   def test_projects_visible_to_returns_all_users_projects_if_mingle_admin
#     user = create_user!
#     admin = create_user!
#     admin.update_attribute(:admin, true)
#     first_project.add_member(user)
#     assert_equal [first_project], user.projects_visible_to(admin)
#   end
#
#   def test_should_delete_oauth_tokens_granted_on_destroy
#     user = create_user!
#     token = Oauth2::Provider::OauthToken.create!(:user_id => user.id)
#     assert_equal 1, Oauth2::Provider::OauthToken.find_all_with(:user_id, user.id).size
#     user.destroy
#     assert_nil Oauth2::Provider::OauthToken.find_by_id(token.id)
#   end
#
#   def test_should_delete_oauth_tokens_granted_on_deactive
#     user = create_user!
#     token = Oauth2::Provider::OauthToken.create!(:user_id => user.id)
#     user.activated = false
#     user.save!
#     assert_nil Oauth2::Provider::OauthToken.find_by_id(token.id)
#   end
#
#   def test_should_not_lost_oauth_tokens_when_update_normal_attributes
#     user = create_user!
#     token = Oauth2::Provider::OauthToken.create!(:user_id => user.id)
#     user.name = 'hello'
#     user.save!
#     assert_equal token.id, Oauth2::Provider::OauthToken.find_by_id(token.id).id
#   end
#
#   def test_system_user_does_not_go_to_user_count
#     assert_no_difference 'User.count' do
#       User.create_or_update_system_user(login: 'sa', name: 'Sa')
#     end
#   end
#
#   def test_system_user_does_not_go_to_user_list
#     user = User.create_or_update_system_user(login: 'sa', name: 'Sa')
#     assert_not_include User.all, user
#   end
#
#   def test_can_find_system_user_using_login_or_id
#     user = User.create_or_update_system_user(login: 'sa', name: 'Sa')
#     assert_not_nil User.find(user.id)
#     assert_not_nil User.find_by_login(user.login)
#     assert_not_nil User.find_by_id(user.id)
#     assert_nil User.find_by_id_exclude_system(user.id)
#   end
#
#   def test_should_not_allow_to_destroy_system_user
#     user = User.create_or_update_system_user(login: 'sys', name: 'System admin')
#     user.destroy
#     assert_equal user, User.find_by_login(user.login)
#   end
#
#   def test_should_not_allow_to_destroy_current_user
#     user = create_user!
#     User.current = user
#     user.destroy
#     assert_equal user, User.find_by_login(user.login)
#   end
#
#   def test_should_not_allow_to_destroy_sole_admin
#     User.delete_all
#     user = create_user!
#     user.admin = true
#     user.activated = true
#     user.save!
#
#     user.destroy
#     assert_equal user, User.find_by_login(user.login)
#   end
#
#   def test_admin_in_any_project_returns_true_when_user_is_admin_of_any_projects
#     proj_admin = login_as_proj_admin
#     assert proj_admin.admin_in_any_project?
#   end
#
#   def test_admin_in_any_project_returns_false_when_user_isnt_admin_of_any_projects
#     bob = User.find_by_login('bob')
#     assert bob.projects.count > 0
#     assert !bob.admin_in_any_project?
#   end
#
#   def test_deletable_users_should_not_contain_system_users
#     user = User.create_or_update_system_user(login: 'sys', name: 'System admin')
#     assert_not_includes User.deletable_users, user
#   end
#
#   def test_find_by_email_should_be_case_insensitive
#     create_user!(:email => 'CAP.name@email.com')
#
#     assert User.find_by_email('cap.name@email.com')
#     assert User.find_by_email('CAP.NAME@EMAIL.COM')
#   end
#
#   def test_email_uniqueness_validation_should_be_case_insensitive
#     create_user!(:email => 'CAP.name@email.com')
#     user = User.new(:email => 'cap.name@email.com', name: 'capname', login: 'capname', :password => 'password1!', :password_confirmation => 'password1!')
#     assert !user.valid?, 'user should be invalid'
#     assert user.errors.invalid?('email'), 'user email is invalid'
#   end
#
#   def test_create_from_email_sets_default_attributes
#     user = User.create_from_email 'luca@dogs.com'
#     assert_equal ['luca', 'luca@dogs.com', 'luca@dogs.com'], [user.login, user.email, user.name]
#   end
#
#   def test_create_from_email_should_generate_uniq_login
#     user = User.create_from_email('member@dogs.com')
#     assert user.save
#     assert_equal 'member1', user.login
#   end
#
#   def test_singed_in_before
#     new_user = create_user!(:email => 'CAP.name@email.com')
#     assert_false new_user.signed_in_before?
#
#     login(new_user.email)
#     assert new_user.reload.signed_in_before?
#   end
#
#   def test_recent_users_for_project
#     @first_user = User.find_by_login('first')
#     login_as_member
#
#     User.current.display_preference.update_preference(:recent_users, [User.current.id, @first_user.id])
#
#     with_first_project do |project|
#       dev = project.find_property_definition 'dev'
#       user_logins = User.current.recent_users(project).map(&:login)
#       assert_equal ['member', 'first'], user_logins[0..1]
#       assert_equal ['bob', 'first', 'member', 'proj_admin'], user_logins.sort
#     end
#   end
#
#   def test_recent_users_should_return_at_most_5_users
#     login_as_member
#
#     with_first_project do |project|
#       10.times do |i|
#         user = create_user!(name: "Sam #{i}")
#         project.add_member(user)
#       end
#       dev = project.find_property_definition 'dev'
#       user_logins = User.current.recent_users(project).map(&:login)
#       assert_equal 5, user_logins.length
#     end
#   end
#
#   def test_update_recent_users_when_update_card_by_user
#     @first_user = User.find_by_login('first')
#     login_as_member
#
#     User.current.display_preference.update_preference(:recent_users, [User.current.id, @first_user.id])
#
#     with_first_project do |project|
#       dev = project.find_property_definition 'dev'
#       card = project.cards.first
#       dev.update_card(card, @first_user.id)
#       assert_equal [@first_user.id, User.current.id], User.current.display_preference.read_preference(:recent_users)
#
#       new_users = []
#       5.times do |i|
#         user = create_user!(name: "Sam #{i}")
#         project.add_member(user)
#         dev.update_card(card, user.id)
#         new_users << user
#       end
#       assert_equal new_users.map(&:id).reverse, User.current.display_preference.read_preference(:recent_users)
#     end
#   end
#
#   def test_should_delete_dependency_views_when_delete_user
#     user = create_user!
#     user.dependency_views.create(:project_id => 1)
#
#     assert_equal 1, user.dependency_views.count
#     view = user.dependency_views.first
#     user.destroy
#
#     assert_nil DependencyView.find_by_id(view.id)
#   end

  #Custom assertions
  def assert_is_valid_email(email, user)
    user.email = email
    user.save
    assert !user.errors.messages.key?(:email)
  end

  def assert_is_invalid_email(email, user)
    user.email = email
    user.save
    assert 'Email is invalid', user.errors.full_messages.join(' ')
  end

  def setup_history_notification_test
    SmtpConfiguration.load
    @project = project_without_cards
    @project.activate
    login_as_admin
    ActionMailer::Base.deliveries.clear
    @user = create_user!
    @project.add_member(@user)
  end
end
