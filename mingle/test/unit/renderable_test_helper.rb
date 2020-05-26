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

module RenderableTestHelper

  include ActionView::Helpers::TextHelper, ActionView::Helpers::TagHelper, ActionView::Helpers::AssetTagHelper, ActionView::Helpers::UrlHelper, ActionController::Assertions::DomAssertions # allows us to have things like assert_messages_for_queue_equal in our model tests

  def create_raw_macro_markup(macro)
    element = Nokogiri::HTML::DocumentFragment.parse("<div>your macro will render on save</div>").elements.first
    element["raw_text"] = URI.escape(macro)
    element["class"] = "macro"
    element.to_xhtml
  end

  def assert_dom_equal_with_ignore_whitespace(expected, actual)
     assert_dom_equal_without_ignore_whitespace(expected.squish, actual.squish)
  end
  alias_method_chain :assert_dom_equal, :ignore_whitespace

  module SingletonMethods

    def default_url_options
      {:host => 'example.com'}
    end

  end

  class DummyScriptTagMacro < Macro
    def execute
      "DUMMY #{name} #{parameters.sort} <script type='text/javascript'>alert('hello');</script>"
    end
  end

  class DummyMacro < Macro
    def execute
      "DUMMY #{name} #{parameters.sort.join}"
    end
  end

  class DummyBodyMacro < Macro
    def execute_with_body(body)
      "DUMMY #{name} #{parameters.to_a.join} #{body}"
    end

    def execute
      "DUMMY #{name} #{parameters}"
    end
  end

  class ExplodingBodyMacro < Macro
    def execute_with_body(body)
      raise Macro::ProcessingError.new("explode!")
    end
  end

  class ExplodingMacro < Macro
    def execute_macro
      raise Macro::ProcessingError.new("explode!")
    end
  end

  class TimeoutMacro < Macro
    def execute
      raise ::TimeoutError.new('Timeout error')
    end

    def can_be_cached?
      true
    end
  end

  class RealTimeoutMacro < Macro
    def execute
      (1..5).each do
        sleep 1
      end
    end
  end

  class HelloMacro < Macro
    def execute
      "hello"
    end

    def can_be_cached?
      true
    end
  end

  class HelloChart < Chart
    def do_generate(*args)
      "hello chart image goes here"
    end

    def can_be_cached?
      true
    end
  end

  class TimeoutBodyMacro < Macro
    def execute_with_body(body)
      raise ::TimeoutError.new('Timeout error')
    end
  end

  def with_safe_macro(name, klass, &block)
    raise "That macro is already registered" if Macro.get(name)
    Macro.register(name, klass)
    begin
      yield
    ensure
      Macro.unregister(name)
    end
  end

  def template_can_be_cached?(template, project, view_helper=self.view_helper)
    renderable = RenderableTester.new(project, template)
    renderable.formatted_content(view_helper)
    renderable.can_be_cached?
  end

  def render(template, project, options = {}, m=:formatted_content)
    options[:view_helper] ||= self.view_helper
    RenderableTester.new(project, template, options[:this_card]).send(m, options[:view_helper], (options.reject { |key| key == :view_helper}) )
  end

  def format_chart_image_source(alt, source)
    image = self.view_helper.content_tag('img', nil, :alt => alt, :src => source)
    Nokogiri::HTML::DocumentFragment.parse(image).to_xhtml
  end

  def with_renderable_caching_enabled
    Renderable.enable_caching
    yield
  ensure
    Renderable.disable_caching
  end

  def clean_backtrace
    yield # Patch non-Action-Controller test cases to be able to use assert_dom_equal.
  end

  def card_with_redcloth_content(content)
    card = @project.cards.first
    card.update_attributes(:description => content, :redcloth => true)
    assert card.redcloth, "unable to create redcloth card!"
    card.reload
  end

  module Unit
    include ActionController::UrlWriter, RenderableTestHelper, ActionView::Helpers, ApplicationHelper

    def self.included(base)
      base.extend(RenderableTestHelper::SingletonMethods)
      base.extend(ActionView::Helpers::ClassMethods)
    end
  end

  module Functional
    include RenderableTestHelper

    def self.included(base)
      base.extend(RenderableTestHelper::SingletonMethods)
    end

    def ckeditor_data
      if @response.body =~ /event\.editor\.setData\(\"(.+)\"\)\;/
        json_unescape($1)
      else
        raise "No ckeditor data found, response body: #{@response.body}"
      end
    end

  end

end
