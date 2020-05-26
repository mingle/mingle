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

class AccountController < ApplicationController
  privileges UserAccess::PrivilegeLevel::REGISTERED_USER  => ['edit', 'update']
  allow :get_access_for => [:edit]

  def edit
    add_monitoring_event(:buy_form_opened)
    @include_planner = CurrentLicense.status.enterprise?
    @buy_tier = CurrentLicense.status.buy_tier
    render_in_lightbox('edit')
  end

  def update
    edition = params['mingle-edition'] == 'plus' ? Registration::ENTERPRISE : Registration::NON_ENTERPRISE
    org = {
      :product_edition => edition,
      :max_active_full_users => params[:max_active_full_users].to_i,
      :buy_at => Clock.now.iso8601
    }

    if org[:max_active_full_users] > Registration::TRIAL_USER_COUNT
      if CurrentLicense.status.expired_in_week? || CurrentLicense.status.free_tier?
        org[:subscription_expires_on] = (Clock.now + 1.week).strftime("%F")
      end
    else
      org[:subscription_expires_on] = (Clock.now + 10.years).strftime("%F")
    end

    CurrentLicense.update!(org)
    unless MingleConfiguration.ask_for_upgrade_email_recipient.blank?
      AccountMailer.deliver_buy(:max_active_full_users => params[:max_active_full_users],
                                :include_planner => edition == Registration::ENTERPRISE,
                                :user => User.current,
                                :contact_email => params[:contact_email],
                                :contact_phone => params[:contact_phone])
    else
      Rails.logger.error("No ask_for_upgrade_email_recipient configured, no email alert sent out")
    end

    add_monitoring_event(:buy_form_submittted)
    update = render_to_string(:partial => 'update')
    render(:update) do |page|
      page.inputing_contexts.update(update)
    end
  end

  def downgrade
    CurrentLicense.downgrade
    add_monitoring_event(:downgraded)
    render(:update) do |page|
      page << "window.location.reload(true)"
    end
  end
end
