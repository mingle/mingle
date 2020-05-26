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

class LicenseAlertMailer < ActionMailer::Base
  include UrlWriterWithFullPath, MailerHelper
  def alert_for_5_licenses_left(params)
    setup_generic_sales_alert_email(params)
    body("<pre style='font-family: sans-serif; font-size: 15px' >#{organization_with_alert_message(params)}
Do they need to purchase new licenses? Give them a nudge! :-)</pre>")
  end

  def alert_for_no_licenses_left(params)
    setup_generic_sales_alert_email(params)
    body("<pre style='font-family: sans-serif; font-size: 15px' >#{organization_with_alert_message(params)}
Surely they need to add more licenses!</pre>")
  end

  private

  def setup_generic_sales_alert_email(params)
    recipients MingleConfiguration.sales_team_email_address
    from default_sender
    content_type "text/html"

    subject "License alert: #{params[:tenant_name]}#{params[:tenant_organization].nil? ? '' : " for #{params[:tenant_organization]}"}"
  end

  def organization_with_alert_message(params)
    "#{params[:tenant_organization]} (<a href=#{params[:tenant_url]}>#{params[:tenant_url]}</a>) has #{params[:alert_message].downcase}."
  end

end
