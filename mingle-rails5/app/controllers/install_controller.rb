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

class InstallController < ApplicationController
  skip_before_action :check_user
  skip_before_action :check_need_install
  skip_before_action :check_license
  skip_before_action :check_license_expiration
  skip_before_action :authenticated? #:except => ['register_license']
  skip_around_action :wrap_in_transaction

  skip_before_action :need_to_accept_saas_tos

  def index
    # This endpoint is just to generate path. All request to this end point will go to mingle 2.3.8
  end
end
