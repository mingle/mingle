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

class DataFixesControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller(DataFixesController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    DataFixes.reset
    @fix = FlexibleDataFix.new("name" => "fix_my_data", "description" => "will fix it", "required" => true, "project_ids" => [])
    DataFixes.register(@fix)
    @admin = login_as_admin
    @admin.update_attribute(:system, true)
  end

  def teardown
    Multitenancy.clear_tenants
    MingleConfiguration.multitenancy_migrator = nil
  end

  def test_list_data_fixes
    get :list, :format => "html"
    assert_response :ok
    assert_select "td.name", "fix_my_data"
    assert_select "td.description", "will fix it"

    get :list, :format => "json"
    assert_response :ok
    assert_include({"name" => "fix_my_data", "description" => "will fix it", "project_ids" => [], "queued" => false}, JSON.parse(@response.body))
  end

  def test_apply_data_fix
    post :apply, :fix => @fix.attrs, :format => "html"
    assert @fix.applied?
    assert_redirected_to :action => :data_fixes

    @fix.reset
    assert_false @fix.applied?

    post :apply, :fix => @fix.attrs, :format => "json"
    assert @fix.applied?
    assert_response :ok
  end

  def test_fetch_of_datafix_required
    fix_required = FlexibleDataFix.new("name" => "required_fix", "description" => "will fix it", "required" => true, "project_ids" => [])
    fix_not_required = FlexibleDataFix.new("name" => "not_required_fix", "description" => "will fix it", "required" => false, "project_ids" => [])
    DataFixes.register(fix_required)
    DataFixes.register(fix_not_required)
    get :required, :fix => {:name => fix_required.name}
    assert_response :ok
    assert_equal 'true', @response.body

    get :required, :fix => {:name => fix_not_required.name}
    assert_response :ok
    assert_equal 'false', @response.body

  end
  def test_enqueue_data_fix
    Messaging.enable
    Messaging::Mailbox.sender = Sender.new

    fix = @fix.attrs.merge("queued" => "true")
    post :apply, :fix => fix, :format => "html"
    assert_redirected_to :action => :data_fixes

    entry = Messaging::Mailbox.sender.messages.first
    queue = entry.shift
    message = entry.shift.first

    expected = {:fix => fix}
    assert_equal DataFixesProcessor::QUEUE, queue
    assert_equal expected, message.body_hash
  ensure
    Messaging::Mailbox.sender = Messaging::Gateway.instance
    Messaging.disable
  end

  def test_only_sysadmin_can_access
    MingleConfiguration.overridden_to(:multitenancy_mode => "true", :saas_env => "test") do
      @admin.update_attribute(:system, false)

      get :list, :format => "html"
      assert_response :forbidden

      get :list, :format => "json"
      assert_response :forbidden
    end

    # non-saas should allow only admin
    get :list, :format => "html"
    assert_response :ok

    get :list, :format => "json"
    assert_response :ok

    @admin.update_attribute(:admin, false)
    get :list, :format => "html"
    assert_response :forbidden

    get :list, :format => "json"
    assert_response :forbidden
  ensure
    @admin.update_attribute(:admin, true)
  end

  def test_should_respond_not_found_if_specified_invalid_data_fix
    post :apply, :format => "json"
    assert_response :not_found
    assert_equal "Invalid data fix", @response.body

    post :apply, :fix => {"name" => "does not exist"}, :format => "json"
    assert_response :not_found
    assert_equal "Invalid data fix", @response.body
  end

  private

  class Sender
    attr_accessor :messages
    def send_message(queue_name, messages=[], options={})
      (@messages ||= []) << [queue_name, messages, options]
    end
  end

end
