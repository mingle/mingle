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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class DeleteVersion < ApplicationRecord
  acts_as_versioned_ext
end

class ArchiveVersion < ApplicationRecord
  acts_as_versioned_ext :keep_versions_on_destroy => true
end

class ActsAsVersionedExtTest < ActiveSupport::TestCase

  def setup
    @connection = ApplicationRecord.connection
    @model_with_dependent_destroy_table  =  DeleteVersion.table_name
    @model_with_out_dependent_destroy_table  =  ArchiveVersion.table_name

    @model_with_dependent_destroy_version_table  =  DeleteVersion.versioned_table_name
    @model_with_out_dependent_destroy_version_table  =  ArchiveVersion.versioned_table_name

    @connection.create_table(@model_with_dependent_destroy_table) do |t|
      t.string :name
      t.string :text
      t.integer :version
    end
    @connection.create_table(@model_with_out_dependent_destroy_table) do |t|
      t.string :name
      t.string :text
      t.integer :version
    end
    DeleteVersion.create_versioned_table
    ArchiveVersion.create_versioned_table
  end

  def teardown
    @connection.drop_table(@model_with_dependent_destroy_table)
    @connection.drop_table(@model_with_out_dependent_destroy_table)
    @connection.drop_table(@model_with_dependent_destroy_version_table)
    @connection.drop_table(@model_with_out_dependent_destroy_version_table)
  end

  def test_version_class_should_extend_form_application_record
    archive_version = ArchiveVersion.create!(name: 'name', text: 'text')

    assert archive_version.versions.first.kind_of?(ApplicationRecord)
  end

  def test_version_class_includes_extension_methods_when_keep_versions_on_destroy_is_true
    archive_version = ArchiveVersion.create!(name: 'name', text: 'text')
    assert archive_version.versions.first.class.include?(ActiveRecord::Acts::ExtensionMethods)
  end

  def test_version_class_does_not_includes_extension_methods_when_keep_versions_on_destroy_is_false
    delete_version = DeleteVersion.create!(name: 'name', text: 'text')
    assert !delete_version.versions.first.class.include?(ActiveRecord::Acts::ExtensionMethods)
  end

  def test_should_not_destroy_versions
    model_with_out_dependent_destroy = ArchiveVersion.create!(name: 'name', text: 'text')
    assert_equal 1, model_with_out_dependent_destroy.versions.count
    model_with_out_dependent_destroy.update_attribute(:text ,'new text')
    assert_equal 2, model_with_out_dependent_destroy.versions.count

    versions = model_with_out_dependent_destroy.versions.to_a
    model_with_out_dependent_destroy.destroy
    assert_equal versions, ArchiveVersion::Version.all.where(name: 'name').to_a
  end

  def test_should_destroy_versions
    model_with_dependent_destroy = DeleteVersion.create!(name: 'name', text: 'text')
    assert_equal 1, model_with_dependent_destroy.versions.count
    model_with_dependent_destroy.update_attribute(:text ,'new text')
    assert_equal 2, model_with_dependent_destroy.versions.count

    model_with_dependent_destroy.destroy
    assert_equal 0, DeleteVersion::Version.all.where(name: 'name').count
  end

end
