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

class DataFixesProcessor < Messaging::DeduplicatingProcessor
  QUEUE = "mingle.datafixes"

  class << self
    # allow datafixes to run in non-saas environments
    # this way we can have this job exist in both periodical_tasks.yml and migrator_periodical_tasks.yml
    # without negatively affecting saas or installers
    def run_once_with_migrator_check(options={})
      if MingleConfiguration.installer? || MingleConfiguration.multitenancy_migrator?
        run_once_without_migrator_check
      end
    end

    alias_method_chain :run_once, :migrator_check
  end

  def identity_hash(message)
    {:name => message[:fix]["name"].to_s, :project_ids => message[:fix]["project_ids"].sort}
  end

  def do_process_message(message)
    DataFixes.apply(message[:fix])
  end
end
