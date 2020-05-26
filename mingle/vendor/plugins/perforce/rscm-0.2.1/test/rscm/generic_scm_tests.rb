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
require 'rscm/tempdir'
require 'rscm/path_converter'

module RSCM

  module GenericSCMTests
    include FileUtils

    # Acceptance test for scm implementations
    #
    #  1) Create a repo
    #  2) Import a test project
    #  3) Verify that CheckoutHere is not uptodate
    #  4) Check out to CheckoutHere
    #  5) Verify that the checked out files were those imported
    #  6) Verify that the initial total changesets (from epoch to infinity) represents those from the import
    #  7) Verify that CheckoutHere is uptodate
    #  8) Change some files in DeveloperOne's working copy
    #  9) Check out to CheckoutHereToo
    # 10) Verify that CheckoutHereToo is uptodate
    # 11) Verify that CheckoutHere is uptodate
    # 12) Commit modifications in CheckoutHere is uptodate
    # 13) Verify that CheckoutHere is uptodate
    # 14) Verify that CheckoutHereToo is not uptodate
    # 15) Check out to CheckoutHereToo
    # 16) Verify that CheckoutHereToo is uptodate
    # 17) Add and commit a file in CheckoutHere
    # 18) Verify that the changeset (since last changeset) for CheckoutHereToo contains only one file
    def test_basics
      work_dir = RSCM.new_temp_dir("basics")
      checkout_dir = "#{work_dir}/CheckoutHere"
      other_checkout_dir = "#{work_dir}/CheckoutHereToo"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.create
      assert(scm.name)

      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")

      # test twice - to verify that uptodate? doesn't check out.
      assert(!scm.uptodate?(checkout_dir, Time.new.utc))
      assert(!scm.uptodate?(checkout_dir, Time.new.utc))
      yielded_files = []
      files = scm.checkout(checkout_dir) do |file_name|
        yielded_files << file_name
      end

      assert_equal(4, files.length)
      assert_equal(files, yielded_files)
      files.sort!
      yielded_files.sort!
      assert_equal(files, yielded_files)

      assert_equal("build.xml", files[0])
      assert_equal("project.xml", files[1])
      assert_equal("src/java/com/thoughtworks/damagecontrolled/Thingy.java", files[2])
      assert_equal("src/test/com/thoughtworks/damagecontrolled/ThingyTestCase.java", files[3])

      initial_changesets = scm.changesets(checkout_dir, nil, nil)
      assert_equal(1, initial_changesets.length)
      initial_changeset = initial_changesets[0]
      assert_equal("imported\nsources", initial_changeset.message)
      assert_equal(4, initial_changeset.length)
      assert(scm.uptodate?(checkout_dir, initial_changesets.latest.time + 1))

      # modify file and commit it
      change_file(scm, "#{checkout_dir}/build.xml")
      change_file(scm, "#{checkout_dir}/src/java/com/thoughtworks/damagecontrolled/Thingy.java")

      scm.checkout(other_checkout_dir)
      assert(scm.uptodate?(other_checkout_dir, Time.new.utc))
      assert(scm.uptodate?(checkout_dir, Time.new.utc))

      scm.commit(checkout_dir, "changed\nsomething")

      # check that we now have one more change
      changesets = scm.changesets(checkout_dir, initial_changesets.time + 1)

      assert_equal(1, changesets.length, changesets.collect{|cs| cs.to_s})
      changeset = changesets[0]
      assert_equal(2, changeset.length)

      assert_equal("changed\nsomething", changeset.message)

      # why is this nil when running as the dcontrol user on codehaus? --jon
      #assert_equal(username, changeset.developer)
      assert(changeset.developer)
      assert(changeset.identifier)

      assert_equal("build.xml", changeset[0].path)
      assert(changeset[0].revision)
      assert(changeset[0].previous_revision)
      assert_equal("src/java/com/thoughtworks/damagecontrolled/Thingy.java", changeset[1].path)
      assert(changeset[1].revision)
      assert(changeset[1].previous_revision)

      assert(!scm.uptodate?(other_checkout_dir, changesets.latest.time+1))
      assert(!scm.uptodate?(other_checkout_dir, changesets.latest.time+1))
      assert(scm.uptodate?(checkout_dir, changesets.latest.time+1))
      assert(scm.uptodate?(checkout_dir, changesets.latest.time+1))

      files = scm.checkout(other_checkout_dir).sort
      assert_equal(2, files.length)
      assert_equal("build.xml", files[0])
      assert_equal("src/java/com/thoughtworks/damagecontrolled/Thingy.java", files[1])

      assert(scm.uptodate?(other_checkout_dir, Time.new.utc))

      add_or_edit_and_commit_file(scm, checkout_dir, "src/java/com/thoughtworks/damagecontrolled/Hello.txt", "Bla bla")
      assert(!scm.uptodate?(other_checkout_dir, Time.new.utc))
      changesets = scm.changesets(other_checkout_dir, changesets.time + 1)
      assert_equal(1, changesets.length)
      assert_equal(1, changesets[0].length)
      assert("src/java/com/thoughtworks/damagecontrolled/Hello.txt", changesets[0][0].path)
      assert("src/java/com/thoughtworks/damagecontrolled/Hello.txt", scm.checkout(other_checkout_dir).sort[0])
    end

    def test_trigger
      work_dir = RSCM.new_temp_dir("trigger")
      path = "OftenModified"
      checkout_dir = "#{work_dir}/#{path}/checkout"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, path)
      scm.create

      trigger_files_checkout_dir = File.expand_path("#{checkout_dir}/../trigger")
      trigger_command = "bla bla"
      (1..3).each do
        assert(!scm.trigger_installed?(trigger_command, trigger_files_checkout_dir))
        scm.install_trigger(trigger_command, trigger_files_checkout_dir)
        assert(scm.trigger_installed?(trigger_command, trigger_files_checkout_dir))
        scm.uninstall_trigger(trigger_command, trigger_files_checkout_dir)
      end
    end

    def test_checkout_changeset_identifier
      work_dir = RSCM.new_temp_dir("label")
      checkout_dir = "#{work_dir}/checkout"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.create

      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")
      scm.checkout(checkout_dir)
      add_or_edit_and_commit_file(scm, checkout_dir, "before.txt", "Before label")
      before_cs = scm.changesets(checkout_dir, Time.epoch)

      add_or_edit_and_commit_file(scm, checkout_dir, "after.txt", "After label")
      next_identifier = before_cs.latest.identifier + 1
      after_cs = scm.changesets(checkout_dir, next_identifier)
      assert_equal(1, after_cs.length)
      assert_equal("after.txt", after_cs[0][0].path)

      scm.checkout(checkout_dir, before_cs.latest.identifier)

      assert(File.exist?("#{checkout_dir}/before.txt"))
      assert(!File.exist?("#{checkout_dir}/after.txt"))
    end

    def test_should_allow_creation_with_empty_constructor
      scm = create_scm(RSCM.new_temp_dir, ".")
      scm2 = scm.class.new
      assert_same(scm.class, scm2.class)
    end

    def test_diff
      work_dir = RSCM.new_temp_dir("diff")
      path = "diffing"
      checkout_dir = "#{work_dir}/#{path}/checkout"
      repository_dir = "#{work_dir}/repository"
      import_dir = "#{work_dir}/import/diffing"
      scm = create_scm(repository_dir, path)
      scm.create

      mkdir_p(import_dir)
      File.open("#{import_dir}/afile.txt", "w") do |io|
        io.puts("one two three")
        io.puts("four five six")
      end
      File.open("#{import_dir}/afile.txt", "w") do |io|
        io.puts("")
      end

      scm.import(import_dir, "Imported a file to diff against")
      scm.checkout(checkout_dir)

      scm.edit("#{checkout_dir}/afile.txt")
      File.open("#{checkout_dir}/afile.txt", "w") do |io|
        io.puts("one two three four")
        io.puts("five six")
      end
      File.open("#{checkout_dir}/anotherfile.txt", "w") do |io|
        io.puts("one quick brown")
        io.puts("fox jumped over")
      end
      scm.commit(checkout_dir, "Modified file to diff")

      scm.edit("#{checkout_dir}/afile.txt")
      File.open("#{checkout_dir}/afile.txt", "w") do |io|
        io.puts("one to threee")
        io.puts("hello")
        io.puts("four five six")
      end
      File.open("#{checkout_dir}/anotherfile.txt", "w") do |io|
        io.puts("one quick brown")
        io.puts("fox jumped over the lazy dog")
      end
      scm.commit(checkout_dir, "Modified file to diff again")

      changesets = scm.changesets(checkout_dir, Time.epoch)
    end

  private

    def import_damagecontrolled(scm, import_copy_dir)
      mkdir_p(import_copy_dir)
      path = File.dirname(__FILE__) + "/../../testproject/damagecontrolled"
      path = File.expand_path(path)
      dirname = File.dirname(import_copy_dir)
      cp_r(path, dirname)
      todelete = Dir.glob("#{import_copy_dir}/**/.svn")
      rm_rf(todelete)
      scm.import(import_copy_dir, "imported\nsources")
    end

    def change_file(scm, file)
      file = File.expand_path(file)
      scm.edit(file)
      File.open(file, "w+") do |io|
        io.puts("changed\n")
      end
    end

    def add_or_edit_and_commit_file(scm, checkout_dir, relative_filename, content)
      existed = false
      absolute_path = File.expand_path("#{checkout_dir}/#{relative_filename}")
      FileUtils.mkpath(File.dirname(absolute_path))
      existed = File.exist?(absolute_path)
      File.open(absolute_path, "w") do |file|
        file.puts(content)
      end
      scm.add(checkout_dir, relative_filename) unless(existed)

      message = existed ? "editing" : "adding"

      sleep(1)
      scm.commit(checkout_dir, "#{message} #{relative_filename}")
    end
  end

  module LabelTest
    def test_label
      work_dir = RSCM.new_temp_dir("label")
      checkout_dir = "#{work_dir}/LabelTest"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.create

      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")

      scm.checkout(checkout_dir)

      # TODO: introduce a Revision class which implements comparator methods
      assert_equal(
        "1",
        scm.label(checkout_dir)
      )
      change_file(scm, "#{checkout_dir}/build.xml")
      scm.commit(checkout_dir, "changed something")
      scm.checkout(checkout_dir)
      assert_equal(
        "2",
        scm.label(checkout_dir)
      )
    end
  end

  module ApplyLabelTest

  end
end
