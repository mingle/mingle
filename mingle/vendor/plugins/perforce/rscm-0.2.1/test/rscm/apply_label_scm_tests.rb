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

require 'fileutils'

module RSCM
  module GenericSCMTests
    include FileUtils

    def test_apply_label
      work_dir = new_temp_dir
      checkout_dir = "#{work_dir}/checkout"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.create

      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")
      scm.checkout(checkout_dir)

      add_or_edit_and_commit_file(scm, checkout_dir, "before.txt", "Before label")
      scm.apply_label(checkout_dir, "MY_LABEL")
      add_or_edit_and_commit_file(scm, checkout_dir, "after.txt", "After label")
      scm.checkout(checkout_dir, "MY_LABEL")
      assert(File.exist?("#{checkout_dir}/before.txt"))
      assert(!File.exist?("#{checkout_dir}/after.txt"))
    end

  end
end
