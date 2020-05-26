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

module Install
  class InitialSetup

    class << self
      def need_install?
        return false if MingleConfiguration.skip_install_check?

        if Database.need_config?
          logger.info("Need install: database configuration")
          return true
        end
        if Database.need_migration?
          logger.info("Need install: db migration")
          return true
        end
        if !SmtpConfiguration.load
          logger.info("Need install: smtp configuration")
          return true
        end
        if MingleConfiguration.need_configure_site_url?
          logger.info("Need install: site url")
          return true
        end

        begin
          if User.no_users?
            logger.info("Need install: initial user not created")
            return true
          end

          unless License.eula_accepted?
            logger.info("Need install: eula not accepted")
            return true
          end
          return false
        rescue Exception => e
          logger.info("Need install: Exception when checking if we need to install. Does the database need to be migrated? #{e.message}")
          return true
        end

      end

      def need_migration?
        Database.need_migration?
      end

      def logger
        Rails.logger
      end
    end
  end
end
