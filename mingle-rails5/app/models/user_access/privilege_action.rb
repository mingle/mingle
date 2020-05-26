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

module UserAccess

  class PrivilegeAction
    attr_reader :controller, :name

    def self.create(action)
      unless action.is_a?(Hash) || action.is_a?(ActionController::Parameters)
        controller, action = action.to_s.split(':')
        action = {:controller => controller, :action => action}
      end
      action = action.symbolize_keys if action.is_a?(Hash)
      new(action[:controller], action[:action])
    end

    def initialize(controller, name)
      @controller = controller.blank? ? Thread.current[:controller_name] : controller
      @name = name || 'index'
    end

    def validate
      raise "There is no controller named #{@controller}." unless Object.const_defined?(controller_class_name)
    end

    def ==(other)
      other && @controller.to_s == other.controller.to_s && name.to_s == other.name.to_s
    end

    alias :eql? :==

    def planner_action?
      return false if @controller.blank?
      controller_class_name.constantize <= PlannerApplicationController
    end

    def dependencies_action?
      return false if @controller.blank?
      controller_class = controller_class_name.constantize

      [DependenciesController, DependenciesImportExportController].any? do |klass|
        controller_class <= klass
      end
    end

    def project_action?
      return false if @controller.blank?
      controller_class_name.constantize <= ProjectApplicationController
    end

    def identifier
      "#{controller}:#{name}"
    end

    def hash
      7 + identifier.hash
    end

    def controller_class_name
      "#{@controller}_controller".classify
    end

    ACTIONS_THAT_ONLY_MINGLE_ADMIN_ACCESSIBLE_WHEN_LICENSE_INVALID = [
      PrivilegeAction.create({:controller => 'under_the_hood', :action => 'index'}),
      PrivilegeAction.create({:controller => 'under_the_hood', :action => 'toggle_logging_level'}),
      PrivilegeAction.create({:controller => 'under_the_hood', :action => 'reindex'}),
      PrivilegeAction.create({:controller => 'license', :action => 'show'}),
      PrivilegeAction.create({:controller => 'license', :action => 'update'}),
      PrivilegeAction.create({:controller => 'users', :action => 'toggle_activate'}),
      PrivilegeAction.create({:controller => 'users', :action => 'destroy'}),
      PrivilegeAction.create({:controller => 'users', :action => 'deletable'}),
      PrivilegeAction.create({:controller => 'users', :action => 'toggle_light'}),
      PrivilegeAction.create({:controller => 'users', :action => 'list'}),
      PrivilegeAction.create({:controller => 'users', :action => 'index'}),
      PrivilegeAction.create({:controller => 'admin', :action => 'index'}),
    ]

    ACTIONS_THAT_ONLY_MINGLE_ADMIN_ACCESSIBLE_WHEN_READONLY_MODE = [
        PrivilegeAction.create({controller: 'exports', :action => 'index'}),
        PrivilegeAction.create({controller: 'exports', :action => 'create'}),
        PrivilegeAction.create({controller: 'exports', :action => 'download'}),
        PrivilegeAction.create({controller: 'users', :action => 'plan'}),
        PrivilegeAction.create({controller: 'users', :action => 'list'}),
        PrivilegeAction.create({controller: 'users', :action => 'index'}),
        PrivilegeAction.create({controller: 'dependencies_import_export', :action => 'index'}),
        PrivilegeAction.create({controller: 'dependencies_import_export', :action => 'create'}),
        PrivilegeAction.create({controller: 'dependencies_import_export', :action => 'download'}),
        PrivilegeAction.create({controller: 'integrations', :action => 'index'}),
        PrivilegeAction.create({controller: 'integrations', :action => 'remove_slack_integration'}),
        PrivilegeAction.create({controller: 'sso_config', :action => 'show'}),
        PrivilegeAction.create({controller: 'sysadmin', :action => 'toggle_show_all_project_admins'})
    ]
  end

end
