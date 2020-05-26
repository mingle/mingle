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

require 'file_validator'

module ActiveRecord
  module Acts
    module Attachable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_attachable
          has_many :attachings, :as => :attachable, :class_name => '::Attaching', :dependent => :destroy
          include ActiveRecord::Acts::Attachable::InstanceMethods

        end
      end

      module InstanceMethods
        include FileValidator

        def attachments
          #todo: in test sometime attaching get nil attachment, see todo in attaching.rb
          attachings.collect{|attaching| attaching.attachment}.compact
        end

        def attach_files(*files)
          reject_empty_files!(files)

          return unless validate_files(files)

          files.each do |file|
            detect_and_delete_attachings(file.original_filename.downcase)

            attachment = Attachment.new(:file => file, :project => project)
            attachings << self.attachings.new(:attachment => attachment)
          end
        end

        def ensure_attachings(*attachment_ids)
          existing = self.attachings.all(:conditions => "attachment_id in (#{attachment_ids.join(", ")})", :select => "attachment_id").map(&:attachment_id).map(&:to_i)

          attachment_ids.each do |id|
            next if existing.include?(id.to_i)
            attachings << self.attachings.new(:attachment_id => id)
          end
        end

        def remove_attachment(file_name)
          if detect_and_delete_attachings(file_name)
            return true
          else
            available_attachments = self.attachings.map { |attaching| attaching.attachment.file_name}
            logger.error("Could not find attachment #{file_name} in #{available_attachments.inspect}")
            self.errors.add_to_base("Could not find attachment #{file_name} in #{available_attachments.inspect}")
            return false
          end
        end

        def validate_files(files)
          no_duplicate_files(files) && no_large_files(files)
        end

        def no_large_files(files)
          errors = validate_attachment_size(files).each do |error|
            self.errors.add_to_base(error)
          end
          errors.empty?
        end

        def no_duplicate_files(files)
          filenames = files.collect {|f| f.original_filename.downcase}
          duplicate = filenames.size != filenames.uniq.size
          self.errors.add_to_base("Sorry, you cannot upload multiple attachments with the same name.") if duplicate
          !duplicate
        end

        def clone_attachings(orig_model, new_model)
          new_model.attachings = orig_model.attachings.collect { |attaching| Attaching.new(:attachment => attaching.attachment) }
        end

        def attachments_changed_against?(another)
          return true if attachments.blank? ^ another.attachments.blank?
          return true unless attachments.size == another.attachments.size

          ids = attachments.collect(&:id).sort
          other_ids = another.attachments.collect(&:id).sort
          return ids != other_ids
        end

        def attachment_changes_against(another)
          if attachments_changed_against?(another)
            if all_attachments_are_new(another)
              return attachments
            elsif another.attachments.all? {|att| att.nil? || att.id.nil?} && attachments.empty?
              return []
            end

            ids = attachments.collect(&:id).sort
            other_ids = another.attachments.collect(&:id).sort
            changed_ids = ids - other_ids
            return attachments.select {|attachment| changed_ids.include?(attachment.id) ? attachment : nil }.compact
          else
            return []
          end
        end

        private

        # file.size almost always comes out as 0 when file is a Tempfile (i.e. when the file is > 10k),
        # so use File.zero? instead
        def reject_empty_files!(files)
          files.reject! do |file|
            file.blank? || (!file.is_a?(Tempfile) && file.size == 0) || (file.is_a?(Tempfile) && File.zero?(file.path))
          end
        end

        def all_attachments_are_new(another)
          attachments.all? {|att| att.nil? || att.id.nil?} && another.attachments.empty?
        end

        def delete_attaching(attaching_to_delete)
          attaching_to_delete.destroy
          self.attachings = self.attachings.reject { |attaching| attaching.id == attaching_to_delete.id }
        end

        def delete_all_attaching
          self.attachings.each(&:destroy)
          self.attachings = []
        end

        def detect_and_delete_attachings(file_name)
          if self.respond_to?(:latest_version?) && !self.latest_version?
            raise "Can only remove attachments from the latest version of an object"
          end
          if (file_name == '*')
            delete_all_attaching
          else
            attaching_to_delete = self.attachings.detect { |attaching| attaching.attachment.file_name.downcase == FileColumn::sanitize_filename(file_name.downcase)}
            if attaching_to_delete
              delete_attaching(attaching_to_delete)
            end
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Attachable)
