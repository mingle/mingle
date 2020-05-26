require 'net/http'
require 'guid'

module Sahi
  # The Browser class controls different browsers via Sahi's proxy.
  #
  # Thank you Sai Venkat for helping kickstart the ruby driver.
  #
  # Author::    Narayan Raman (mailto:narayan@sahi.co.in)
  # Copyright:: Copyright (c) 2006  V Narayan Raman
  # License::   Apache License, Version 2.0
  #
  # Download Sahi from http://sahi.co.in/ .
  # Java 1.5 or greater is needed to run Sahi.
  #
  # Start Sahi:
  # cd sahi\userdata\bin;
  # start_sahi.bat;
  #
  # or
  #
  # cd sahi/userdata/bin;
  # start_sahi.sh;
  #
  # Point the browser proxy settings to localhost 9999.
  #

  class Browser
    attr_accessor :proxy_host, :proxy_port, :print_steps, :sahisid, :popup_name, :domain_name

    # Takes browser_type as specified in sahi/userdata/config/browser_types.xml (name of browserType)
    #
    # OR
    #
    # Takes browser_path, browser_options and browser_executable
    # Various browser options needed to initialize the Browser object are:
    #
    # Internet Explorer 6&7:
    # 	browser_path = "C:\\Program Files\\Internet Explorer\\iexplore.exe"
    # 	browser_options = ""
    #   browser_executable = "iexplore.exe"
    #
    # Internet Explorer 8:
    # 	browser_path = "C:\\Program Files\\Internet Explorer\\iexplore.exe"
    # 	browser_options = "-nomerge"
    #   browser_executable = "iexplore.exe"
    #
    # Firefox:
    #   browser_path = "C:\\Program Files\\Mozilla Firefox\\firefox.exe"
    #   browser_options = "-profile $userDir/browser/ff/profiles/sahi0 -no-remote"
    #   browser_executable = "firefox.exe"
    #
    # Chrome:
    # 	userdata_dir = "D:/sahi/sf/sahi_993/userdata" #  path to Sahi's userdata directory.
    #   browser_path = "C:\\Documents and Settings\\YOU_THE_USER\\Local Settings\\Application Data\\Google\\Chrome\\Application\\chrome.exe"
    #   browser_options = "--user-data-dir=# {userdata_dir}\browser\chrome\profiles\sahi$threadNo"
    #   browser_executable = "chrome.exe"
    #
    # Safari:
    # 	browser_path = "C:\\Program Files\\Safari\Safari.exe"
    # 	browser_options = ""
    #   browser_executable = "safari.exe"
    #
    # Opera:
    # 	browser_path = "C:\\Program Files\\Opera\\opera.exe"
    # 	browser_options = ""
    #   browser_executable = "opera.exe"

    def initialize(*args)
      @proxy_host = "localhost"
      @proxy_port = 9999
      if args.size == 3
        @browser_path = args[0]
        @browser_options = ars[1]
        @browser_executable = args[2]
      elsif args.size == 1
        @browser_type = args[0]
      end
      @popup_name = nil
      @domain_name = nil
      @sahisid = nil
      @print_steps = false
    end

    def check_proxy()
      begin
        response("http://#{@proxy_host}:#{@proxy_port}/_s_/spr/blank.htm")
      rescue
        raise "Sahi proxy is not available. Please start the Sahi proxy."
      end
    end

    #opens the browser
    def open()
      check_proxy()
      @sahisid = Guid.new.to_s
      start_url = "http://sahi.example.com/_s_/dyn/Driver_initialized"
      if (@browser_type != null)
        exec_command("launchPreconfiguredBrowser", {"browserType" => @browser_type, "startUrl" => start_url})
      else
        exec_command("launchAndPlayback", {"browser" => @browser, "browserOptions" => @browser_options, "browserExecutable" => @browser_executable, "startUrl" => start_url})
      end

      i = 0
      while (i < 500)
        i+=1
        break if is_ready?
        sleep(0.1)
      end
    end


    def is_ready?
      return  "true".eql?(exec_command("isReady"))
    end

    def exec_command(cmd, qs={})
      res = response("http://#{@proxy_host}:#{@proxy_port}/_s_/dyn/Driver_" + cmd, {"sahisid"=>@sahisid}.update(qs))
      return res
    end

    def response(url, qs={})
      return Net::HTTP.post_form(URI.parse(url), qs).body
    end

    # navigates to the given url
    def navigate_to(url, force_reload=false)
      execute_step("_sahi._navigateTo(\"" + url + "\", "+ (force_reload.to_s()) +")");
    end

    def execute_step(step)
      if popup?()
        step = "_sahi._popup(#{Utils.quoted(@popup_name)})." + step
      end
      if domain?()
        step = "_sahi._domain(#{Utils.quoted(@domain_name)})." + step
      end
      exec_command("setStep", {"step" => step})
      i = 0
      while (i < 500)
        sleep(0.1)
        i+=1
        check_done = exec_command("doneStep")
        done = "true".eql?(check_done)

        error = check_done.index("error:") == 0
        return if done
        if (error)
          raise check_done
        end
      end
    end

    def method_missing(m, *args, &block)
      return ElementStub.new(self, m.to_s, args)
    end

    # evaluates a javascript expression on the browser and fetches its value
    def fetch(expression)
      key = "___lastValue___" +Guid.new.to_s()
      execute_step("_sahi.setServerVarPlain('"+key+"', " + expression + ")")
      return check_nil(exec_command("getVariable", {"key" => key}))
    end

    # evaluates a javascript expression on the browser and returns true if value is true or "true"
    def fetch_boolean(expression)
      return fetch(expression) == "true"
    end


    def browser_js=(js)
      exec_command("setBrowserJS", {"browserJS"=>js})
    end

    def check_nil(s)
      return (s == "null")  ? nil : s
    end

    # closes the browser
    def close()
      if popup?()
        execute_step("_sahi._closeWindow()");
      else
        exec_command("kill");
        #Process.kill(9, @pid) if @pid
      end
    end

    # sets the speed of execution. The speed is specified in milli seconds
    def speed=(ms)
      exec_command("setSpeed", {"speed"=>ms})
    end

    # sets strict visibility check. If true, Sahi APIs ignores elements which are not visible
    def strict_visibility_check=(check)
      execute_step("_sahi._setStrictVisibilityCheck(#{check})")
    end


    # represents a popup window. The name is either the window name or its title.
    def popup(name)
      if (@browser_type != null)
        win = Browser.new(@browser_type)
      else
        win = Browser.new(@browser_path, @browser_options, @browser_executable)
      end

      win.proxy_host = @proxy_host
      win.proxy_port = @proxy_port
      win.sahisid = @sahisid
      win.print_steps = @print_steps
      win.popup_name = name
      win.domain_name = @domain_name
      return win
    end

    # represents a domain section of window.
    def domain(name)
      if (@browser_type != null)
        win = Browser.new(@browser_type)
      else
        win = Browser.new(@browser_path, @browser_options, @browser_executable)
      end

      win.proxy_host = @proxy_host
      win.proxy_port = @proxy_port
      win.sahisid = @sahisid
      win.print_steps = @print_steps
      win.popup_name = @popup_name
      win.domain_name = name
      return win
    end

    def popup?()
      return @popup_name != nil
    end

    def domain?()
      return @domain_name != nil
    end

    # returns the message last alerted on the browser
    def last_alert()
      return fetch("_sahi._lastAlert()")
    end

    # resets the last alerted message
    def clear_last_alert()
      execute_step("_sahi._clearLastAlert()")
    end

    # returns the last confirm message
    def last_confirm()
      return fetch("_sahi._lastConfirm()")
    end

    # resets the last confirm message
    def clear_last_confirm()
      execute_step("_sahi._clearLastConfirm()")
    end

    # set an expectation to press OK (true) or Cancel (false) for specific confirm message
    def expect_confirm(message, input)
      execute_step("_sahi._expectConfirm(#{Utils.quoted(message) }, #{input})")
    end

    # returns the last prompted message
    def last_prompt()
      return fetch("_sahi._lastPrompt()")
    end

    # clears the last prompted message
    def clear_last_prompt()
      execute_step("_sahi._clearLastPrompt()")
    end

    # set an expectation to set given value for specific prompt message
    def expect_prompt(message, input)
      execute_step("_sahi._expectPrompt(#{Utils.quoted(message)}, #{Utils.quoted(input) })")
    end

    # get last downloaded file's name
    def last_downloaded_filename()
      return fetch("_sahi._lastDownloadedFileName()")
    end

    # clear last downloaded file's name
    def clear_last_downloaded_filename()
      execute_step("_sahi._clearLastDownloadedFileName()")
    end

    # Save the last downloaded file to specified path
    def save_downloaded(file_path)
      execute_step("_sahi._saveDownloadedAs(#{Utils.quoted(file_path)})")
    end

    # make specific url patterns return dummy responses. Look at _addMock documentation.
    def add_url_mock(url_pattern, clazz=nil)
      clazz = "MockResponder_simple" if !clazz
      execute_step("_sahi._addMock(#{Utils.quoted(url_pattern)}, #{Utils.quoted(clazz)})")
    end

    # reverse effect of add_url_mock
    def remove_url_mock(url_pattern)
      execute_step("_sahi._removeMock(#{Utils.quoted(url_pattern)})")
    end

    # return window title
    def title()
      return fetch("_sahi._title()")
    end

    # returns true if browser is Internet Explorer
    def ie?()
      return fetch_boolean("_sahi._isIE()")
    end

    # returns true if browser is Firefox
    def firefox?()
      return fetch_boolean("_sahi._isFF()")
    end

    # returns true if browser is Google Chrome
    def chrome?()
      return fetch_boolean("_sahi._isChrome()")
    end

    # returns true if browser is Safari
    def safari?()
      return fetch_boolean("_sahi._isSafari()")
    end

    # returns true if browser is Opera
    def opera?()
      return fetch_boolean("_sahi._isOpera()")
    end

    # waits for specified time (in seconds).
    # if a block is passed, it will wait till the block evaluates to true or till the specified timeout, which ever is earlier.
    def wait(timeout)
      total = 0;
      interval = 0.2;

      if !block_given?
        sleep(timeout)
        return
      end

      while (total < timeout)
        sleep(interval);
        total += interval;
        begin
          return if yield
        rescue Exception=>e
          puts e
        end
      end
    end

    #private :check_proxy, :is_ready?, :exec_command, :check_nil

  end


  # This class is a stub representation of various elements on the browser
  # Most of the methods are implemented via method missing.
  #
  # All APIs available in Sahi are available in ruby. The full list is available here: http://sahi.co.in/w/browser-accessor-apis
  #
  # Most commonly used action methods are:
  # click - for all elements
  # mouse_over - for all elements
  # focus - for all elements
  # remove_focus - for all elements
  # check - for checkboxes or radio buttons
  # uncheck - for checkboxes

  class ElementStub
    @@actions  = {"click"=>"click",
      "focus"=>"focus", "remove_focus"=>"removeFocus",
      "check"=>"check", "uncheck"=>"uncheck",
      "dblclick"=>"doubleClick", "right_click"=>"rightClick",
      "key_down"=>"keyDown", "key_up"=>"keyUp", "key_press"=>"keyPress",
      "mouse_over"=>"mouseOver", "mouse_down"=>"mouseDown", "mouse_up"=>"mouseUp"}
    def initialize(browser, type,  identifiers)
      @type = type
      @browser  = browser
      @identifiers = identifiers
    end

    def method_missing(m, *args, &block)
      key = m.to_s
      if @@actions.key?(key)
        _perform(@@actions[key])
      end
    end

    def _perform(type)
      step = "_sahi._#{type}(#{self.to_s()})"
      @browser.execute_step(step)
    end

    # drag element and drop on another element
    def drag_and_drop_on(el2)
      @browser.execute_step("_sahi._dragDrop(#{self.to_s()}, #{el2.to_s()})")
    end

    # choose option in a select box
    def choose(val)
      @browser.execute_step("_sahi._setSelected(#{self.to_s()}, #{Utils.quoted(val)})")
    end

    # sets the value for textboxes or textareas. Also triggers necessary events.
    def value=(val)
      @browser.execute_step("_sahi._setValue(#{self.to_s()}, #{Utils.quoted(val)})")
    end

    # returns value of textbox or textareas and other relevant input elements
    def value()
      return @browser.fetch("#{self.to_s()}.value")
    end

    # fetches value of specified attribute
    def fetch(attr=nil)
      return attr ? @browser.fetch("#{self.to_s()}.#{attr}") : @browser.fetch("#{self.to_s()}")
    end

    # returns boolean value of attribute. returns true only if fetch returns "true"
    def fetch_boolean(attr=nil)
      return @browser.fetch_boolean(attr)
    end

    # Emulates setting filepath in a file input box.
    def file=(val)
      @browser.execute_step("_sahi._setFile(#{self.to_s()}, #{Utils.quoted(val)})")
    end

    # returns inner text of any element
    def text()
      return @browser.fetch("_sahi._getText(#{self.to_s()})")
    end

    # returns checked state of checkbox or radio button
    def checked?()
      return fetch("checked") == "true";
    end

    # returns selected text from select box
    def selected_text()
      return @browser.fetch("_sahi._getSelectedText(#{self.to_s()})")
    end

    # returns a stub with a DOM "near" relation to another element
    # Eg.
    #  browser.button("delete").near(browser.cell("User One")) will denote the delete button near the table cell with text "User One"
    def near(el2)
      @identifiers << ElementStub.new(@browser, "near", [el2])
      return self
    end

    # returns a stub with a DOM "in" relation to another element
    # Eg.
    #  browser.image("plus.gif").in(browser.div("Tree Node 2")) will denote the plus icon inside a tree node with text "Tree Node 2"
    def in(el2)
      @identifiers << ElementStub.new(@browser, "in", [el2])
      return self
    end

    # returns a stub with a POSITIONAL "under" relation to another element.
    # Eg.
    #  browser.cell(0).under(browser.cell("Header")) will denote the cell visually under "Header"
    #  browser.cell(0).near(browser.cell("Book")).under(browser.cell("Cost")) may be used to denote the Cost of Book in a grid

    def under(el2)
      @identifiers << ElementStub.new(@browser, "under", [el2])
      return self
    end


    # specifies exacts coordinates to click inside an element. The coordinates are relative to the element. x is from left and y is from top. Can be negative to specify other direction
    # browser.button("Menu Button with Arrow on side").xy(-5, 10).click will click on the button, 5 pixels from right and 10 pixels from top.
    def xy(x, y)
      return ElementStub.new(@browser, "xy", [self, x, y])
    end

    # denotes the DOM parentNode of element.
    # If tag_name is specified, returns the parent element which matches the tag_name
    # occurrence finds the nth parent of a particular tag_name
    # eg. browser.cell("inner nested cell").parent_node("TABLE", 3) will return the 3rd encapsulating table of the given cell.
    def parent_node(tag_name="ANY", occurrence=1)
      return ElementStub.new(@browser, "parentNode", [self]);
    end

    # returns true if the element exists on the browser
    def exists?(optimistic = false)
      return self.exists1?() if optimistic;
      (1..5).each do
        return true if self.exists1?();
      end
      return false;
    end

    def exists1?
      return "true".eql?(@browser.fetch("_sahi._exists(#{self.to_s()})"))
    end

    # returns true if the element exists and is visible on the browser
    def visible?(optimistic = false)
      return self.visible1?() if optimistic;
      (1..5).each do
        return true if self.visible1?();
      end
      return false;
    end

    def visible1?
      return "true".eql?(@browser.fetch("_sahi._isVisible(#{self.to_s()})"))
    end

    # returns true if the element contains this text
    def contains_text?(text)
      return @browser.fetch("_sahi._containsText(#{self.to_s()}, #{Utils.quoted(text)})")
    end

    # returns true if the element contains this html
    def contains_html?(html)
      return @browser.fetch("_sahi._containsHTML(#{self.to_s()}, #{Utils.quoted(html)})")
    end

    # returns count of elements similar to this element
    def count_similar()
    	return Integer(@browser.fetch("_sahi._count(\"_#{@type}\", #{concat_identifiers(@identifiers).join(", ")})"))
    end
    
    # returns array elements similar to this element
    def collect_similar()
    	count = self.count_similar()
    	els = Array.new(count)
    	for i in (0..count-1)
    		copy = Array.new(@identifiers)
    		copy[0] = "#{copy[0]}[#{i}]"
    		els[i] = ElementStub.new(@browser, @type, copy);
    	end
    	return els
    end
                
    def to_s
      return "_sahi._#{@type }(#{concat_identifiers(@identifiers).join(", ") })"
    end

    def concat_identifiers(ids)
      return ids.collect {|id| id.kind_of?(String) ? Utils.quoted(id) : id.to_s()}
    end
    #private :concat_identifiers, :exists1?, :visible1?
  end

  class Utils
    def Utils.quoted(s)
      return "\"" + s.gsub("\\", "\\\\").gsub("\"", "\\\"") + "\""
    end
  end
end
