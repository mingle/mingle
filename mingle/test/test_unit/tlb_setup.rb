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

# HACK: TLB setup gets overridden on loading rake causing the method overloading of run_suite to not work. This makes sure
# that the tlb setup done in tlb-testunit gem (tlb/test_unit/media_inflection.rb) is done again in case the run_suite method now points to the default implementation in the
# test_unit gem. This will ensure a call to TLB will be made to split the tests.

if (defined?(Test::Unit::UI::TestRunnerMediator) && Test::Unit::UI::TestRunnerMediator.instance_method(:run_suite) && Test::Unit::UI::TestRunnerMediator.instance_method(:run_suite_without_tlb))
  if Test::Unit::UI::TestRunnerMediator.instance_method(:run_suite).source_location == Test::Unit::UI::TestRunnerMediator.instance_method(:run_suite_without_tlb).source_location
    class Test::Unit::UI::TestRunnerMediator
      alias_method :run_without_tlb, :run_suite
      remove_method :run_suite

      def run_suite
        register_observers
        prune_suite
        run_without_tlb
      end
    end
  end
end
