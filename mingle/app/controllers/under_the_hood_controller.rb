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

class UnderTheHoodController < ApplicationController
  before_filter :disable_in_multitenat

  allow :get_access_for => [:index],
        :put_access_for => [:toggle_logging_level]

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN => ["index", "toggle_logging_level", "force_bg"]

  SPECIAL_LOGGERS = { :search => { :name => 'elasticsearch', :namespace => 'org' } }

  def index
    @title = "Under the Hood"
    @specific_loggers_status = loggers
  end

  def toggle_logging_level
    logger = logger_for(params[:logger])
    logger.debug? ? logger.level = Logger::INFO : logger.level = Logger::DEBUG
    redirect_to :action  => "index"
  end

  def force_bg
    bg = params[:task_name].constantize
    batch_size = 1
    if params[:batch_size]
      batch_size = params[:batch_size].to_i
    end
    bg.run_once(:batch_size => batch_size)
    redirect_to :action => :index, :task_name => params[:task_name]
  end

  private
  def logger_for(name)
    loggers[name]
  end

  def loggers
    @loggers ||= ["jobs", "pool", "servlet", "murmurs", :search].inject({ '' => root_logger})  do |h, name|
      logger_options = if Symbol === name
        SPECIAL_LOGGERS[name] || raise("Unable to understand logger #{name}")
      else
        {:name => name, :namespace => LOG_NAMESPACE}
      end
      h[name.to_s] = Log4j::Logger.new(logger_options)
      h
    end
  end

  def root_logger
    Log4j::Logger.new(:namespace => LOG_NAMESPACE)
  end

  def disable_in_multitenat
    if MingleConfiguration.multitenancy_migrator? || MingleConfiguration.multitenancy_mode?
      head(:not_found)
    end
  end
end
