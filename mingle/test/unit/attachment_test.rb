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

class AttachmentTest < ActiveSupport::TestCase  
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_after_upload_the_file_should_exist_under_public
    attachment = Attachment.create!(:file => sample_attachment, :project => @project)
    assert File.exist?("#{root}/public/#{attachment.path}/#{attachment.id}/sample_attachment.txt")
  end

  def test_store_path_should_be_different_everytime
    attachment1 = Attachment.create!(:file => sample_attachment, :project => @project)
    attachment2 = Attachment.create!(:file => sample_attachment, :project => @project)

    assert_not_nil attachment1.path
    assert_not_nil attachment2.path     
    assert_not_equal attachment2.path, attachment1.path
  end

  def test_generate_url
    attachment = Attachment.create!(:file => sample_attachment, :project => @project)
    assert_equal "/#{attachment.path}/#{attachment.id}/sample_attachment.txt", attachment.url    
  end

  def test_remember_original_file_name
    attachment = Attachment.create!(:file => sample_attachment, :project => @project)
    assert_equal 'sample_attachment.txt', attachment.file_name
  end

  def test_attachable_should_not_accept_duplicate_attachments
    card = @project.cards.find_by_number(1)
    card.attach_files(sample_attachment, sample_attachment)
    assert !card.errors.empty?
  end

  # this test is for the case when there is already an attachment on the card and you upload a duplicate one
  def test_attachable_should_accept_duplicate_attachments_appended_and_should_replace_old_attachment_with_new_one
    card =create_card!(:name => "attaching cards")
    card.attach_files(sample_attachment,sample_attachment('1.txt'))
    card.save!

    original_number_of_attachments = card.attachments.size
    card.attach_files(sample_attachment)
    card.save!
    
    original_attachment = card.reload.attachments.detect {|a| a.file_name == sample_attachment.original_filename}
    
    card.attach_files(another_sample_attachment(sample_attachment.original_filename))

    assert card.reload.errors.empty?
    assert original_number_of_attachments, card.attachments.size
    
    new_attachment = card.attachments.detect {|a| a.file_name == sample_attachment.original_filename}
    
    assert FileUtils.compare_file(original_attachment.file, new_attachment.file) != true  # assert files have different contents
  end
  
  def test_should_delete_attaching_when_delete_the_attachement
    card =create_card!(:name => "attaching cards")
    card.attach_files(sample_attachment,sample_attachment('1.txt'))
    card.save!
    
    assert_equal 2, card.attachments.size
    attachment = card.attachments.first
    attachment.destroy
    assert attachment.attachings.empty?
    assert Attaching.find_all_by_attachment_id(attachment.id).empty?
    assert 1, card.attachments.size
  end


  def test_should_not_try_to_do_smart_file_ext_fix
    attachment = Attachment.create!(:file => sample_attachment('1.txt'), :project => @project)
    assert_equal '1.txt', attachment.file_name
  end
  
  def test_attachments_changed_against_uses_more_than_just_number_of_attachments_to_detect_changes
    attachment_one = sample_attachment("attachment1.txt")
    attachment_two = sample_attachment("attachment2.txt")
    
    card = @project.cards.create!(:name => 'card one', :card_type_name => @project.card_types.first.name)
    card.attach_files(attachment_one)
    card.save!
    
    card_two = @project.cards.create!(:name => 'card two', :card_type_name => @project.card_types.first.name)
    card_two.attach_files(attachment_two)
    card_two.save!
    
    assert card.attachments_changed_against?(card_two)
    assert !card.attachments_changed_against?(card)
  end

  def test_should_be_invalid_when_file_is_nil
    attachment = Attachment.new(:file => nil, :project => @project)
    assert !attachment.valid?
  end

  def test_should_convert_plus_to_underscore_in_file_name
    atachment_file = sample_attachment("attachment+1.txt")
    attachment = Attachment.create!(:file => atachment_file, :project => @project)
    assert_equal 'attachment_1.txt', attachment.file_name
  end
  
  def test_should_be_able_find_attachment_base_on_attachable_type
    @project.attachments.each(&:destroy)
    
    attachment_one = sample_attachment("attachment1.txt")
    attachment_two = sample_attachment("attachment2.txt")
    
    card = create_card!(:name => 'acard')
    page = @project.pages.create(:name => 'apage')
    card.attach_files(attachment_one)
    page.attach_files(attachment_two)
    
    assert_equal card.attachments, Attachment.find_by_attachable_types([Card])
    assert_equal (card.attachments + page.attachments).sort_by(&:id), Attachment.find_by_attachable_types([Card, Page]).sort_by(&:id)
  end
  
  def test_find_base_on_attable_type_should_scoped_in_project
    attachment_one = sample_attachment("attachment1.txt")
    
    card = create_card!(:name => 'acard')
    card.attach_files(attachment_one)
        
    with_project_without_cards do |project|
      assert_equal [], project.attachments.find_by_attachable_types([Card])
    end
  end

  def test_file_missing_should_return_false_when_attachment_exists
    attachment = @project.attachments.create! :file => sample_attachment
    assert_equal false, attachment.file_missing?
  end

  def test_file_missing_should_return_true_when_attachment_not_exist
    attachment = @project.attachments.create! :file => sample_attachment
    attachment.write_attribute(:file, 'doesnt_exist')
    attachment.save!
    attachment = Attachment.find attachment.id
    assert_equal true, attachment.file_missing?
  end

  def test_should_put_attachment_in_new_root_attachments_directory_when_existing_root_directories_are_full
    with_tmp_data_dir do
      with_attachments_per_directory(1) do
        assert_equal [], DataDir::Attachments.all_root_directories
        first_attachment = @project.attachments.create! :file => sample_attachment
        assert_equal 'attachments', root_attachment_dir(first_attachment)

        second_attachment = @project.attachments.create! :file => sample_attachment
        assert_equal 'attachments_1', root_attachment_dir(second_attachment)

        third_attachment = @project.attachments.create! :file => sample_attachment
        assert_equal 'attachments_2', root_attachment_dir(third_attachment)
      end
    end
  end

  def test_project_export_import_when_root_attachments_directory_hit_limit
    with_tmp_data_dir do
      with_attachments_per_directory(1) do
        with_new_project do |project|
          @project = project
          card = create_card!(:name => 'card 1')
          card.attach_files(sample_attachment('1.txt'), sample_attachment('2.txt')) # attachments, attachments_1
          card.save!

          assert_equal ['attachments', 'attachments_1'], @project.attachments.collect {|attachment| root_attachment_dir(attachment)}.sort

          @user = User.current
          export_file = create_project_exporter!(@project, @user, :template => false).export
          @project.attachments.create! :file => sample_attachment # attachments_2

          imported_project = create_project_importer!(@user, export_file).process!.reload
          assert_equal ['attachments_3', 'attachments_4'], imported_project.attachments.collect {|attachment| root_attachment_dir(attachment)}.sort
        end
      end
    end
  end

  # only for local verification
  def xtest_performance_of_root_directory_when_attachment_limit_reached
    with_tmp_data_dir do
      30_000.times do |index|
        FileUtils.mkdir_p(root_path("attachments_#{index + 1}"))
      end
      # the first run should be the slowest
      assert_spend_time_less_than(0.5) do
        DataDir::Attachments.root_directory
      end
      assert_spend_time_less_than(0.01) do
        DataDir::Attachments.root_directory
      end
    end
  end

  def assert_spend_time_less_than(time)
    start = Time.now
    yield
    used = Time.now - start
    assert(used < time)
  end

  private
  def with_tmp_data_dir
    tmp_data_dir = File.join(Rails.root, 'tmp', 'data_dir', SecureRandomHelper.random_32_char_hex)
    FileUtils.mkdir_p(tmp_data_dir)
    FileUtils.mkdir_p(tmp_data_dir + '/public')
    origin_data_dir = MINGLE_DATA_DIR
    silence_warnings { Object.const_set "MINGLE_DATA_DIR", tmp_data_dir }
    Attachment.new.file_options[:root_path] = DataDir::Public.directory.pathname
    yield
  ensure
    silence_warnings { Object.const_set "MINGLE_DATA_DIR", origin_data_dir }
    Attachment.new.file_options[:root_path] = DataDir::Public.directory.pathname
    FileUtils.rm_rf(tmp_data_dir)
    DataDir::Attachments.reset
  end

  def with_attachments_per_directory(limit)
    DataDir::Attachments.reset
    DataDir::Attachments.attachments_per_directory = limit
    clear(DataDir::Attachments.all_root_directories)
    yield
  ensure
    clear(DataDir::Attachments.all_root_directories)
    DataDir::Attachments.reset
  end

  def index(path)
    path.split('_').last.to_i
  end
  
  def root_attachment_dir(attachment)
    attachment.path.split('/').first
  end

  def root_path(dir)
    DataDir::DataFileProxy.new(['public', dir]).pathname
  end

  def clear(directories)
    directories.each do |dir|
      path = root_path(dir)
      FileUtils.rm_rf(path)
    end
  end
  
  def root
    File.expand_path(Rails.root)
  end
end
