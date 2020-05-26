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

class EffectTest < ActiveSupport::TestCase
  def test_render_for_simple_model_usage
    assert_equal "Used by #{'1 Card'.bold}.", Deletion::Effect.new(Card, :count =>  1).render
    assert_equal "Used by #{'2 Cards'.bold}.", Deletion::Effect.new(Card, :count => 2).render
  end
  
  def test_render_with_concrete_collections
    assert_equal "Used by #{'1 Transition'.bold}: #{'a'.bold}.", Deletion::Effect.new(Transition, :collection => [Transition.new(:name => 'a')]).render
    
    assert_equal "Used by #{'2 Transitions'.bold}: #{'a'.bold} and #{'b'.bold}.", Deletion::Effect.new(Transition, :collection => [Transition.new(:name => 'a'), Transition.new(:name => 'b')]).render
    
    assert_equal "Used by #{'3 Transitions'.bold}: #{'a'.bold}, #{'b'.bold}, and #{'c'.bold}.", Deletion::Effect.new(Transition, :collection => [Transition.new(:name => 'a'), Transition.new(:name => 'b'), Transition.new(:name => 'c')]).render    
  end

  def test_should_raise_exception_when_did_not_provide_count_and_collection
    assert_raise(RuntimeError) { Deletion::Effect.new(Card) }
  end
  
  def test_render_simple_model_usage_with_additional_notes
    assert_equal "Used by #{'1 Card'.bold}. <div class=\"bullet-qualifier\">important info</div>", Deletion::Effect.new(Card, :count => 1, :additional_notes => 'important info').render    
  end
  
  def test_render_collection_with_additional_notes
    assert_equal "Used by #{'1 Transition'.bold}: #{'a'.bold}. <div class=\"bullet-qualifier\">important info</div>", Deletion::Effect.new(Transition, :collection => [Transition.new(:name => 'a')], :additional_notes => 'important info').render    
  end
  
  def test_render_collection_with_action_will_be_taken
    assert_equal "Used by #{'1 Transition'.bold}: #{'a'.bold}. This will be deleted.", Deletion::Effect.new(Transition, :collection => [Transition.new(:name => 'a')], :action => 'deleted').render
  end
  
  def test_render_collection_action_should_pluralized
    assert_equal "Used by #{'2 Transitions'.bold}: #{'a'.bold} and #{'b'.bold}. These will be deleted.", Deletion::Effect.new(Transition, :collection => [Transition.new(:name => 'a'), Transition.new(:name => 'b')], :action => 'deleted').render
  end

end
