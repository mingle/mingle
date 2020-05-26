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

module SetupAndTeardown
  def self.included(base)
    base.class_eval do
      safe_alias_method_chain :run, :clean_env
    end
  end

  def run_with_clean_env(*args, &block)
    all_tests_setup
    run_without_clean_env(*args, &block)
  ensure
    all_tests_teardown
  end

  def all_tests_setup
    Rails.logger.info("#{self.name} started at #{Time.now} ...")
    SetupHelper.clear_caches
    SetupHelper.register_license
    Clock.reset_fake
    logout_as_nil
  end

  def all_tests_teardown
    if self.class.use_transactional_fixtures
      if CardType.find_all_by_project_id(nil).size > 0
        Rails.logger.info "This test(#{self.name}) left a card type that has no project_id value"
      end
      # rollback changes before destroy any project which will commit
      # transaction on Oracle
      ActiveRecord::Base.connection.rollback_db_transaction
      ActiveRecord::Base.connection.begin_db_transaction

      clean_test_db
    end
    Murmur.delete_all
    Project.clear_active_project!

    Rails.logger.info("#{self.name} finished at #{Time.now}...")
  end

  def clean_test_db
    Project.all.reject do |p|
      UnitTestDataLoader.preloaded_project?(p)
    end.each do |project|
      project.with_active_project {project.destroy rescue nil} #rescue project may already been deleted
    end

    User.all.reject do |user|
      UnitTestDataLoader.preloaded_user_logins.include?(user.login)
    end.each(&:destroy)

    Program.all.reject { |program| program.identifier == 'simple_program' }.each(&:destroy)
    Dependency.destroy_all
  end

end
