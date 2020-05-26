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

class LicenseAlertPublisher < ActiveRecord::Observer
  observe User

  include Messaging::Base
  include InvitesHelper
  include ActionView::Helpers::TextHelper

  def after_create(_)
    if paid_tenant? && alert_sales_team?
      send_message(LicenseAlertProcessor::QUEUE, [Messaging::SendingMessage.new(
          :tenant_organization => CurrentLicense.registration.company_name,
          :tenant_url => MingleConfiguration.site_url,
          :alert_message => license_alert_message,
          :tenant_name => MingleConfiguration.app_namespace
      )])
    end
  end

  private

  def alert_sales_team?
    [THRESHOLD_FOR_LICENSE_ALERT, 0].include?(number_of_licenses_left)
  end
end

LicenseAlertPublisher.instance
