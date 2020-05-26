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

class MultiMemberSelection

  class << self
    def for_user_selection(project, user_ids)
      members = project.users.find_all_by_id(user_ids)
      deletions = members.collect {|member| ProjectMemberDeletion.for_direct_member(project, member) }
      new(project, members, deletions).tap do |selection|
        selection.extend(MultipleUserDeletion)
      end
    end
  end

  module MultipleUserDeletion
    include PluralizationSupport

    def delete_all
      @deletions.each(&:execute)
      @errors = @deletions.collect(&:deletion_errors).flatten
    end

    def describe
      "remove #{pluralize(@deletions.size, 'member')}"
    end

    def successful_removal_message
      pluralized_member = @deletions.size == 1 ? "member has" : 'members have'
      "#{@deletions.size} #{pluralized_member} been removed from the #{@project.name.bold} team successfully."
    end

    def member_ids
      @members.map(&:id)
    end
  end

  module GroupDeletion
    def delete_all
      @deletions.execute
      @errors = @deletions.collect(&:deletion_errors).flatten
    end

    def describe
      @deletions.describe
    end

    def successful_removal_message
      @deletions.successful_removal_message
    end

    def member_ids
      @members.id
    end
  end

  def initialize(project, members, deletions)
    @project, @members, @deletions = project, members, deletions
  end

  def blank?
    @deletions.blank?
  end

  def no_deletion_warnings?
    @deletions.all?(&:warning_free_destroy?)
  end

  def any_errors?
    !@errors.blank?
  end

  def size
    @deletions.size
  end

  def error_message
    @errors.join(". ")
  end

  def transitions_used
    @transitions_used ||= collection_sorted_by(:transitions_used, :name)
  end

  def transitions_specified
    @transitions_specified ||= collection_sorted_by(:transitions_specified, :name)
  end

  def card_defaults_usages
    return @card_defaults_usages if @card_defaults_usages

    found_items = @deletions.collect(&:card_defaults_usages).flatten.uniq
    @card_defaults_usages ||= found_items.collect(&:card_defaults).flatten.uniq.collect(&:card_type_name).smart_sort
  end

  def project_variable_usage
    @project_variable_usage ||= collection_sorted_by(:project_variable_usage, :name)
  end

  def property_usages
    @property_usages ||= collection_sorted_by(:property_usages, :property_name)
  end

  private
  def collection_sorted_by(collect_sym, sort_sym)
    @deletions.collect(&collect_sym).flatten.uniq.collect(&sort_sym).smart_sort
  end
end
