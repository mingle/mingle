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
  module Accessibility

    def self.included(base)
      # base.validate(:validate_membership_update)
      base.extend(SingletonMethods)
      # base.send(:include, InstanceMethods)
      # base.named_scope :membership_requestables, :conditions => ["membership_requestable = ? AND hidden = ?", true, false]
    end

    module SingletonMethods


      def anonymous_accessible_projects
        #TODO need to look into this
        all.where(anonymous_accessible: true).to_a.smart_sort_by(&:name)
      end

      def accessible_projects_for(user)
        return anonymous_accessible_projects.reject(&:hidden) if user.anonymous? || user.api_user?
        projects = if user.admin?
          all
        else
          if CurrentLicense.status.allow_anonymous?
            user.projects.all + anonymous_accessible_projects
          else
            user.projects.all
          end
        end
        projects.reject(&:hidden?)
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
