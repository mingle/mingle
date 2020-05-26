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

class ProgramDependencyView < ActiveRecord::Base
  serialize :params, Hash

  belongs_to :program
  belongs_to :user
  validates_uniqueness_of :user_id, :scope => :program_id

  PARAM_NAMES = [:filter]
  PARAM_VALUES = {
    :filter => ['raising', 'resolving']
  }
  PARAM_DEFAULT_VALUES = {
    :filter => 'resolving'
  }

  PARAM_NAMES.each do |name|
    define_method(name) do
      params[name] || PARAM_DEFAULT_VALUES[name]
    end
  end

  before_create :init_params

  class << self
    def current
      return new(:params => {}) if User.current.anonymous?
      find_or_create_by_user_id(User.current.id)
    end
  end

  def resolving?
    self.filter == "resolving"
  end

  def projects
    return program.projects if self.params[:project_ids].blank?
    program.projects.find(:all, :conditions => ["#{Project.quoted_table_name}.id in (?)", self.params[:project_ids]])
  end

  def project_ids=(ids)
    return if ids.blank?
    self.params[:project_ids] = program.projects.map(&:id) & ids.map(&:to_i)
  end

  def update_params(params)
    PARAM_NAMES.each do |name|
      self.params[name] = params[name] if PARAM_VALUES[name].include?(params[name])
    end
    self.project_ids = params[:project_ids]
    self.save! if self.user_id
    self
  end

  def dependencies_for(project, status)
    deps = self.resolving? ? project.resolving_dependencies : project.raised_dependencies
    deps.select {|dep| dep.status == status}
  end

  def project
    Program.current
  end

  def requires_tree?
    false
  end

  def page
    nil
  end

  def style
    false
  end

  def to_params
    {}
  end

  private
  def init_params
    self.params ||= {}
  end
end
