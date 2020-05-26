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

class Card::Comment

  class MurmurFacade
    include MurmurReplyTemplate
    attr_reader :id, :origin, :author, :created_at, :murmur, :describe_origin

    def initialize(comment, version)
      @id = "version-#{version.version}"
      @origin = version.card
      @author = comment.created_by
      @created_at = comment.created_at
      @murmur = comment.content
      @describe_origin = version.card.type_and_number
    end

    def project
      Project.current
    end

    def user_mentions
      @mention ||= MurmurUserMentions.new(project, self.murmur)
    end

    def origin_id
      @origin.id
    end

    def mentioned_current_user?
      MurmurUserMentions.new(project, self.murmur).users.include?(User.current)
    end

    def user_display_name
      @author.try(:name)
    end
  end

  include ::API::XMLSerializer
  serializes_as :complete => [:content, :created_by, :created_at], :element_name => 'comment'
  compact_at_level 0

  def initialize(card, attributes)
    @card = card
    @attributes = attributes
  end

  def content
    @attributes[:content].strip
  end

  def blank?
    content.blank?
  end

  def store_to(version)
    return if blank?
    version.comment = content
    CardCommentMurmur.create(:project_id => @card.project_id, :murmur => content, :author_id => created_by.id, :origin => @card, :replying_to_murmur_id => @attributes[:replying_to_murmur_id], :source => @attributes[:source])
  end

  def created_by
    @card.modified_by
  end

  def created_at
    @card.updated_at
  end

  def full_text_search_index_string
    %{ #{content} #{created_by.full_text_search_index_string} }
  end

  def murmur_like
    MurmurFacade.new(self, @card)
  end
end
