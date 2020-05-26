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

module InvitesHelper
  include UserAccess
  include FootBarHelper

  THRESHOLD_FOR_LICENSE_ALERT = 5

  def invites_enabled?
    !MingleConfiguration.sso_enabled? &&
        project_exists? &&
        (CurrentLicense.trial? || project_or_mingle_admin?) &&
        SmtpConfiguration.configured? &&
        authorized?(:controller => "team", :action => "invite_user")
  end

  def project_exists?
    Project.activated? && in_project_context?
  end

  def show_low_on_licenses_alert?
    paid_tenant? &&
        Project.activated? &&
        project_or_mingle_admin? &&
        number_of_licenses_left <= THRESHOLD_FOR_LICENSE_ALERT
  end

  def paid_tenant?
    CurrentLicense.registration.paid? &&
        MingleConfiguration.saas?
  end

  def license_alert_message
    count = number_of_licenses_left <= 0 ? 'No' : number_of_licenses_left
    "#{pluralize(count, 'license')} left"
  end


  def disable_invites_button?
    paid_tenant? && number_of_licenses_left <= 0
  end

  private
  def number_of_licenses_left
    CurrentLicense.registration.full_user_licenses_left
  end

  def project_or_mingle_admin?
    Project.current.member_roles.admin?(User.current)
  end
end
