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

# --------------------------------------------------------------
# To setup an experiment do
#  ABTesting.add_experiments('exp1', 'exp2')
#
# To put your instance go to a specific group in local testing
#  in jruby set system property -Dmingle.ABTesting.exp1=group_b
#  in mri set environment variable MINGLE_AB_TESTING_EXP1=group_b
#
# You can verify ab testing setup for any instance by calling
#   /api/v2/abtesting_info.xml
# --------------------------------------------------------------

class ABTesting
  extend MingleConfiguration::HasConfigureOptions
  GROUPS = ['group_a', 'group_b']

  class << self
    def add_experiments(*experiment_names)
      define_config_opts('mingle.ABTesting', experiment_names, [])
    end

    def overridden_group_info(options, &block)
      defined_experiment_groups = options.select do |exp, group|
        defined_experiment?(exp)
      end
      self.overridden_to(defined_experiment_groups, &block)
    end

    def assign_groups
      defined_experiments.inject({}) do |memo, experiment|
        memo[experiment] = GROUPS.shuffle.first
        memo
      end
    end

    def group_info
      defined_experiments.inject({}) do |memo, experiment|
        memo[experiment] = experiment_group(experiment)
        memo
      end
    end

    def in_experimental_group?(experiment)
      "group_b" == experiment_group(experiment)
    end

    def experiment_group(experiment)
      defined_experiment?(experiment)  && self.send(experiment)
    end

    private

    def defined_experiment?(experiment)
      defined_experiments.include?(experiment)
    end

    def defined_experiments
      self.config_opts_keys
    end
  end

end
