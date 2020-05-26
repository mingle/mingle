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

class ProjectsControllerTest < ActionController::TestCase
  include MetricsHelper

  def setup
    @controller = create_controller ProjectsController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    rescue_action_in_public!

    @first_user = User.find_by_login('first')
    @member_user = User.find_by_login('member')
    @admin = User.find_by_login('admin')
    @bob = User.find_by_login('bob')
    @user = login_as_admin
  end

  def teardown
    reset_license
    logout_as_nil
  end

  # see [minglezy/#981]
  test 'history_as_first_tab_goes_to_the_right_page_when_navigating_to_project' do
    with_first_project do |project|
      class << @controller
        def card_context
          CardContext.new(project, {})
        end
      end

      # make History the first tab
      tabs = DisplayTabs.new(project, @controller)
      new_order = ['History'] + tabs.sortable_tabs.collect(&:identifier).reject {|n| n == 'History'
      }
      tabs.reorder!(new_order)
      assert_equal 'History', tabs.collect(&:identifier).first

      get :show, :project_id => project.identifier
      assert_redirected_to :controller => 'history', :action => 'index', :project_id => project.identifier
    end
  end

  test 'should_not_create_project_with_icon_of_invalid_type' do
    f = sample_attachment('1.txt')
    post :create, :project_id => 123, :project => {:name => 'foo', :identifier => 'foo', :icon => f}
    assert_rollback
    assert_template 'new'
    assert_nil Project.find_by_identifier('foo')
    assert_equal 'Icon is an invalid format. Supported formats are BMP, GIF, JPEG and PNG.', assigns(:project).errors.full_messages.first
  end

  test 'should_create_project_with_valid_icon' do
    f = uploaded_file(icon_file_path('icon.png'))
    post :create, :project_id => 123, :project => {:name => 'foo', :identifier => 'foo', :icon => f}
    assert Project.find_by_identifier('foo')
  end

  test 'should_not_upload_project_icon_images_larger_than_file_size_limit' do
    f = uploaded_file(icon_file_path('bigger_than_2M.jpg'))
    post :create, :project_id => 123, :project => {:name => 'foo', :identifier => 'foo', :icon => f}
    assert_rollback
    assert_template 'new'
    assert_nil Project.find_by_identifier('foo')
    assert_equal 'Icon is larger than the allowed file size. Maximum file size is 2 MB.', assigns(:project).errors.full_messages.first
  end

  test 'should_clear_active_project_after_request_finished' do
    def @controller.create
      Project.find_by_identifier('first_project').activate
      render :nothing => true
    end
    post :create
    assert_response :success
    assert_false Project.activated?
  end

  test 'can_render_edit_form' do
    get :edit, :project_id => create_project.identifier
    assert_response :success
  end

  test 'create_project_with_enabling_auto_enroll_user_type' do
    user_size = User.find(:all).size
    identifier = 'identifier'.uniquify[0..20]
    post :create, :project => {:name => 'auto_enroll_user_type', :identifier => identifier, :auto_enroll_user_type => 'full'}

    assert_redirected_to :action => 'show', :project_id => identifier
    created_project = Project.find_by_identifier(identifier)
    assert_equal 'full', created_project.auto_enroll_user_type
    assert_equal user_size, created_project.users.size
  end

  test 'create_project_with_enabling_all_users_are_readonly_members' do
    identifier = 'identifier'.uniquify[0..20]
    post :create, :project => {:name => 'auto_enroll_user_type', :identifier => identifier, :auto_enroll_user_type => 'readonly'}

    assert_redirected_to :action => 'show', :project_id => identifier
    assert_equal 'readonly', Project.find_by_identifier(identifier).auto_enroll_user_type
  end

  test 'should_have_at_least_one_card_type_after_created_project' do
    unique_project_name = unique_name 'project'
    post :create, :controller => 'projects',
      :project => {:name => unique_project_name, :identifier => unique_project_name}

    assert_equal 1, Project.find_by_name(unique_project_name).card_types.size
  end

  test 'should_have_at_least_one_card_type_after_created_project_used_template' do
    template = create_project
    template.update_attribute(:template, true)
    template.card_types.first.update_attribute :name, 'This is Card Type imported from template'

    unique_project_name = unique_name 'for_project'
    post :create, :controller => 'projects',
      :project => {:name => unique_project_name, :identifier => unique_project_name},
      :template_name => "custom_#{template.identifier}"

    project = Project.find_by_name(unique_project_name)
    assert_equal 1, project.card_types.size
    assert_equal 'This is Card Type imported from template', project.card_types.first.name
  end

  test 'should_maintain_tab_order_after_created_project_using_a_template' do
    class << @controller
      def card_context
        CardContext.new(project, {})
      end
    end
    template = create_project
    template.update_attribute(:template, true)
    tabs = DisplayTabs.new(template, @controller)
    tabs.reorder!(tabs.sortable_tabs.reverse)
    tab_order = tabs.sortable_tabs

    unique_project_name = unique_name 'template_tab_order'
    post :create, :controller => 'projects',
      :project => {:name => unique_project_name, :identifier => unique_project_name},
      :template_name => "custom_#{template.identifier}"

    project = Project.find_by_name(unique_project_name)
    tabs = DisplayTabs.new(project, @controller)
    assert_equal template.ordered_tab_identifiers, project.ordered_tab_identifiers
  end

  test 'should_lookup_template_in_db_if_identifier_prefixed_with_custom' do
    template_name = 'same_template_name'

    template = create_project(:identifier => template_name)
    template.update_attribute(:template, true)
    template.card_types.first.update_attribute(:name, 'story')

    unique_project_name = unique_name 'for_project'
    post(:create,
         :controller => 'projects',
         :project => {:name => unique_project_name, :identifier => unique_project_name},
         :template_name => "custom_#{template_name}")

    proj = Project.find_by_name(unique_project_name)
    proj.with_active_project do |proj|
      assert_equal ['story'], proj.card_types.map(&:name)
    end
  end

  test 'should_not_merge_anything_if_template_name_does_not_match_any_patterns' do
    unique_project_name = unique_name 'for_project'
    post(:create, :controller => 'projects',
         :project => {:name => unique_project_name, :identifier => unique_project_name},
         :template_name => 'xyz')
    assert Project.find_by_name(unique_project_name)
  end

  test 'should_lookup_template_in_configurable_spec_dir_when_prefixed_with_yml' do
    template_name = 'same_template_name'

    spec_dir = ConfigurableTemplate::SPEC_DIR
    test_template_spec = File.join(spec_dir, "#{template_name}.yml")

    begin
      test_spec = {:card_types => [{:name => 'Story'}], :cards => [{:name => 'hello from card imported via template specs', :card_type_name => 'Story'}]}
      File.open(test_template_spec, 'w') { |f| YAML.dump(test_spec, f) }

      unique_project_name = unique_name 'for_project'
      post(:create, :controller => 'projects',
           :project => {:name => unique_project_name, :identifier => unique_project_name},
           :template_name => "yml_#{template_name}")
      project = Project.find_by_name(unique_project_name)

      project.with_active_project do
        assert_equal 1, project.cards.size
        assert_equal 'hello from card imported via template specs', project.cards.first.name
      end
    ensure
      FileUtils.rm_f(test_template_spec)
    end
  end

  test 'should_lookup_template_inside_in_progress_templates_dir_when_prefixed_with_in_progress' do
    template_name = 'working_copy'

    spec_dir = ConfigurableTemplate::IN_PROGRESS_DIR
    test_template_spec = File.join(spec_dir, "#{template_name}.yml")
    FileUtils.mkdir_p(spec_dir)
    begin
      test_spec = {:card_types => [{:name => 'Story'}], :cards => [{:name => 'hello from card imported via template specs', :card_type_name => 'Story'}]}
      File.open(test_template_spec, 'w') { |f| YAML.dump(test_spec, f) }

      unique_project_name = unique_name 'for_project'
      post(:create, :controller => 'projects',
           :project => {:name => unique_project_name, :identifier => unique_project_name},
           :template_name => "in_progress_#{template_name}")
      project = Project.find_by_name(unique_project_name)
      assert project, 'should create new project'
      project.with_active_project do
        assert_equal 1, project.cards.size
        assert_equal 'hello from card imported via template specs', project.cards.first.name
      end
    ensure
      FileUtils.rm_f(test_template_spec)
    end
  end

  test 'can_see_delete_link_on_project_listing' do
    project = create_project
    get :index
    assert_tag 'a', :attributes => {:href => "/admin/projects/delete/#{project.identifier}"}
    login_as_member
    get :index
    assert_no_tag 'a', :attributes => {:href => "/admin/projects/delete/#{project.identifier}"}
  end

  test 'delete_project_confirming' do
    project = create_project
    project.add_member(@member_user)
    project.save!
    get :delete, :project_id => project.identifier
    assert_tag :a, :attributes => {:href => url_for(:controller => 'users', :action => 'show', :id => @member_user.id)}
  end

  test 'confirming_delete_of_a_project_deletes_all_project_related_information_from_the_system' do
    project = create_project
    post :confirm_delete, :project_id => project.identifier
    assert_redirected_to :action => 'index'
    assert_no_tag 'a', :attributes => {:href => "/projects/#{project.identifier}"}
    assert_equal "#{project.name.bold} was successfully deleted.", flash[:notice]
  end

  test 'update' do
    project = create_project
    new_name = unique_name
    post :update,
      :project_id => project.identifier,
      :project => {:name => new_name, :identifier => project.identifier, :anonymous_accessible => 'true'}
    assert_redirected_to project_show_url(:project_id => project.identifier)
    assert_equal new_name, project.reload.name
    assert project.anonymous_accessible?
  end

  test 'update_should_send_rename_project_event_if_name_changed' do
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      project = create_project
      post :update, :project_id => project.identifier, :project => {:name => 'changed' }
      assert @controller.events_tracker.
        sent_event?('rename_project', {'old_name' => project.name,
                       'new_name' => 'changed'})
    end
  end

  test 'update_should_not_send_project_rename_event_if_name_is_not_changed' do
    project = create_project
    post :update, :project_id => project.identifier, :project => {:description => 'best project in the world' }
    assert !@controller.events_tracker.sent_event?('rename_project')
  end

  test 'update_with_empty_str' do
    project = create_project
    project.update_attribute(:description, 'description')
    project.update_attribute(:email_address, 'email@com.cn')
    new_name = unique_name
    post :update,
      :project_id => project.identifier,
      :project => {:name => project.name, :identifier => project.identifier, :description => '', :email_address => ''}
    assert_redirected_to project_show_url(:project_id => project.identifier)

    assert_blank project.reload.description
    assert_blank project.reload.email_address
  end

  test 'should_show_only_blank_template_when_no_templates_present' do
    delete_all_templates
    get :new
    assert_select '.custom .template', :count => 0
  end

  test 'should_give_option_for_create_with_template_if_there_are_templates' do
    project = create_project
    project.update_attribute(:template, true)
    get :new
    assert_select ".custom .template.custom_#{project.identifier}"
  end

  test 'can_create_project_from_a_valid_template' do
    project = create_project
    project.update_attribute(:template, true)
    post :create, :controller => 'projects',
      :project => {:name => 'dolly', :identifier => 'dolly', :description => 'my description'},
      :template_name => project.identifier
    assert_redirected_to :action => 'show', :project_id => 'dolly'
    assert_equal 'my description', Project.find_by_identifier('dolly').description
  end

  test 'project_with_name_blank_cannot_be_created' do
    post(:create, :controller => 'projects',
         :project => {:name => ProjectsController::BLANK, :identifier => ProjectsController::BLANK, :description => 'my description'})
    assert_template 'new'
  end

  test 'it_should_create_blank_project_when_template_named_blank_is_selected' do
    post(:create,
         :controller => 'projects',
         :project => {:name => 'dolly', :identifier => 'dolly', :description => 'my description'},
         :template_name => ProjectsController::BLANK)

    assert_redirected_to :action => 'show', :project_id => 'dolly'
  end

  # bug 1477
  test 'should_copy_card_key_words_when_create_project_from_a_template' do
    project = create_project
    project.card_keywords = 'story,#,defect,bug'
    project.save
    project.update_attribute(:template, true)
    new_project_name = unique_project_name()
    post :create, :controller => 'projects',
      :project => {:name => new_project_name, :identifier => new_project_name, :description => 'for keywords'},
      :template_name => "custom_#{project.identifier}"

    assert_equal 'story,#,defect,bug', Project.find_by_identifier(new_project_name).card_keywords.to_s
  end

  test 'cannot_create_project_from_a_project' do
    project = create_project
    project.update_attribute(:template, true)
    get :new, :controller => 'projects'
    assert_tag 'input', :attributes => {:id => "template_name_custom_#{project.identifier}", :type => 'radio'}
    project.with_active_project do |project|
      project.update_attribute(:template, false)
    end

    get :new, :controller => 'projects'
    assert_no_tag 'input', :attributes => {:id => "template_name_#{project.identifier}", :type => 'radio'}
  end

  test 'can_create_custom_project_by_not_choosing_template' do
    unique_project_name = unique_name 'project'
    post :create, :controller => 'projects',
      :project => {:name => unique_project_name, :identifier => unique_project_name}

    assert_redirected_to :action => 'show', :project_id => unique_project_name

    even_more_unique_project_name = unique_name 'project'
    post :create, :controller => 'projects',
      :project => {:name => even_more_unique_project_name, :identifier => even_more_unique_project_name},
      :template_name => ''
    assert_redirected_to :action => 'show', :project_id => even_more_unique_project_name
  end

  # test for #833
  test 'shows_attachments_on_index_page' do
    project = create_project
    project.pages.create!(:identifier => project.overview_page_identifier)
    project.overview_page.attach_files(sample_attachment('1.gif'))
    get :overview, :project_id => project.identifier
    assert_select '.dropzone', :data => /1.gif/
  end

  test 'should_be_able_delete_attachment_in_view_mode' do
    project = create_project
    page = project.pages.create!(:identifier => 'Overview Page')
    page.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    page.save!
    xhr :delete, :remove_attachment, :project_id => project.identifier, :file_name => 'sample_attachment.txt', :format => 'json'
    assert_response :success
    assert_equal({'file' => 'sample_attachment.txt'}, JSON.parse(@response.body))
  end

  test 'should_update_content_section_if_content_used_recently_deleted_attachment' do
    project = create_project
    page = project.pages.create!(:identifier => 'Overview Page', :content => 'sample_attachment.gif')
    page.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    page.save!
    xhr :delete, :remove_attachment, :project_id => project.identifier, :file_name => 'sample_attachment.gif', :format => 'json'
    assert_response :success
    assert_equal({'file' => 'sample_attachment.gif'}, JSON.parse(@response.body))
  end

  test 'should_not_show_user_details_link_if_user_is_neither_a_mingle_admin_nor_a_project_admin' do
    set_current_user(@member_user) do
      get :index
      assert_no_tag :a, :content => 'Manage users'
    end
  end

  test 'should_export_project_only_for_admin_and_project_member' do
    project = create_project
    login(@bob.email)
    get :export, :project_id  => project.identifier
    assert_redirected_to projects_url
  end

  test 'should_show_all_projects_if_user_is_admin' do
    admin_login = unique_name('a')[0..8]
    new_admin = create_user!(:admin => true)
    login(new_admin.email)
    get :index

    assert Project.not_template.not_hidden.size > 0
    Project.not_template.not_hidden.each do |proj|
      assert_select 'a', :text => proj.name
    end
  end

  test 'index_xml_should_show_projects_and_templates' do
    regular_project = Project.first
    example_template = create_project :template => true
    login_as_admin
    get :index, :format => 'xml', :api_version => 'v2'
    assert_response :success
    [regular_project, example_template].each do |project|
      assert_include "<identifier>#{project.identifier}</identifier>", @response.body
    end
  end

  test 'should_show_any_project_if_user_is_admin' do
    project = create_project
    login_as_admin
    get :overview, :project_id => project.identifier
    assert_template 'overview'
  end

  test 'index_should_display_programs_tab' do
    get :index
    assert_select '#header-pills a', :text => 'Programs'
  end

  test 'index_should_display_admin_tab' do
    get :index
    assert_select '#header-pills a', :text => 'Admin'
  end

  test 'index_should_not_display_plans_tab_when_license_is_not_enterprise' do
    begin
      register_license(:product_edition => Registration::NON_ENTERPRISE)
      get :index
      assert_select '#plans-link', :count => 0
    ensure
      reset_license
    end
  end

  test 'invite_to_team_is_not_displayed_when_toggle_is_on' do
    register_license(:trial => true)
    get :overview, :project_id => first_project.identifier
    assert_response :success
    assert_select '.invite-to-team button'
  end


  test 'create_project_adds_creator_as_team_member_if_requested' do
    a_project_name = unique_project_name
    post :create, :controller => 'projects', :as_member => 'true',
      :project => {:name => a_project_name, :identifier => a_project_name}
    assert Project.find_by_identifier(a_project_name).member?(@admin)
  end

  test 'creat_project_does_not_add_creator_as_team_member_if_not_requested' do
    a_project_name = unique_project_name
    post :create, :controller => 'projects',
      :project => {:name => a_project_name, :identifier => a_project_name}
    assert !Project.find_by_identifier(a_project_name).member?(@admin)

    a_project_name = unique_project_name
    post :create, :controller => 'projects', :as_member => 'false',
      :project => {:name => a_project_name, :identifier => a_project_name}
    assert !Project.find_by_identifier(a_project_name).member?(@admin)
  end

  test 'hidden_projects_are_not_shown_on_list' do
    normal_project = create_project
    hidden_project = create_project
    hidden_project.update_attribute(:hidden, true)
    get :index
    assert @response.body.include?(normal_project.name)
    assert !@response.body.include?(hidden_project.name)
  end

  test 'keywords_test_does_not_re_initialize_revisions_cache' do
    project = create_project
    config = SubversionConfiguration.create!(:project_id => project.id, :repository_path => 'foorepository')
    post :test_keywords_for_revisions, :controller => 'projects', :card_number => '1',
      :project_id => project.identifier,
      :project => {:card_keywords => 'some, different, words'}
    assert_response :success
    assert_equal config.id, MinglePlugins::Source.find_for(project).id
  end

  test 'precision_should_default_to_2_on_new_project_form' do
     get :new, :controller => 'projects'
     assert_select "input[name='project[precision]'][value=2]"
  end

  test 'precision_should_default_to_2_on_creation' do
     a_project_name = unique_project_name
     post :create, :controller => 'projects', :project => {:name => a_project_name, :identifier => a_project_name}
     assert_equal 2, Project.find_by_identifier(a_project_name).precision
  end

  test 'precision_should_be_set' do
     a_project_name = unique_project_name
     post :create, :controller => 'projects', :project => {:name => a_project_name, :identifier => a_project_name, :precision => 10}
     assert_equal 10, Project.find_by_identifier(a_project_name).precision
  end

  # bug 2964.
  test 'should_not_update_links_with_bad_identifier' do
    project = create_project
    good_identifier = project.identifier
    bad_identifier = 'testing 2.0'
    post :update, :project_id => project.identifier, :project => {:identifier => bad_identifier}
    assert_equal good_identifier, project.reload.identifier
    assert_select "a#tab_overview_link[href='/projects/#{good_identifier}/overview']"
  end

  test 'should_redirected_to_index_if_none_member_accesses_project_show_page' do
    project = create_project
    login_as_longbob
    get :overview, :project_id => project.identifier
    assert_redirected_to projects_url
  end

  # bug 4633
  test 'no_overview_exists_message_displays_without_hyphen_and_create_link_for_readonly_members' do
    with_new_project do |project|
      project.add_member(@member_user)
      login_as_member
      get :overview, :project_id => project.identifier
      assert_select 'p#info', :text => /^This project does not have an overview page - why not create it...$/

      project.add_member(@member_user, :readonly_member)
      login_as_member
      get :overview, :project_id => project.identifier
      assert_select 'p#info', :text => /^This project does not have an overview page$/
    end
  end


  # bug 4276
  test 'redirected_with_correct_project_identifier_after_project_create' do
    post :create, :project => {:name => 'bang!!!!', :identifier => 'bang____'}
    assert_redirected_to :action => 'show', :project_id => 'bang____'
  end

  test 'should_not_show_project_link_when_annoymous_accessiable_but_license_is_invalid' do
    project = first_project
    project.activate
    project.update_attribute(:anonymous_accessible, true)
    register_expiration_license_with_allow_anonymous
    logout_as_nil
    get :index
    assert_response :success
    assert_select 'a', :text => project.name, :count => 0
  end

  test 'should_be_redirected_to_login_page_when_mingle_have_anonymous_accessible_projects_even_though_the_mingle_is_unlicensed' do
    project = first_project
    project.activate
    project.update_attribute(:anonymous_accessible, true)
    clear_license
    logout_as_nil
    get :index
    assert_redirected_to :controller => 'profile', :action => 'login'
  end

  test 'should_not_show_annoymous_accessible_project_when_the_license_is_not_allow_anonymous' do
    project = first_project
    project.activate
    project.update_attribute(:anonymous_accessible, true)
    user = create_user!
    login(user.email)
    get :index
    assert_response :success
    assert_select 'a', :text => project.name, :count => 0
  end

  test 'should_show_annoymous_accessible_project_for_mingle_admin_even_though_the_mingle_liense_is_violation' do
    project = first_project
    project.activate
    project.update_attribute(:anonymous_accessible, true)
    clear_license
    login_as_admin
    get :index
    assert_response :success
    assert_select 'div[class=project] a', :text => project.name, :count => 1
  end

  test 'should_show_project_list_to_anonymous_user_if_one_project_is_anonymous_accessible' do
    begin
      change_license_to_allow_anonymous_access
      with_first_project do |project|
        project.update_attribute(:anonymous_accessible, true)
      end
      logout_as_nil
      assert Project.has_anonymous_accessible_project?
      get :index
      assert_response :success
      assert_select 'a[href=/projects/first_project]', :count => 2 #one for project name, one for icon
    ensure
      reset_license
    end
  end

  test 'should_redirect_to_login_when_anonymous_user_accesses_project_list_when_no_projects_are_anonymous_accessible' do
    logout_as_nil
    assert_false Project.has_anonymous_accessible_project?
    get :index
    assert_redirected_to :controller => 'profile', :action => 'login'
  end

  test 'should_escape_project_name_in_projects_list' do
    project = first_project
    project.activate
    project.update_attribute(:name, '<h3>name</h3>')
    get :index
    assert_response :success
    assert_select 'div[class=project-description] a', :text => /&lt;h3&gt;name&lt;\/h3&gt;/
  end

  test 'should_have_notice_when_health_check_has_no_problem' do
    with_first_project do |project|
      @request.env['HTTP_REFERER'] = 'anything' # need to set this so redirect_to :back works
      get :health_check, :project_id => project.identifier
      assert flash[:notice]
    end
  end

  test 'should_have_notice_when_rebuild_card_murmur_linking' do
    with_first_project do |project|
      post :rebuild_card_murmur_linking, :project_id => project.identifier
      assert flash[:notice]
    end
  end

  test 'should_show_rebuild_murmur_and_card_links' do
    with_first_project do |project|
      get :advanced, :project_id => project.identifier
      assert_select 'h3', :text => 'Murmurs and card linking', :count => 1
    end
  end

  test 'should_unescapse_urlencoded_string_in_error_message_when_page_name_contain_html_tags' do
    with_first_project do |project|
      get :show_page_name_error, {
        :error_msg => '%26lt%3Bh3%26gt%3B is invalid page name.',
        :page_url => 'overview',
        :project_id => project.identifier }
      assert_response :redirect
      assert_equal '&lt;h3&gt; is invalid page name.', flash[:error]
    end
  end

  test 'request_membership_should_be_able_to_accessed_by_non_member' do
    first_project.activate
    first_project.update_attribute(:membership_requestable, true)
    login_as_longbob
    get :request_membership, :project_id => first_project.identifier
    assert_response :redirect
    assert_redirected_to :action => 'index'
    assert_equal "Your request for membership to project #{first_project.name.bold} has been successful.", flash[:notice]
  end

  test 'request_membership_should_show_me_error_when_project_admin_does_not_have_email' do
    first_project.activate
    first_project.update_attribute(:membership_requestable, true)

    first_project.admins.each { |admin| admin.update_attribute(:email, nil) }
    login_as_longbob
    get :request_membership, :project_id => first_project.identifier
    assert_response :redirect
    assert_equal 'This project does not have any project administrators or none of the project administrators has an email address. Please contact your Mingle Administrator for further assistance.', flash[:error]
  end

  test 'request_membership_should_show_me_error_when_project_does_not_have_admin' do
    first_project.activate
    first_project.update_attribute(:membership_requestable, true)

    with_first_project do |project|
      project.admins.each { |admin| project.remove_member(admin) }
    end
    login_as_longbob
    get :request_membership, :project_id => first_project.identifier
    assert_response :redirect
    assert_equal 'This project does not have any project administrators or none of the project administrators has an email address. Please contact your Mingle Administrator for further assistance.', flash[:error]
  end

  test 'request_membership_should_show_error_when_smtp_is_not_configured' do
    first_project.activate
    first_project.update_attribute(:membership_requestable, true)

    def @controller.smtp
      OpenStruct.new(:configured? => false)
    end
    login_as_longbob
    get :request_membership, :project_id => first_project.identifier
    assert_equal 'This feature is not configured. Contact your Mingle administrator for details.', flash[:error]
  end

  test 'request_membership_should_show_error_when_project_is_not_requestable' do
    login_as_longbob
    get :request_membership, :project_id => first_project.identifier
    assert_response :redirect
    assert_equal 'Either the resource you requested does not exist or you do not have access rights to that resource.', flash[:error]
  end

  test 'should_not_show_membership_requestable_option_when_editing_a_template' do
    template = create_project
    template.update_attribute(:template, true)
    get :edit, :project_id => template.identifier
    assert_select 'input#project_membership_requestable', :count => 0
  end

  test 'should_not_trigger_the_job_and_redirect_to_advanced_page_when_trying_to_send_get_request_for_an_admin_jobs' do
    with_first_project do |project|
      [:invalidate_content_cache, :recache_revisions, :regenerate_secret_key, :regenerate_changes, :recompute_aggregates, :rebuild_card_murmur_linking].each do |action|
        get action, :project_id => project.identifier
        assert_redirect_to_index_page_without_any_flash_message
      end
    end
  end

  test 'show_should_provide_warning_when_more_than_4_macros' do
    with_first_project do |project|
      page = project.pages.create!(:identifier => Project::OVERVIEW_PAGE_IDENTIFIER, :content => "sdfvsdf #{'{{ dummy }}' * 11} blabla")
      get :overview, :project_id => project.identifier, :page_identifier => page.identifier
      assert_select '#too_many_macros_warning'
    end
  end

  test 'confirming_delete_of_a_project_referenced_by_a_plan_should_provide_error_message' do
    project = sp_first_project
    post :confirm_delete, :project_id => project.identifier
    assert_redirected_to :action => 'index'
    follow_redirect
    assert_select 'a', :text => sp_first_project.name
    assert_equal "Project #{project.name.bold} is referenced by 1 plan: simple program", flash[:error]
  end

  test 'should_allow_delete_a_project_that_has_any_dependencies' do
    project = first_project
    resolving_project = create_project
    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:desired_end_date => '2014-09-11', :name => 'dep1', :resolving_project_id => resolving_project.id).save!
    end

    post :confirm_delete, :project_id => project.identifier
    get :index
    assert_no_tag 'a', :attributes => {:href => "/admin/projects/delete/#{project.identifier}"}
  end

  test 'deleting_project_with_no_current_work_in_plans_and_not_associated_to_any_plan_anymore_should_be_allowed' do
    project = create_project
    project.cards.create!(:number => 1, :name => 'first card', :card_type => project.card_types.first)

    program = create_program
    plan = program.plan
    program.assign(project)
    create_planned_objective(program)

    plan.assign_cards(project, 1, program.objectives.first)

    program.unassign(project)
    post :confirm_delete, :project_id => project.identifier

    assert_redirected_to :action => 'index'
    assert_no_tag 'a', :attributes => {:href => "/projects/#{project.identifier}"}
    assert_equal "#{project.name.bold} was successfully deleted.", flash[:notice]
  end

  test 'should_not_show_add_card_on_project_list' do
    get :index
    assert_select 'a#add_card_with_defaults', :count => 0
  end

  test 'should_not_show_project_info_when_hidden' do
   with_new_project do |project|
     project.add_member(@admin)
     project.hidden = true
     project.save!
     assert project.hidden?

     response = get :show_info, :project_id => project.identifier, :api_version => 'v2', :format => 'xml'
     assert_equal('404 Not Found', response.status)
   end
  end

  def assert_redirect_to_index_page_without_any_flash_message
    assert_redirected_to :action => 'index'
    assert_nil flash[:notice]
    assert_nil flash[:error]
  end

  test 'non_project_admin_user_can_view_project_contents' do
    bob = login_as_bob
    project = sp_first_project
    project.add_member(bob, :readonly_member)
    project.save!

    response = get :show_info, :project_id => project.identifier, :api_version => 'v2', :format => 'xml'
    assert_response :success
  end

  test 'tabs_visibility' do
    get :index
    assert_select '#header-pills li a', :text => 'Programs'
    assert_select '#header-pills li.selected a', :text => 'Projects'
    assert_select '#header-pills li a', :text => 'Admin'
  end

  test 'show_redirects_to_overview_page_when_there_is_no_ordered_tab_identifiers' do
    with_new_project do |project|
      get :show, :project_id => project.identifier
      assert_redirected_to project_overview_path(project.identifier)
    end
  end

  test 'show_redirects_to_first_tab_when_there_is_ordered_tab_identifiers_defined' do
    with_new_project do |project|
      view = CardListView.construct_from_params(project, :name => 'Story Wall', :style => 'grid')
      view.tab_view = true
      view.save!

      project.ordered_tab_identifiers = "#{view.favorite.id},Overview"
      project.save!

      get :show, :project_id => project.identifier
      assert_redirected_to view.link_params
    end
  end

  test 'show_redirection_should_keep_params' do
    with_new_project do |project|
      get :show, :project_id => project.identifier, :murmur_id => 1
      assert_redirected_to project_overview_path(project.identifier) + '?murmur_id=1'
    end
  end

  test 'create_project_sends_monitoring_metrics_with_template_name' do
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      template = create_project(:identifier => 'tracked_template')
      template.update_attribute(:template, true)

      unique_project_name = unique_name 'for_project'
      post :create, :controller => 'projects',
           :project => {:name => unique_project_name, :identifier => unique_project_name},
           :template_name => template.identifier
      assert @controller.events_tracker.sent_event?('create_project',
                                                    {'project_name' =>
                                                     unique_project_name, 'template_name' => template.identifier})
    end
  end

  test 'create_project_with_project_spec' do
    spec = JSON.dump({ :project => {:name => 'Foo Project', :identifier => 'foo' }})
    post :create_with_spec, :api_version => 'v2', :spec => spec, :format => 'xml'

    assert_response :created
    assert_equal 'Foo Project', Project.find_by_identifier('foo').name

  end

  test 'create_project_with_project_spec_and_include_current_user_as_member' do
    spec = JSON.dump({ :project => {:name => 'Foo Project', :identifier => 'foo' }})
    post :create_with_spec, :api_version => 'v2', :spec => spec, :as_member => 'true', :format => 'xml'

    assert_response :created
    proj = Project.find_by_identifier('foo')
    assert_equal [@user.login], proj.users.map(&:login)
  end

  test 'create_project_without_project_identifier' do
    spec = JSON.dump({ :project => {:name => 'Foo Project'}})
    post :create_with_spec, :api_version => 'v2', :spec => spec, :format => 'xml'

    assert_response :created
    assert_equal 'fooproject', @response.header['Identifier']
  end

  test 'create_project_with_spec_with_separate_project_name' do
    spec = JSON.dump({})
    post :create_with_spec, :api_version => 'v2', :project => {:name => 'Foo Project'}, :spec => spec, :format => 'xml'

    assert_response :created
    assert_equal 'fooproject', @response.header['Identifier']
  end

  test 'create_project_with_invalid_project_spec' do
    spec = JSON.dump({ :project => {:name => 'Foo Project', :identifier => 'hello there' }})
    assert_no_difference 'Project.count' do
      post :create_with_spec, :api_version => 'v2', :spec => spec, :format => 'xml'
    end
    assert_response :unprocessable_entity

  end

  test 'project_list_in_json' do
    get :index, :format => 'json'
    assert_response :ok
    projects = JSON.parse(@response.body)
    assert_include 'first_project', projects.map {|p| p['identifier']}
  end

  test 'index_should_not_include_requestable_projects' do
    requestable_project = create_project(membership_requestable: true, name: 'Requestable Project')
    accessible_project = create_project(name: 'Accessible Project', users: [@member_user])
    login_as_member

    get :index, format: 'json', exclude_requestable: 'true'
    projects = JSON.parse(@response.body)

    assert_response :ok
    assert_include accessible_project.identifier, projects.collect { |p| p['identifier'] }
    assert_not_include requestable_project.identifier, projects.collect { |p| p['identifier'] }
  end

  test 'create_project_without_identifier_should_generate_one_from_name' do
    unique_project_name = unique_name 'for_project'
    post :create, :controller => 'projects', :project => {:name => unique_project_name}, :format => 'xml', :api_version => 'v2'

    assert_response :created
    proj = Project.find_by_name(unique_project_name)
    assert proj
    assert_equal proj.identifier, @response.headers['identifier']
    assert_match /forproject/, proj.identifier
  end

  test 'should_response_unprocessable_entity_when_no_project_params' do
    post :create, :controller => 'projects'
    assert_response :unprocessable_entity
  end

  test 'chart_data_should_return_name_identifier_and_date_format' do
    with_new_project do |project|
      project.add_member(@admin)
      project.save!
      project.reload

      get :chart_data, :project_id => project.identifier, :api_version => 'v2', :format => 'json'
      project_chart_data = JSON.parse(@response.body).with_indifferent_access

      assert_response :ok
      assert_equal project.name, project_chart_data[:name]
      assert_equal project.identifier, project_chart_data[:identifier]
      assert_equal project.date_format, project_chart_data[:dateFormat]
    end
  end

  test 'chart_data_should_return_card_types_data' do
    with_new_project do |project|
      project.add_member(@admin)
      project.save!
      project.reload

      expected_card_types_data = project.card_types.collect do |card_type|
        {
            'id' => card_type.id,
            'name' => card_type.name,
            'color' => card_type.color,
            'position' => card_type.position,
            'propertyDefinitions' => []
        }
      end


      get :chart_data, :project_id => project.identifier, :api_version => 'v2', :format => 'json'
      card_types_data = JSON.parse(@response.body).with_indifferent_access[:cardTypes]

      assert_response :ok
      assert_equal(expected_card_types_data, card_types_data)
    end
  end

  test 'chart_data_should_return_tags_data' do
    with_new_project do |project|
      project.add_member(@admin)
      project.save!
      project.tags.create!(name: 'some tag')
      project.tags.create!(name: 'projectXTag')
      project.tags.create!(name: 'another tag')
      project.reload

      expected_tags_data = project.tags.sort_by(&:name).collect do |tag|
        {
            'name' => tag.name,
            'color' => tag.color
        }
      end

      get :chart_data, :project_id => project.identifier, :api_version => 'v2', :format => 'json'
      tags_data = JSON.parse(@response.body).with_indifferent_access[:tags].sort_by {|tag| tag[:name]}

      assert_response :ok
      assert_equal(expected_tags_data, tags_data)
    end
  end

  test 'chart_data_should_return_team_data' do
    with_new_project do |project|
      project.add_member(@admin)
      project.save!
      project.reload

      expected_team_data = project.users.collect do |team_member|
        {
            'id' => team_member.id,
            'name' => team_member.name,
            'login' => team_member.login
        }
      end


      get :chart_data, :project_id => project.identifier, :api_version => 'v2', :format => 'json'
      team_data = JSON.parse(@response.body).with_indifferent_access[:team]

      assert_response :ok
      assert_equal(expected_team_data, team_data)
    end
  end

  test 'should display project admins tab to only registered users when toggle is on' do
    MingleConfiguration.overridden_to(:show_all_project_admins => true) do
     project = create_project(name: 'Project 2', users: [@member_user])

      get :index

      assert_select 'a', :text => 'Project admins'

     change_license_to_allow_anonymous_access
     project.update_attribute(:anonymous_accessible, true)
     logout_as_nil

     get :index

     assert_select 'a', {count: 0, text: 'Project admins'}
    end
  end

  test 'should display admins list for users of projects allowing requestable memberships' do
    MingleConfiguration.overridden_to(:show_all_project_admins => true) do
      project = create_project(name: 'Project 2')
      project.update_attribute(:membership_requestable, true)
      login_as_longbob

      get :admins, :project_id => project.identifier

      assert_response :success
      assert_include 'admins-list', @response.body
    end
  end

  test 'should display admins list for registered users of an instance' do
    MingleConfiguration.overridden_to(:show_all_project_admins => true) do
      project = create_project(name: 'Project 2', users:[@member_user])
      project.update_attribute(:membership_requestable, true)
      login_as_member

      get :admins, :project_id => project.identifier

      assert_response :success
      assert_include 'admins-list', @response.body
    end
  end

  test 'should display export data banner when toggled on for saas' do
    MingleConfiguration.overridden_to(:display_export_banner => true, :export_data => false, :multitenancy_mode => true, :saas_env => 'test') do
      get :index

      assert_select "li.export-banner", :count => 1
    end
  end

  test 'should not display export data banner when toggled export data is toggled on' do
    MingleConfiguration.overridden_to(:display_export_banner => true, :export_data => true) do
      get :index

      assert_select "li.export-banner", :count => 0
    end
  end
end
