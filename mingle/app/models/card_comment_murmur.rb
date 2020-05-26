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

class CardCommentMurmur < Murmur
  belongs_to :origin, :polymorphic => true

  class << self
    # when card is deleted, need to invalidate murmurs caches for all cards that are linked to any of this card's murmured comments
    def invalidate_murmur_cache(project_id, ids)
      return if ids.empty?
      Project.find(project_id).with_active_project do |project|
        murmur_id_col = self.connection.quote_column_name("murmur_id")
        card_id_col = self.connection.quote_column_name("card_id")
        cards = self.connection.execute %Q{
          SELECT c.id
            FROM #{CardMurmurLink.table_name} cml, #{Card.table_name} c
           WHERE cml.#{murmur_id_col} in (#{ids.join(", ")})
             AND cml.#{card_id_col} = c.id
        }

        CardCachingStamp.update(cards.map{|c| c["id"]})
      end
    end
  end

  def stream
    Murmur::Stream.comment(origin)
  end

  def posting_info(view_helper)
    "#{super} from #{describe_origin}"
  end

  def describe_origin
    "#{origin.try(:type_and_number) || 'deleted card'}"
  end
  alias_method :describe_context, :describe_origin

  def reply_card_numbers
    if self.origin
      [self.origin.number].concat(super)
    else
      super
    end
  end

  private

  def origin_for_indexing
    return unless origin_id
    ["##{origin.number}"]
  end

end
