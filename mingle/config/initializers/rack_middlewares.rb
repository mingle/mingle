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

#todo: move all middleware initializations to here please
require "timeout_handling_middleware"
require 'thread_locals_sweeper'
require 'middlewares/maintenance'

ActionController::Dispatcher.middleware.insert_after(ActionController::Failsafe, GlobalConfigManagement)

if MingleConfiguration.multitenancy_mode?
  ActionController::Dispatcher.middleware.insert_after(GlobalConfigManagement, Multitenancy::TenantManagement)
  ActionController::Dispatcher.middleware.insert_after(GlobalConfigManagement, Middlewares::Maintenance)
end


if MingleConfiguration.request_timeout
  TimeoutHandlingMiddleware.timeout = MingleConfiguration.request_timeout.to_i
  if TimeoutHandlingMiddleware.timeout < 5
    Rails.logger.warn("Please consider setup request timeout more than 5 seconds")
    TimeoutHandlingMiddleware.timeout = 5
  end
  Rails.logger.info("Setup request timeout middleware, timeout: #{TimeoutHandlingMiddleware.timeout} seconds")
  # we setup this middelware before alarm, so that we can get notified
  # by alarm
  ActionController::Dispatcher.middleware.insert_after(ActionController::Failsafe,
                                                       TimeoutHandlingMiddleware)
end

ActionController::Dispatcher.middleware.insert_after(ActionController::Failsafe,
                                                     ThreadLocalsSweeper)
# this should run after tenant switching
require 'slack/redirect_middleware'
