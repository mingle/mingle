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

class SaasTosController < ApplicationController
  layout 'saas_tos'

  skip_before_action :check_user
  skip_before_action :check_need_install
  skip_before_action :check_license
  skip_before_action :check_license_expiration
  skip_before_action :need_to_accept_saas_tos

  def show
    if SaasTos.accepted?
      redirect_to MINGLE_ROOT_PATH
      return
    end
    render :show
  end

  def accept
    # TODO this methods will be implemented once when we move event tracker model from rails 2.3 to rails 5
    # add_monitoring_event('hit-continue-on-tos')
    SaasTos.accept(User.current)
    redirect_to MINGLE_ROOT_PATH
  end
end
