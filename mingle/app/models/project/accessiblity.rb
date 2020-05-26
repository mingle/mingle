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

class Project
  module Accessiblity

    def self.included(base)
      base.validate(:validate_membership_update)
      base.extend(SingletonMethods)
      base.send(:include, InstanceMethods)
      base.named_scope :membership_requestables, :conditions => ["membership_requestable = ? AND hidden = ?", true, false]
    end

    module SingletonMethods
      def has_anonymous_accessible_project?
        count(:conditions => {:anonymous_accessible => true}) > 0
      end

      def anonymous_accessible_projects
        all(:conditions => {:anonymous_accessible => true}).smart_sort_by(&:name)
      end

      def disable_all_anonymous_accessible_projects
        find_all_by_anonymous_accessible(true).each{|project| project.update_attribute(:anonymous_accessible, true)}
      end

      def accessible_projects_without_templates_for(user)
        accessible_projects_for(user).reject(&:template?)
      end

      def accessible_projects_for(user)
        return anonymous_accessible_projects.reject(&:hidden) if user.anonymous? || user.api_user?
        projects = if user.admin?
          all
        else
          if CurrentLicense.status.allow_anonymous?
            user.projects.all + anonymous_accessible_projects + auto_enroll_enabled
          else
            user.projects.all + auto_enroll_enabled
          end
        end
        projects.reject(&:hidden?).uniq
      end

      def membership_requestable_projects_for(user)
        return [] if user.anonymous? || user.api_user?
        project_ids = user.project_ids
        return membership_requestables if project_ids.empty?
        membership_requestables.all(:conditions => ["id NOT IN (?)", user.project_ids])
      end

      def accessible_templates_for(user)
        if user.admin?
          DBTemplate.templates.smart_sort_by(&:name)
        else
          user.projects.select(&:template?).reject(&:hidden?).smart_sort_by(&:name)
        end
      end

      def accessible_or_requestables_for(user)
        (accessible_projects_without_templates_for(user) + membership_requestable_projects_for(user)).uniq.smart_sort_by(&:name)
      end
    end

    module InstanceMethods

      def validate_membership_update
        errors.add_to_base('The request a membership feature is not available for templates.') if self.template? && self.membership_requestable?
      end

      def accessible_for?(user)
        return true if user.admin?
        return false if !CurrentLicense.status.valid? && anonymous_accessible? && !user.member_of?(self)
        return true if CurrentLicense.status.allow_anonymous? && anonymous_accessible?

        user.member_of?(self)
      end

      def requestable_for?(user)
        return unless CurrentLicense.status.valid?
        self.membership_requestable? && !user.anonymous? && !user.member_of?(self)
      end

    end
  end
end
