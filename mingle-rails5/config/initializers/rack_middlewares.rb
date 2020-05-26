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

Rails.application.configure do |config|
  config.middleware.insert_after(ActionDispatch::DebugExceptions, Middlewares::GlobalConfigManagement)
  # This is done intentionally as we don't need rails migration check.
  # We already have an migration check on application controller filter label for installer and a dedicated migrator for saas.
  config.middleware.delete(ActiveRecord::Migration::CheckPending)

  if MingleConfiguration.multitenancy_mode?
    config.middleware.insert_after(Middlewares::GlobalConfigManagement, Middlewares::TenantManagement)
    config.middleware.insert_after(Middlewares::GlobalConfigManagement, Middlewares::Maintenance)
  end

  if MingleConfiguration.request_timeout
    Middlewares::TimeoutHandlingMiddleware.timeout = MingleConfiguration.request_timeout.to_i
    if Middlewares::TimeoutHandlingMiddleware.timeout < 5
      Rails.logger.warn('Please consider setup request timeout more than 5 seconds')
      Middlewares::TimeoutHandlingMiddleware.timeout = 5
    end
    Rails.logger.info("Setup request timeout middleware, timeout: #{Middlewares::TimeoutHandlingMiddleware.timeout} seconds")
    # we setup this middleware before alarm, so that we can get notified
    # by alarm
    config.middleware.insert_after(ActionDispatch::DebugExceptions,
                                   Middlewares::TimeoutHandlingMiddleware)
  end

  config.middleware.insert_after(ActionDispatch::DebugExceptions,
                                 Middlewares::ThreadLocalsSweeper) unless Rails.env.test?
# Todo: Move when migrating Slack code
# this should run after tenant switching
# require 'slack/redirect_middleware'
end
