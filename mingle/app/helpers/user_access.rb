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

  def authorized_options?(options)
    return true unless options
    return true unless Thread.current[:controller_name]
    options.stringify_keys!
    if options && options.has_key?("accessing")
      resource = options.delete("accessing")
      unless authorized?(resource)
        disabling = options.delete('disable_on_access_denied')
        return disabling ? :disabling : false
      end
    end
    return true
  end

  private :authorized_options?

  def on_options_authorized(options, &block)
    case authorized_options?(options)
    when :disabling
      options.merge!('disabled' => 'disabled')
      yield
    when true
      yield
    when false
      ""
    end
  end

  def install_in_progress?
    Thread.current[:controller_name] == 'install'
  end

  def readonly_privileges?
    User.current.anonymous? || (@project && @project.readonly_member?(User.current))
  end

  def authorized?(action)
    deliverable = PrivilegeAction.create(action).project_action? ? @project : @program
    authorized_for?(deliverable, action)
  end

  def authorized_for?(deliverable, action)
    return true if install_in_progress?
    privilege_action = PrivilegeAction.create(action)
    if (User.current.respond_to?( :github? ) && User.current.github? && privilege_action.controller != 'github')
      return false
    end
    return false unless FEATURES.active_action?(privilege_action.controller, privilege_action.name)

    return false if privilege_action.planner_action? && (!CurrentLicense.status.enterprise? || CurrentLicense.status.invalid?)
    return false if privilege_action.dependencies_action? && !CurrentLicense.status.enterprise?

    action_minimum_privilege_level = PrivilegeLevel.find_minimum_privilege_level_for(privilege_action)
    if CurrentLicense.status.valid?
      if MingleConfiguration.readonly_mode?
        handle_readonly_mode(action_minimum_privilege_level, deliverable, action)
      else
        User.current.privilege_level(deliverable) >= action_minimum_privilege_level
      end
    else
      if PrivilegeAction::ACTIONS_THAT_ONLY_MINGLE_ADMIN_ACCESSIBLE_WHEN_LICENSE_INVALID.include?(PrivilegeAction.create(action))
        User.current.admin?
      else
        User.current.license_invalid_privilege_level(deliverable) >= action_minimum_privilege_level
      end
    end
  end

  def self.init(controller, authorizer_actions)
    authorizer_actions.each do |minimum_privilege_level, action_names|
      action_names.each do |action_name|
        PrivilegeLevel.map_minimum_privilege_level({:controller => controller, :action => action_name}, minimum_privilege_level)
      end
    end
  end

  class NotAuthorizedException < StandardError; end
  private

  def handle_readonly_mode(action_minimum_privilege_level, deliverable, action)
    if PrivilegeAction::ACTIONS_THAT_ONLY_MINGLE_ADMIN_ACCESSIBLE_WHEN_READONLY_MODE.include?(PrivilegeAction.create(action))
      User.current.admin? || User.current.system?
    else
      User.current.license_invalid_privilege_level(deliverable) >= action_minimum_privilege_level
    end
  end

end
