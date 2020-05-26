#encoding:utf-8

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

module CSSLocatorHelper
  def css_locator(css, index=0)
    %{dom=this.browserbot.getCurrentWindow().$$(#{css.to_json})[#{index}]}
  end

  def class_locator(classname, index=0)
    %{dom=this.browserbot.getCurrentWindow().$$('.#{classname}')[#{index}]}
  end
end

class ActiveSupport::TestCase
  ['actions','pages','page_ids'].each do |required_dir|
    Dir["#{File.join(File.dirname(__FILE__), required_dir)}/*.rb"].each do |file|
      require file
      basename = File.basename(file, '.rb')
      include(basename.camelize.constantize)
    end
  end
end

module MingleHelpersLoader
  def self.included(base)
    base.extend(SingletonMethods)
  end

  module SingletonMethods

     def actions(*actions)
        assertions.each do |action|
          load_module(action, "_action", "actions")
        end
      end

       def pages(*page)
          assertions.each do |page|
            load_module(page, "_page", "pages")
          end
        end

         def page_ids(*pageid)
            assertions.each do |pageid|
              load_module(page, "_id", "page_ids")
            end
          end

    private

    def load_module(module_name, suffix, folder)
      module_name = module_name.to_s + suffix
      Object.module_eval do
        remove_const(module_name.camelize) if const_defined?(module_name.camelize)
      end
      load File.join(File.dirname(__FILE__), folder, module_name + '.rb')
      self.send(:include, module_name.camelize.constantize)
    end
  end
end

module Selenium

  class SeleneseInterpreter

    include CSSLocatorHelper

    def register_test(test_name)
      @current_test = test_name
    end

    def key_down(locator, keyseq)
      do_command("keyDown", [locator, keyseq])
    end

    def press_enter(locator)
      key_press(locator, Keycode::ENTER)
    end

    def submit_and_wait(form_locator, timeout=60000)
      submit(form_locator)
      wait_for_page_to_load(timeout)
    end

    def get_inner_html(locator)
      get_eval("this.page().findElement(#{locator.to_json}).innerHTML.unescapeHTML()")
    end

    def get_raw_inner_html(locator)
      get_eval("this.page().findElement(#{locator.to_json}).innerHTML")
    end

    def get_element_attribute(locator, attribute)
      get_eval("this.page().findElement(#{locator.to_json}).getAttribute(#{attribute.to_json})")
    end

    def drag_and_drop_to(from_locator, to_locator, overshoot=0)
      coords = overshoot_by(movement_between(from_locator, to_locator), overshoot)
      new_grid_view = get_eval("!!selenium.browserbot.getCurrentWindow().MingleUI.grid.instance")

      if new_grid_view == "true"
        coords = coords.split(", ").map(&:to_i)
        script = %Q{
          (function($) {
            var from = $(selenium.page().findElement(#{from_locator.to_json}));
            var to = $(selenium.page().findElement(#{to_locator.to_json}));
            var dx = #{coords[0]}, dy = #{coords[1]};

            var options = {
              dx: dx, dy: dy,
              interpolation: {
                duration: 1000,
                stepWidth: 5
              }
            };

            from.simulate("drag", options);
            to.simulate('drop');
          })(selenium.browserbot.getCurrentWindow().jQuery);
        }
        get_eval(script)
      else
        drag_and_drop(from_locator, coords)
      end
    end

    def mouse_up(locator)
      do_command('mouseUp', [locator])
    end

    def mouse_over(locator)
      do_command("mouseOver", [locator])
    end

    def mouse_move_at(locator, coord_string)
      do_command('mouseMoveAt', [locator, coord_string])
    end

    def mouse_move(locator)
      do_command('mouseMove', [locator])
    end

    def drag_and_drop_downwards(from_locator, to_locator)
      drag_and_drop(from_locator, movement_from_top(from_locator, to_locator))
    end

    def drag_and_drop_upwards(from_locator, to_locator)
      drag_and_drop(from_locator, movement_from_bottom(from_locator, to_locator))
    end

    def drag_and_drop(locator, movementsString)
      do_command("dragAndDrop", [locator, movementsString])
    end

    def blur(locator)
      fire_event(locator, 'blur')
    end

    def eval_javascript(script)
      get_eval("this.browserbot.getCurrentWindow()." + script)
    end

    def run_javascripts(*scripts)
      scripts.each { |script| eval_javascript(script) }
    end

    def run_script(script)
      do_command("runScript", [script])
    end

    def scroll_to_top
      get_eval("window.scrollTo(0,-document.body.scrollHeight)")
      sleep 0.5
    end

    def fake_client_timezone_offset(offset)
      open("/_class_method_call?class=Clock&method=fake_client_timezone_offset&offset=#{offset}")
      assert_text_present "Clock.fake_client_timezone_offset called"
      Clock.fake_client_timezone_offset(offset)
    end

    def disable_license_decrypt
      open("/_class_method_call?class=LicenseDecrypt&method=disable_license_decrypt")
    end

    def enable_license_decrypt
      open("/_class_method_call?class=LicenseDecrypt&method=enable_license_decrypt")
    end

    def run_once_full_text_search
      FullTextSearch.run_once
      ElasticSearch.clear_cache
      ElasticSearch.refresh_indexes
    end

    def run_once_history_generation
      @eval_session ||= ActiveSupport::TestCase.new_selenium_session(ActiveSupport::TestCase.create_selenium_session, true)
      @eval_session.open("/_class_method_call?class=HistoryGeneration&method=run_once")
      @eval_session.wait_for_text_present('SUCCESS')
    end

    def is_checked(locator)
      get_value(locator) == "on"
    end

    def is_not_checked(locator)
      get_value(locator) == "off"
    end

    def reset_fake
      open("/_class_method_call?class=Clock&method=reset_fake")
      assert_text_present "Clock.reset_fake called"
      Clock.reset_fake
    end

    def wait_for_selected_label(locator, optionLocator)
      do_command("waitForSelectedLabel",[locator, optionLocator])
    end

    def wait_for_element_present(locator, timeout=30000)
      do_command("waitForElementPresent", [locator,timeout,])
    end

    def wait_for_element_not_present(locator, timeout=60000)
      do_command("waitForElementNotPresent", [locator,timeout,])
    end

    def wait_for_element_visible(locator, timeout=30000)
      do_command("waitForVisible", [locator,timeout,])
    end

    def wait_for_element_not_visible(locator, timeout=30000)
      do_command("waitForNotVisible", [locator, timeout,])
    end

    def wait_for_checked(locator, timeout=30000)
      do_command("waitForChecked", [locator, timeout])
    end

    def wait_for_not_checked(locator, timeout=30000)
      do_command("waitForNotChecked", [locator, timeout])
    end

    def wait_for_text_present(patten)
      do_command("waitForTextPresent", [patten])
    end

    def wait_for_page_to_load(timeout=30000)
      do_command("waitForPageToLoad", [timeout,])
      wait_for_all_ajax_finished
    end

    def wait_for_popup(window_id, timeout=30000)
      do_command('waitForPopUp', [window_id, timeout])
    end

    def ruby_wait_for(label, time=30000, &block)
      return unless block_given?
      Timeout::timeout(time / 1000.0) do
        while !(block.call)
          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise "Timeout waiting for: #{label.inspect}"
    end

    def ruby_wait_for_condition(condition, time=30000)
      Timeout::timeout(time / 1000.0) do
        # careful! make sure your condition returns booleans and not just truthy or falsey values
        while get_eval(condition).downcase == "false"
          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise "Timeout waiting for condition: #{condition.inspect}"
    end

    def wait_for_all_ajax_finished(time = 30000, options={:card_summary => false})
      if ('object' == get_eval("typeof selenium.browserbot.getCurrentWindow().MingleAjaxTracker").downcase)
        all_ajax_done_condition = "selenium.browserbot.getCurrentWindow().MingleAjaxTracker.allAjaxComplete(#{options[:card_summary]})"
        ruby_wait_for_condition(all_ajax_done_condition)
      else
        text = get_eval(<<-JAVASCRIPT)
        var w = selenium.browserbot.getCurrentWindow();
        var r = [];
        for (prop in w) {
          if (w.hasOwnProperty(prop)) {
            r.push(prop);
          }
        }
        r.sort().join("\n");
        JAVASCRIPT
        puts "selenium.browserbot.getCurrentWindow properties: #{text}"
      end
    rescue => e
      puts %Q[
==========================================
PENDING_REQUESTS: #{pending_ajax_requests}

CALLER (shortened):
#{caller[0..9].join("\n")}
==========================================
      ]
    end

    def pending_ajax_requests
      get_eval("selenium.browserbot.getCurrentWindow().MingleAjaxTracker.PENDING_REQUESTS.join(', ')")
    rescue => e
      message = "unable to retrieve PENDING_REQUESTS: #{e.message}"
      if e.message.include?('MingleAjaxTracker is undefined')
        message << "markup:\n"
        message << get_eval("selenium.browserbot.getCurrentWindow().document.body.innerHTML")
      end
      message
    end

    def wait_for_all_drag_and_drop_finished(timeout = 120000)
      wait_for_condition(%Q{
        (function (win) {
          return !win.Draggable.isDragging() && !win.jQuery.simulate.activeDrag() && (win.jQuery("#transition_popup_div,#select_transition_div").length || win.jQuery(".card-icon.operating").length === 0) && win.jQuery(".card-rank-placeholder").length === 0;
        })(selenium.browserbot.getCurrentWindow());
      }, timeout)
    rescue => e
      puts "wait_for_all_drag_and_drop_finished failed for: #{e.message}"
    end

    def with_drag_and_drop_wait(timeout = 120000)
      yield
      wait_for_all_drag_and_drop_finished(timeout)
    end

    def with_ajax_wait(timeout = 30000)
      yield
      wait_for_all_ajax_finished(timeout)
    end

    def click_with_no_wait(locator)
      do_command("click", [locator,])
    end

    def click(locator)
      #wait element present for some ajax call random problem
      #
      #when locator including 'option', mostly is our drop list javascript and it's not ajax,
      #so we don't want to wait, since some test failed because of this.
      wait_for_element_present(locator) unless is_element_present(locator) unless locator.to_s.include?('option')
      do_command("click", [locator,])
    end

    def click_and_wait(locator, timeout = 60000)
      do_command("clickAndWait", [locator, timeout,])
    end

    def select_and_wait(selectLocator, optionLocator)
      do_command("selectAndWait", [selectLocator,optionLocator,])
    end

    def wait_for_card_popup(card_number, timeout=60000)
      wait_for_condition("selenium.browserbot.getCurrentWindow().document.getElementById('card_show_lightbox_content')", timeout)
    end

    def type_in_property_search_filter(locator, keyword)
      with_ajax_wait do
        if keyword.blank?
          type(locator, "")
          key_down(locator, Keycode::BACKSPACE)
        else
          type_with_key_down(locator, keyword)
        end
        sleep 0.1
      end
    end

    def take_snapshot
      html = ["<!-- snapshot start -->"]
      html << eval_javascript("document.documentElement.outerHTML")
      html << ["<!-- snapshot end -->"]
      html.join("\n")
    end

    def take_server_status
      Net::HTTP.get URI.parse("http://localhost:#{MINGLE_PORT}/status")
    end

    def type_with_key_down(locator, text)
      type(locator, text)
      key_down(locator, text[-1].to_s)
    end

    private

    def perform(command, *options)
      do_command(command, options).split(',')[1]
    end

    def overshoot_by(vector, pixels)
      puts "before: #{vector.inspect}"
      return vector if pixels == 0
      dx, dy = vector.split(", ").map(&:to_i)

      if (dx == dy || dx == 0 || dy == 0)
        dx -= pixels if dx < 0
        dx += pixels if dx > 0

        dy -= pixels if dy < 0
        dy += pixels if dy > 0
      else
        if (dy.abs > dx.abs)
          coeff = (dx.to_f / dy.to_f).abs

          dx -= coeff * pixels if dx < 0
          dx += coeff * pixels if dx > 0

          dy -= pixels if dy < 0
          dy += pixels if dy > 0
        else
          coeff = (dy.to_f / dx.to_f).abs

          dx -= pixels if dx < 0
          dx += pixels if dx > 0

          dy -= coeff * pixels if dy < 0
          dy += coeff * pixels if dy > 0
        end
      end

      [dx.round, dy.round].map(&:to_s).join(", ").tap {|s| puts "overshot by #{pixels}px: #{s.inspect}"}
    end

    def movement_between(locator1, locator2)
      origin = center_of(locator1)
      destination = center_of(locator2)
      "#{destination[0] - origin[0]}, #{destination[1] - origin[1]}"
    end

    def movement_to_behind(locator1, locator2)
      origin = center_of(locator1)
      destination = center_of(locator2)
      height = perform('getElementHeight', locator2).to_i
      width = perform('getElementWidth', locator2).to_i
      "#{destination[0] - origin[0] + width*2}, #{destination[1] + height - origin[1]}"
    end

    def movement_from_top(locator1, locator2)
      origin = center_of(locator1)
      destination = center_of(locator2)
      "#{destination[0] - origin[0]}, #{destination[1] - origin[1] + 17 }"
    end

    def movement_from_bottom(locator1, locator2)
      origin = center_of(locator1)
      destination = center_of(locator2)
      "#{destination[0] - origin[0]}, #{destination[1] - origin[1] - 17}"
    end

    def top_left_corner_of(locator)
      result_x = perform('getElementPositionLeft', locator).to_i
      result_y = perform('getElementPositionTop', locator).to_i
      [result_x, result_y]
    end

    def center_of(locator)
      left_x = perform('getElementPositionLeft', locator).to_i
      top_y = perform('getElementPositionTop', locator).to_i
      width = perform('getElementWidth', locator).to_i
      height = perform('getElementHeight', locator).to_i

      result_x = left_x + width / 2
      result_y = top_y + height / 2
      [result_x, result_y]
    end

  end

  module Assertions

    include ::Test::Unit::Assertions

    def assert_title(text)
      raise SeleniumCommandError.new("Title is not '#{text}' it was '#{get_title}'") unless get_title == text
    end


    def assert_has_classname(locator, class_name, message=nil)
      classes = get_attribute(locator + "@class").split(" ")
      message ||= "element #{locator} should have class name #{class_name} but it does not. The class name is '#{classes.join(" ")}'"
      raise SeleniumCommandError.new(message) unless classes.include?(class_name)
    end

    def assert_does_not_have_classname(locator, class_name)
      classes = get_attribute(locator + "@class").split(" ")
      raise SeleniumCommandError.new("element #{locator} should not have class name #{class_name} but it does. The class name is '#{classes.join(" ")}'") if classes.include?(class_name)
    end

    def assert_value(locator, text)
      raise SeleniumCommandError.new("Value of field is not '#{text}' it was '#{get_value(locator)}'") unless get_value(locator) == text
    end

    def assert_element_text(locator, text)
      actual = get_text locator
      raise SeleniumCommandError.new("Value of element is not '#{text}' it was '#{actual}'") unless actual == text
    end

    def assert_text_not_present(text)
      raise SeleniumCommandError.new("#{text} found in page") if is_text_present(text)
    end

    def assert_raw_text_present(locator, text)
      raw_text = get_raw_inner_html(locator)
      raise SeleniumCommandError.new("#{text} not found in page") unless raw_text.include?(text)
    end

    def assert_text_not_present_in(locator, text, message=nil)
      actual = get_text locator
      message ||= "#{text} found in element(#{locator})"
      raise SeleniumCommandError.new(message) if actual.include?(text)
    end

    def assert_text_present_in(locator, text, message=nil)
      actual = get_text locator
      message ||= %Q[#{text} not found in element(#{locator})
        actual text:
#{actual}]
      raise SeleniumCommandError.new(message) unless actual.include?(text)
    end

    def assert_drop_down_contains_value(locator, value)
      get_select_options("id=#{locator}").include?(value)
    end

    def get_all_drop_down_option_values(locator)
       values = get_select_options("id=#{locator}")
    end

    def assert_values_in_drop_down_are_ordered(drop_down_name, expected_ordered_values)
      actual_values = get_all_drop_down_option_values(drop_down_name)
      expected_ordered_values.each_with_index do |expected_value, index|
        raise SeleniumCommandError.new("Expected drop down value to be '#{expected_value}' at position #{index}, but was '#{actual_values[index]}'") unless expected_value == actual_values[index]
      end
    end

    def assert_drop_down_does_not_contain_value(locator, value)
      !get_select_options("id=#{locator}").include?(value)
    end

    def assert_confirmation(text)
      confirmation = get_confirmation
      raise SeleniumCommandError.new("Confirmation is not '#{text}' it was '#{confirmation}'") unless confirmation == text
    end

    def assert_location(text)
      location = get_location
      if location =~ /[^:]*:\/\/[^\/]*(\/.*)/
        location = $1
      end
      raise SeleniumCommandError.new("Location is not '#{text}' it was '#{location}'") unless location == text
    end

    def assert_table_cell(table_locator, row, column, expected)
      actual = get_table("#{table_locator}.#{row}.#{column}")
      raise SeleniumCommandError.new("Table cell is not '#{expected}' it was '#{actual}'") unless actual == expected.to_s
    end

    def assert_table_cell_match(table_locator, row, column, pattern)
      actual = get_table("#{table_locator}.#{row}.#{column}")
      raise SeleniumCommandError.new("Table cell does not match '#{pattern}' it was '#{actual}'") unless actual =~ pattern
    end

    def assert_not_text(locator, text, timeout=30000)
      do_command('assertNotText', [locator,text,timeout])
    end

    def assert_element_present(locator)
      raise SeleniumCommandError.new("#{locator} is not present") unless is_element_present(locator)
    end

    def assert_element_not_present(locator)
      raise SeleniumCommandError.new("#{locator} is present") if is_element_present(locator)
    end

    def assert_visible(locator)
      raise SeleniumCommandError.new("#{locator} is not visible") unless is_visible(locator)
    end

    def assert_not_visible(locator)
      raise SeleniumCommandError.new("#{locator} is visible") if is_visible(locator)
    end

    def assert_element_not_present_or_visible(locator)
      raise SeleniumCommandError.new("#{locator} is visible or present") if is_element_present(locator) && is_visible(locator)
    end

    def assert_element_does_not_match(locator, pattern)
      text = get_inner_html(locator)
      raise SeleniumCommandError.new("#{text} matched #{pattern}") if text =~ pattern
    end

    def assert_element_matches(locator, pattern, options = { :raw_html => false })
      text = options[:raw_html] ? get_raw_inner_html(locator) : get_inner_html(locator)
      text =   text.force_encoding("utf-8") if MingleUpgradeHelper.ruby_1_9?
      raise SeleniumCommandError.new("#{text} does not match #{pattern} (#{locator})") unless text =~ pattern
    end

    def assert_element_only_matches_once(locator, pattern)
      text = get_inner_html(locator)
      raise SeleniumCommandError.new("#{text} does not match #{pattern}") unless text =~ pattern
      raise SeleniumCommandError.new("#{text} not only match once") if text.scan(pattern).size > 0
    end

    def assert_element_matches_ignore_space(locator, message)
      text = get_inner_html(locator)
      raise SeleniumCommandError.new("#{text} does not match #{message}") unless text.strip_all =~ /#{message.strip_all}/e
    end

    def assert_checked(locator)
      raise SeleniumCommandError.new("#{locator} is not checked") unless get_value(locator) == "on"
    end

    def assert_not_checked(locator)
      raise SeleniumCommandError.new("#{locator} is checked") unless get_value(locator) == "off"
    end

    def assert_attribute(locator, expected_value)
      raise SeleniumCommandError.new("#{locator} does not have expected value") unless get_attribute(locator) == expected_value
    end

    def assert_attribute_include(locator, expected)
      actual = get_attribute(locator)
      element, attribute = locator.split("@")
      raise SeleniumCommandError.new("attribute '#{attribute}' at locator '#{element}' should match #{expected}, but did not: was #{actual}") unless actual =~ expected
    end

    def assert_attribute_equal(locator, expected)
      actual = get_attribute(locator)
      element, attribute = locator.split("@")
      raise SeleniumCommandError.new("attribute '#{attribute}' at locator '#{element}' should be equal to #{expected}, but was #{actual}") unless expected == actual
    end

    def assert_attribute_not_equal(locator, expected)
      actual = get_attribute(locator)
      element, attribute = locator.split("@")
      raise SeleniumCommandError.new("attribute '#{attribute}' at locator '#{element}' should not be equal to #{expected}") if expected == actual
    end

    def assert_column_present(table, column)
      unless coloumns_of(table).include?(column)
        raise SeleniumCommandError.new("column named #{column} in table '#{table}' not present")
      end
    end

    def assert_column_not_present(table, column)
      if coloumns_of(table).include?(column)
        raise SeleniumCommandError.new("column named #{column} in table '#{table}' is present")
      end
    end

    def coloumns_of(table)
      eval_javascript("$$('##{table} thead th a span').pluck('innerHTML')").split(",")
    end

    def assert_selected_label(locator, optionLocator)
      do_command("assertSelectedLabel",[locator, optionLocator])
    end

    def assert_selected_value(locator, optionLocator)
      do_command("assertSelectedValue",[locator, optionLocator])
    end

    def assert_ordered(locator1, locator2)
      do_command("assertOrdered", [locator1, locator2, ""])
    end

    def assert_fail(message="")
      raise SeleniumCommandError.new("#{message}... Test Failed")
    end

    def assert_element_not_editable(locator)
      if self.respond_to?(:is_editable)
        raise SeleniumCommandError.new("#{locator} should not have been editable") if is_editable(locator)
      else
        do_command("assertNotEditable", [locator])
      end
    end

    def assert_element_editable(locator)
      if self.respond_to?(:is_editable)
        raise SeleniumCommandError.new("#{locator} should have been editable") unless is_editable(locator)
      else
        do_command("assertNotEditable", [locator])
      end
    end

    def assert_button_text_present(text)
      assert_element_present("//input[@type='button' and @value='#{text}']")
    end

    def assert_element_style_property_value(css_selector, property, expected_value)
      script = "window.getComputedStyle(this.browserbot.getCurrentWindow().document.querySelector(\"#{css_selector}\")).getPropertyValue(\"#{property}\");"
      actual_value = get_eval(script)
      unless actual_value == expected_value
        raise SeleniumCommandError.new("Expected (\"#{css_selector}\")['#{property}'] to be '#{expected_value}' but was '#{actual_value}'")
      end
    end

    def within_popup(window_id, &block)
      wait_for_popup(window_id)
      select_window(window_id)
      yield
    ensure
      select_window('')
    end
  end
end

module Keycode
  ENTER = '\13'
  ESC = '\27'
  RIGHT = '\39'
  LEFT = '\37'
  UP = '\38'
  DOWN = '\40'
  BACKSPACE = '\8'
end

class HtmlTable
  attr_accessor :column_names

  def initialize(browser, id, column_names, row_offset=0, column_offset=0)
    @browser = browser
    @id = id
    @column_names = column_names.collect{|column| column.downcase}
    @row_offset = row_offset
    @column_offset = column_offset
  end

  def assert_row_values(row_number, values)
    values.each_with_index do |value, index|
      @browser.assert_table_cell(@id, row_number + @row_offset, index + @column_offset, value)
    end
  end

  def assert_row_values_match(row_number, patterns)
    patterns.each_with_index do |pattern, index|
      @browser.assert_table_cell_match(@id, row_number + @row_offset, index + @column_offset, pattern)
    end
  end

  def assert_row_values_for_card(row_number, card)
    @column_names.each_with_index{|column_name, index| @browser.assert_table_cell(@id, row_number + @row_offset, index + @column_offset, value_for(card, column_name))}
  end

  def assert_ascending(column)
    values = get_non_blank_column_values(column)
    raise SeleniumCommandError.new("values #{values.join(',')} not in ascending order") unless values == values.smart_sort
  end

  def assert_descending(column)
    values = get_non_blank_column_values(column)
    raise SeleniumCommandError.new("values #{values.join(',')} not in descending order") unless values == values.smart_sort.reverse
  end

  def get_non_blank_column_values(column)
    column = @column_names.index(column.downcase) + @column_offset
    values = []
    row = @row_offset + 1
    while true
      begin
        value = @browser.get_table("#{@id}.#{row}.#{column}").strip
        values << value if value.any?
        row += 1
      rescue
        break;
      end
    end
    values
  end

  def value_for(card, attribute)
    if card.respond_to?(:value_for)
      card.value_for(attribute)
    else
      if card.respond_to?(attribute)
        card.send(attribute)
      elsif card.tags.nil?
        return ''
      else
        values_by_group = {}
        card.tags.each do |tag|
          group, value = tag.downcase.split('-')
          values_by_group[group] = value unless value.nil?
        end
        values_by_group[attribute]
      end
    end
  end
end

class FilterTester
  include CSSLocatorHelper, CardShowPage

  PROPERTIES_LIST_TYPE = 'properties'
  OPERATORS_LIST_TYPE = 'operators'
  VALUES_LIST_TYPE = 'values'

  def initialize(browser, filter_prefix)
    @browser = browser
    @filter_prefix = filter_prefix
  end

  def set_property(filter_number, property)
    open_property_list(filter_number)
    click_option(filter_number, PROPERTIES_LIST_TYPE, property)
  end

  def set_value(filter_number, filter_value, options={:wait => false})
    @browser.with_ajax_wait do
      open_value_list(filter_number)
      click_option(filter_number, VALUES_LIST_TYPE, filter_value, options)
    end
  end

  def set_card_number_value(filter_number, card_number)
    if card_number.blank? || card_number == '(not set)'
      set_card_number_value_to_not_set(filter_number)
    else
      click_values_drop_link(filter_number)
      @browser.with_ajax_wait do
        @browser.click droplist_select_card_action("#{filter_prefix(filter_number)}_values_drop_down")
      end
      @browser.with_ajax_wait do
        @browser.click(card_selector_result_locator(:filter, card_number))
      end
    end
  end

  def set_card_number_value_to_not_set(filter_number, options={:wait => false})
    set_value(filter_number, "(not set)", options)
  end

  def set_card_number_value_to_plv(filter_number, plv, options={:wait => false})
    set_value(filter_number, plv, options)
  end

  def select_operator(filter_number, operator)
     open_operator_list(filter_number)
     if @browser.get_text("#{filter_prefix(filter_number)}_operators_drop_link") == operator
       click_option(filter_number, OPERATORS_LIST_TYPE, operator)
     else
       @browser.with_ajax_wait do
         click_option(filter_number, OPERATORS_LIST_TYPE, operator)
       end
     end
  end

  def open_property_list(filter_number)
    open_list(filter_number, PROPERTIES_LIST_TYPE)
  end

  def open_operator_list(filter_number)
    open_list(filter_number, OPERATORS_LIST_TYPE)
  end

  def open_value_list(filter_number)
    open_list(filter_number, VALUES_LIST_TYPE)
  end

  def click_values_drop_link(filter_number)
    click_drop_link(filter_number, VALUES_LIST_TYPE)
  end

  def remove_filter(filter_number, options={:wait => true})
    click_delete(filter_number, options)
  end

  private
  def filter_prefix(filter_number)
    @filter_prefix.call(filter_number)
  end

  def open_list(filter_number, list_type)
    unless @browser.is_visible("#{filter_prefix(filter_number)}_#{list_type}_drop_down")
      click_drop_link(filter_number, list_type)
      @browser.wait_for_element_visible("#{filter_prefix(filter_number)}_#{list_type}_drop_down")
    end
  end

  def click_drop_link(filter_number, list_type)
    @browser.click("#{filter_prefix(filter_number)}_#{list_type}_drop_link")
  end

  def click_option(filter_number, list_type, option, options={:wait => false})
    locator = "#{filter_prefix(filter_number)}_#{list_type}_option_#{option}"
    if options[:wait]
      @browser.click_and_wait locator
    else
      @browser.click locator
    end
  end

  def click_delete(filter_number, options={:wait => true})
    locator = "#{filter_prefix(filter_number)}_delete"
    if options[:wait]
      @browser.click_and_wait locator
    else
      @browser.click locator
    end
  end
end
