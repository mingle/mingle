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

class GithubController < ProjectApplicationController

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => [:receive, :create, :list]
  def new
    @github = Github.new
    load_githubs
  end

  def create
    @github = Github.new(params[:github])
    unless @github.valid?
      flash.now[:error] = @github.errors.full_messages.join("<br/>")
      load_githubs
      render :new
      return
    end

    github_user = User.create_or_update_system_user(:login => "github", :name => "github",
                                                    :email => "mingle.saas+github@thoughtworks.com",
                                                    :admin => true, :activated => true)

    mingle_post_url = github_url(:project_id => project.identifier, :api_version => 'v2', :user => github_user.login)

    code = @github.create_webhook(mingle_post_url, github_user)

    if code == 200 || code == 201
      @github.project = project
      @github.save

      flash[:notice] = "Github Webhook created for #{@github.username}/#{@github.repository}"
      @github = Github.new
    else
      flash.now[:error] = "Github Webhook could not be created for #{@github.username}/#{@github.repository}."
    end
    load_githubs
    render :new
  end

  def list
    load_githubs
  end

  def receive
    repository = params["repository"]
    commits = params["commits"]
    commits.try(:each) do |c|
      message = ["Author: [#{c['author']['username']}](mailto:#{c['author']['email']})",
                 c['message'],
                 "commit [#rev-#{truncated_commit_hash(c['id'])}](#{c['url']}) (#{repository['name']})",
                 "Date: #{c['timestamp']}"].join("\n")
      @project.murmurs.create({:body => message, :author => User.current})
    end

    head :ok
  end

  private

  def truncated_commit_hash(commit_hash)
    commit_hash[0..10]
  end

  def load_githubs
    @githubs = Github.find_all_by_project_id(@project.id)
  end

end
