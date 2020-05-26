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

class GithubTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @member = User.find_by_login('member')
    login_as_member
  end

  def test_create_webhook_successfully_creates
    @github_port = '1156'
    server = start_webrick_server(@github_port) do |request, response|
      response.status = 201
      response['Content-Type'] = 'application/json'
      response.body = {"id" => 2411537}.to_json
    end

    github = Github.new(:username => "bob", :repository => "fun_code", :secret => "super_secret")
    github.github_api_url = "http://localhost:#{@github_port}/"
    mingle_post_url = "http://some_mingle_api/api/v2/projects/#{@project.identifier}/github.json?user=#{@member.login}"

    code = github.create_webhook(mingle_post_url, @member)
    assert_equal 201, code
    assert_equal 2411537, github.webhook_id
  ensure
    server.shutdown rescue nil
  end

  def test_ensures_user_creating_webhook_has_an_api_key
    new_user = create_user!(:login => "no_api_key")
    github = Github.new(:username => "bob", :repository => "fun_code", :secret => "super_secret")

    github.ensure_api_key(new_user)

    assert_not_nil new_user.api_key
  end

  def test_validates_username_and_repository
    assert_false Github.new.valid?
    assert_false Github.new(:username => "username").valid?
    assert_false Github.new(:repository => "reponame").valid?
    assert Github.new(:username => "username", :repository => "reponame").valid?
  end

end
