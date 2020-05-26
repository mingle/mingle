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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class ActsAsAttachableTest < ActiveSupport::TestCase
  def test_attachable_should_be_validated_failed_if_create_attachment_failed
    login_as_member
    with_first_project do |project|
      card = project.cards.new(:name => 'new card', :card_type_name => 'Card')

      attachment = Attachment.new(:file => nil, :project => project)
      card.attachings << card.attachings.new(:attachment => attachment)

      assert !card.save
      assert !card.errors.empty?
    end
  end

  def test_invalid_attachable_removal_name_is_notified_as_model_error
    login_as_member
    with_first_project do |project|
      card = project.cards.new(:name => 'new card', :card_type_name => 'Card')
      card.attach_files(sample_attachment('1.txt'), sample_attachment('2.txt')) # attachments, attachments_1

      assert_false card.remove_attachment('3.txt')
      assert_equal 1, card.errors.size
      assert_equal "Could not find attachment 3.txt in [\"1.txt\", \"2.txt\"]", card.errors.full_messages.first
    end
  end

  def test_attachments_cannot_be_removed_from_older_versions
    login_as_member
    with_first_project do |project|
      card = project.cards.new(:name => 'new card', :card_type_name => 'Card')
      card.attach_files(sample_attachment('1.txt'))
      card.save!

      card.attach_files(sample_attachment('2.txt'))
      card.save!

      previous_version = card.previous_version_or_nil
      assert_raise RuntimeError do
        assert_false previous_version.remove_attachment('1.txt')
      end
    end
  end

  def test_remove_all_attachings_when_file_name_is_star
    login_as_member
    with_first_project do |project|
      card = project.cards.new(:name => 'new card', :card_type_name => 'Card')
      card.attach_files(sample_attachment('1.txt'))
      card.save!

      card.attach_files(sample_attachment('2.txt'))
      card.save!

      assert card.remove_attachment('*')

      card.reload

      assert_equal 0, card.attachments.size
    end
  end
end
