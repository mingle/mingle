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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class Card::CardRankingTest < ActiveSupport::TestCase
  include CardRankingTestHelper

  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end

  def test_rerank_does_nothing_if_no_rerank_params_exist
    moving_card = create_card!(:name => 'M')

    original_rank = moving_card.rank
    moving_card.rerank(:leading_card_number => nil, :following_card_number => nil)

    assert_equal original_rank, moving_card.reload.rank
  end


  def test_card_created_later_should_have_higher_rank_value
    first_card = create_card!(:name => 'first')
    later_card = create_card!(:name => 'later')
    assert first_card.project_card_rank < later_card.project_card_rank
  end

  def test_insert_after_four_cards
    moving_card = create_card!(:name => 'M')
    card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s) }
    assert_equal ['M', '1', '2', '3'], project_card_names_sorted_by_ranking(@project)

    moving_card.insert_after(card1.reload)
    assert_equal ['1', 'M', '2', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.insert_after(card2.reload)
    assert_equal ['1', '2', 'M', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.insert_after(card3.reload)
    assert_equal ['1', '2', '3', 'M'], project_card_names_sorted_by_ranking(@project)
    moving_card.insert_after(card2.reload)
    assert_equal ['1', '2', 'M', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.insert_after(card1.reload)
    assert_equal ['1', 'M', '2', '3'], project_card_names_sorted_by_ranking(@project)
  end

  def test_insert_before_four_cards
    moving_card = create_card!(:name => 'M')
    card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s) }
    assert_equal ['M', '1', '2', '3'], project_card_names_sorted_by_ranking(@project)

    moving_card.reload.insert_before(card3.reload)
    assert_equal ['1', '2', 'M', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.reload.insert_before(card2.reload)
    assert_equal ['1', 'M', '2', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.reload.insert_before(card1.reload)
    assert_equal ['M', '1', '2', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.reload.insert_before(card2.reload)
    assert_equal ['1', 'M', '2', '3'], project_card_names_sorted_by_ranking(@project)
    moving_card.reload.insert_before(card3.reload)
    assert_equal ['1', '2', 'M', '3'], project_card_names_sorted_by_ranking(@project)
  end

  # bug 11063
  def test_should_not_generate_two_versions_when_updating_a_date_property_on_oracle
    first_card = create_card!(:name => 'first')
    second_card = create_card!(:name => 'second')
    first_card.update_properties('startdate' => Date.parse('01 Jan 2011'))
    first_card.save!
    assert_equal 2, first_card.versions.count
    first_card.rerank(:leading_card_number => second_card.number)
    assert_equal 2, first_card.versions.count
  end

  def test_redistribute_card_rankings
    card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s) }
    card1.update_attribute(:project_card_rank, 1)
    card2.update_attribute(:project_card_rank, 2)
    card3.update_attribute(:project_card_rank, 3)
    Card.redistribute_card_rankings
    card1.reload
    card2.reload
    card3.reload

    assert_equal -11529215046068469760, card1.project_card_rank.to_i
    assert_equal -4611686018427387904, card2.project_card_rank.to_i
    assert_equal 2305843009213693952, card3.project_card_rank.to_i
  end

  def test_should_redistribute_card_rankings_when_rerank_by_leading_card_number_and_cards_rank_are_too_close
    card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s) }
    card1.update_attribute(:project_card_rank, BigDecimal.new("100"))
    card2.update_attribute(:project_card_rank, BigDecimal.new("100") + Card::CardRanking::THRESHOLD)
    card3.update_attribute(:project_card_rank, BigDecimal.new("200"))

    $force_max_sig_figs = 38 # so we can force same behavior in postgres and oracle
    assert_equal 38, Card.sig_figs

    assert Card.should_redistribute?(card1, :leading)

    card3.rerank(:leading_card_number => card1.number)

    card1.reload
    card2.reload
    card3.reload

    assert_equal ['1', '3', '2'], [card1, card2, card3].sort_by(&:project_card_rank).map(&:name)
  ensure
    $force_max_sig_figs = nil
  end

  def test_should_redistribute_card_rankings_when_rerank_by_following_card_number_and_cards_rank_are_too_close
    card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s) }
    card1.update_attribute(:project_card_rank, BigDecimal.new("100"))
    card2.update_attribute(:project_card_rank, BigDecimal.new("100") + Card::CardRanking::THRESHOLD)
    card3.update_attribute(:project_card_rank, BigDecimal.new("200"))

    $force_max_sig_figs = 38 # so we can force same behavior in postgres and oracle
    assert_equal 38, Card.sig_figs

    assert Card.should_redistribute?(card2, :following)

    card3.rerank(:following_card_number => card2.number)

    card1.reload
    card2.reload
    card3.reload

    assert_equal ['1', '3', '2'], [card1, card2, card3].sort_by(&:project_card_rank).map(&:name)
  ensure
    $force_max_sig_figs = nil
  end

end
