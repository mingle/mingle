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

module CardExplorerHelper
  def having_draggable_results?(card_candidates, cards_in_tree)
    !(cards_in_tree.empty? || card_candidates.empty? || (card_candidates - cards_in_tree).empty?)
  end

  def card_link_text(card, truncate_length)
    "#{content_tag(:strong, "##{card.number}")} #{h(truncate(card.name.to_s, :length => truncate_length))}".html_safe
  end

  def result_summary(cards)
    if @cards.total_pages > 1
      "Showing first #{pluralize(@cards.per_page, 'result')} of #{@cards.total_entries}."
    else
      "Showing #{pluralize(@cards.size, 'result')}."
    end
  end

  def number_and_name(card_result)
    "##{card_result.number} #{card_result.name}"
  end

end
