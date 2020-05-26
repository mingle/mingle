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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class ProjectVariableMacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_can_render_text_variable
    assert_equal_ignoring_spaces('foo', rendering_for(:data_type => ProjectVariable::STRING_DATA_TYPE, :value => "foo"))
  end

  def test_can_render_text_variable_in_edit_mode
    plv = 'A Project Variable'
    setup_project_variable(@project, :name => plv,
                           :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'foo')
    macro = Nokogiri::HTML::DocumentFragment.parse(render("{{ project-variable name: #{plv}}}", @project, {}, :formatted_content_editor)).css(".macro").first
    assert_equal "foo", macro.text
    assert_equal URI.escape("{{ project-variable name: #{plv}}}"), macro["raw_text"]
  end

  def test_can_render_user_variable
    member = User.find_by_login('member')
    member.update_attribute(:name, "Bobby Member")
    assert_equal_ignoring_spaces('Bobby Member (member)', rendering_for(:data_type => ProjectVariable::USER_DATA_TYPE, :value => member))
  end

  def test_should_escape_user_display_name
    member = User.find_by_login('member')
    member.update_attribute(:name, "<b>123</b>")
    assert_equal_ignoring_spaces('&lt;b&gt;123&lt;/b&gt; (member)', rendering_for(:data_type => ProjectVariable::USER_DATA_TYPE, :value => member))
  end

  def test_can_render_numeric_variable
    assert_equal_ignoring_spaces('23', rendering_for(:data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 23))
  end

  def test_can_render_date_variable
    assert_equal_ignoring_spaces('13 Oct 2008',
      rendering_for(:data_type => ProjectVariable::DATE_DATA_TYPE,
        :value => Date.new(2008, 10, 13), :name => 'first date variable'))
    @project.date_format = '%Y-%m-%d'
    @project.save!
    assert_equal_ignoring_spaces('2007-10-02',
      rendering_for(:data_type => ProjectVariable::DATE_DATA_TYPE,
        :value => Date.new(2007, 10, 2), :name => 'second date variable'))
  end

  def test_can_render_card_variable
    card = @project.cards.find_by_number(4)
    assert_equal('<a href="/projects/first_project/cards/4">#4 another card</a>',
      rendering_for(:data_type => ProjectVariable::CARD_DATA_TYPE, :value => card))
  end

  def test_can_render_card_variable_card_variable
    assert_equal_ignoring_spaces(PropertyValue::NOT_SET,
      rendering_for(:data_type => ProjectVariable::CARD_DATA_TYPE, :value => ""))
  end

  def test_can_render_card_variable_from_another_project
    other_project = with_new_project do |p|
      p.add_member(User.current)
      cross_project_plv_value = p.cards.create!(:name => 'Guess what?', :card_type_name => 'Card', :number => 342)
      setup_project_variable(p, :name => 'card-plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => cross_project_plv_value)
    end
    rendering = render(%{
      {{ project-variable
           name: 'card-plv'
           project: #{other_project.identifier}
      }}
    }, @project)
    assert_equal_ignoring_spaces "<a href=\"/projects/#{other_project.identifier}/cards/342\">#342 Guess what?</a>", rendering
  end

  def test_can_render_variable_specified_with_display_parenthesis
    assert_equal_ignoring_spaces('foo',
      rendering_for(:data_type => ProjectVariable::STRING_DATA_TYPE, :value => "foo",
        :name => 'bar', :name_specified_in_macro => "(bar)"))
  end

  def test_good_error_displayed_when_specified_variable_does_not_exist
    rendered_text = rendering_for(:data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'foo',
      :name => 'bar', :name_specified_in_macro => 'bogus')
    assert_include "Project variable #{'bogus'.bold} does not exist", rendered_text
  end

  def test_works_in_a_body_macro
    setup_project_variable(@project, :name => 'variable foo',
      :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'boo')
    page = @project.pages.create!(:name => 'dashboard', :content => "{% panel-content %}{{ project-variable name: variable foo}}{% panel-content %}")
    page.redcloth = true
    page.convert_redcloth_to_html!
    assert_equal_ignoring_spaces '<div class="dashboard-content">{{ project-variable name: variable foo}}</div>', page.content
  end

  # the thinking is that folks are immediately going to want to nest
  # PLV renderings as values to other macros.  since we will support
  # that in the 2.1 release we must give a useful error messgae.
  pending "drice (Sep 22 2008)"
  def test_good_error_displayed_when_nested_in_another_macro
    macro_text = %{
      {{ table view: {{ project-variable name: Current Iteration Wall }} }}
    }
    puts render(macro_text, @project)
  end

  def test_plvs_with_hyphens_work_with_the_macro
    assert_equal_ignoring_spaces('whoa', rendering_for(:data_type => ProjectVariable::STRING_DATA_TYPE, :value => "whoa", :name => 'hi - there'))
  end

  def test_should_escape_textile_quick_phrase_modifier
    assert_equal_ignoring_spaces 'wh__oa__', rendering_for(:data_type => ProjectVariable::STRING_DATA_TYPE, :value => "wh__oa__", :name => 'foo')
    card = @project.cards.find_by_number(4)
    card.update_attribute(:name, 'another __card__')
    assert_equal('<a href="/projects/first_project/cards/4">#4 another __card__</a>',
      rendering_for(:data_type => ProjectVariable::CARD_DATA_TYPE, :value => card))
  end

  def rendering_for(options)
    options = {:name => 'A Project Variable'}.merge(options)
    setup_project_variable(@project, :name => options[:name],
                           :data_type => options[:data_type], :value => options[:value])
    rendering = render("{{ project-variable name: #{options[:name_specified_in_macro] || options[:name]}}}", @project)
    rendering =~ /(^\<p\>)(.*)(\<\/p\>$)/
    $2 || rendering
  end

end
