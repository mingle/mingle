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
require 'webrick'

class GithubControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller GithubController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @project = first_project
    @project.activate
    @member = login_as_member
    @github_port = "12#{rand(9)}#{rand(9)}"
    @github_settings = {:username => "bob", :repository => "fun_code", :secret => "super_secret"}
    @github_settings.merge!(:github_api_url => "http://localhost:#{@github_port}/")
  end

  def test_creates_github_user_if_none_exists
    server = start_webrick_server(@github_port) do |request, response|
      response.status = 201
      response['Content-Type'] = 'application/json'
      response.body = {"id" => 2411537}.to_json
    end

    assert_nil User.find_by_login("github")

    xhr :post, :create, {:github => @github_settings, :project_id => @project.identifier}

    assert_not_nil User.find_by_login("github")
  ensure
    User.find_by_login("github").destroy_without_callbacks
    server.shutdown
  end

  def test_should_not_create_github_user_if_one_exists
    server = start_webrick_server(@github_port) do |request, response|
      response.status = 201
      response['Content-Type'] = 'application/json'
      response.body = {"id" => 2411537}.to_json
    end

    User.create_or_update_system_user(:login => "github", :name => "github", :email => "mingle.saas+github@thoughtworks.com")
    assert_no_difference "User.count" do
      xhr :post, :create, {:github => @github_settings, :project_id => @project.identifier}
    end
  ensure
    User.find_by_login("github").destroy_without_callbacks
    server.shutdown
  end

  def test_create_should_save_github_webhook_when_successful
    server = start_webrick_server(@github_port) do |request, response|
      response.status = 201
      response['Content-Type'] = 'application/json'
      response.body = {"id" => 2411537}.to_json
    end

    original_count = Github.all.count

    xhr :post, :create, {:github => @github_settings, :project_id => @project.identifier}

    assert_template :new
    assert flash[:notice]
    assert Github.all.count != original_count
    assert_equal 2411537, Github.all.first.webhook_id

  ensure
    server.shutdown
  end

  def test_create_should_throw_an_error_when_webhook_already_exists
    server = start_webrick_server(@github_port) do |request, response|
      response.status = 422
      response['Content-Type'] = 'application/json'
      response.body = {"id" => 2411537}.to_json
    end

    original_count = Github.all.count

    xhr :post, :create, {:github => @github_settings, :project_id => @project.identifier}

    assert_template :new
    assert flash[:error]
    assert Github.all.count == original_count
  ensure
    server.shutdown
  end

  def test_create_should_show_errors_when_github_params_are_invalid
    invalid_settings = {:username => "", :repository => ""}
    xhr :post, :create, {:github => invalid_settings, :project_id => @project.identifier}

    assert_template :new
    assert flash[:error]
  end

  def test_create_new_murmur_on_github_event
    original_count = @project.murmurs.count

    xhr :post, :receive, github_data.merge({:project_id => @project.identifier})
    assert_response :ok
    assert @project.murmurs.count != original_count

    murmur = @project.murmurs.last.murmur
    assert_include "changing for push", murmur
    assert_include "Author: [#{@author['username']}](mailto:#{@author['email']})", murmur
    assert_include "Date: #{@timestamp}", murmur
    assert_include "commit [#rev-#{@id[0..10]}](#{@url}) (#{@repository['name']})", murmur
  end

  def test_create_should_not_fail_on_push_without_commits
    no_commits_push = github_data.merge({:project_id => @project.identifier})
    no_commits_push["commits"] = nil
    xhr :post, :receive, no_commits_push
    assert_response :ok
  end

  def github_data
    @author = {
     "name" => "Sudhindra Rao",
     "email" => "sudhindra.r.rao@gmail.com",
     "username" => "betarelease"
    }
    @timestamp = "2014-04-30T13:57:01-07:00"
    @id = "4fbee7a1ae639e07bd7792da0912bb7e4015a0e1"
    @repository = {"id"=>19327016,"name"=>"test_push","url"=>"https://github.com/betarelease/test_push"}

    @url = "https://github.com/betarelease/#{@repository['name']}/commit/4fbee7a1ae639e07bd7792da0912bb7e4015a0e1"
    { :repository => @repository,
      :commits => [{
        "id" => @id,
        "distinct" => true,
        "message" => "changing for push",
        "timestamp" => @timestamp,
        "url" => @url,
        "author" => @author,
        "committer" => {
          "name" => "Sudhindra Rao",
          "email" => "sudhindra.r.rao@gmail.com",
          "username" => "betarelease"
        },
        "added" => [],
        "removed" => [],
        "modified" => ["README.md" ]
      }]}
  end

end
