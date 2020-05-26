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

class ProjectMemberDeletion

  class << self
    def for_direct_member(project, member)
      ForUser.new(project, member)
    end
  end

  class ForUser
    def execute
      destroy_membership.tap { |success| cleanup if success }
    end

    def cleanup
      # TODO IMPORTANT need to uncomment this section whenever we get the test from 2.3
      # if project.is_a?(Project)
      #   remove_associated_user_project_variables
      #   update_releated_view
      #   remove_members_that_assigned_to_transition
      #   clean_user_property_value_usage
      #   destroy_history_subscriptions
      #   destroy_personal_favorites
      #   destroy_transtions_that_used
      # end
      clear_member_roles
      cleanup_group_memberships
    end

    def deletion_errors
      @deletion_errors || []
    end

    def warning_free_destroy?
      property_usages.empty? && card_defaults_usages.empty? && transitions_used.empty? && transitions_specified.empty? && project_variable_usage.empty?
    end

    def destroy_membership
      @deletion_errors = @project.team.validate_for_removal(@user)
      return false unless @deletion_errors.empty?
      @project.team.remove_member(@user)
    end

    def project_variable_usage
      ProjectVariable.variables_that_use_user(project, user)
    end

    def transitions_specified
      Transition.find_any_specifying_user(user, :project => project) - Transition.find_all_using_member(user, :project => project)
    end

    def property_usages
      user_property_usages(:card_usage)
    end

    def card_defaults_usages
      user_property_usages(:card_defaults_usage)
    end

    def transitions_used
      Transition.find_all_using_member(user, :project => project)
    end

    def clean_user_property_value_usage
      (property_usages + card_defaults_usages).each(&:clean)
    end

    def remove_associated_user_project_variables
      project.project_variables.each do |variable|
        variable.clear_team_member(user)
      end
    end

    def remove_members_that_assigned_to_transition
      project.transitions.each{|transition| transition.remove_specified_to_user(user)}
    end

    def destroy_history_subscriptions
      project.history_subscriptions.each do |history_subscription|
        history_subscription.destroy if (!user.admin? && history_subscription.user_id == user.id) || history_subscription.uses_user?(user)
      end
    end

    def destroy_personal_favorites
      user.personal_views_for(project).each(&:destroy) if !user.admin?
    end

    def update_releated_view
      UserFilterUsage.card_list_views(project, user.id).each do |view|
        project.user_property_definitions_with_hidden.each do |user_prop|
          view.rename_property_value(user_prop.name, user.login, '')
          view.save
        end
      end
    end

    def destroy_transtions_that_used
      transitions_used.each(&:destroy)
    end

    def clear_member_roles
      project.member_roles.destroy_for_member(user)
    end

    def cleanup_group_memberships
      project.groups_for_member(user).each {|g| g.remove_member(user)}
    end

    private
    attr_reader :project, :user

    def initialize(project, user)
      @project, @user = project, user
    end

    def user_property_usages(type)
      @usages ||= load_user_property_usages
      @usages[type]
    end

    def load_user_property_usages
      usages = {:card_usage => [], :card_defaults_usage => []}
      project.user_property_definitions_with_hidden.each do |user_def|
        property_value = PropertyValue.create_from_db_identifier(user_def, user.id)
        usages.keys.each do |key|
          usage = property_value.send(key)
          if !usage.empty?
            usages[key] << usage
          end
        end
      end
      usages
    end
  end
end
