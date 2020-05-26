require 'test/unit'
require '../lib/sahi'

class SahiDriverTest < Test::Unit::TestCase
  def setup
    @browser = init_browser()
    @browser.open
    @base_url = "http://sahi.co.in"
  end

  def teardown
    if @browser
      @browser.set_speed = 100
      @browser.close
      sleep(1)
    end
  end

  def init_browser()
    # Look at sahi/userdata/config/browser_types.xml to configure browsers.
    @browser_name = "firefox"
    return Sahi::Browser.new(@browser_name)
  end


  def test1
    @browser.navigate_to(@base_url + "/demo/formTest.htm")
    @browser.textbox("t1").value = "aaa"
    @browser.link("Back").click
    @browser.link("Table Test").click
    assert_equal("Cell with id", @browser.cell("CellWithId").text)
  end

  def test_ZK
    @browser.speed = 200
    @browser.navigate_to("http://www.zkoss.org/zkdemo/userguide/")
    @browser.div("Hello World").click
    @browser.span("Pure Java").click
    @browser.div("Various Form").click
    @browser.wait(5000) {@browser.textbox("z-intbox[1]").visible?}

    @browser.div("Comboboxes").click
    @browser.textbox("z-combobox-inp").value = "aa"
    @browser.italic("z-combobox-btn").click
    @browser.cell("Simple and Rich").click

    @browser.italic("z-combobox-btn[1]").click
    @browser.span("The coolest technology").click
    @browser.italic("z-combobox-btn[2]").click
    @browser.image("CogwheelEye-32x32.gif").click
    assert(@browser.textbox("z-combobox-inp[2]").exists?)
  end


  def test_fetch()
    @browser.navigate_to(@base_url + "/demo/formTest.htm")
    assert_equal(@base_url + "/demo/formTest.htm", @browser.fetch("window.location.href"))
  end

  def test_accessors()
    @browser.navigate_to(@base_url  + "/demo/formTest.htm")
    assert_equal("", @browser.textbox("t1").value)
    assert(@browser.textbox(1).exists?)
    assert(@browser.textbox("$a_dollar").exists?)
    @browser.textbox("$a_dollar").value = ("adas")
    assert_equal("", @browser.textbox(1).value)
    assert(@browser.textarea("ta1").exists?)
    assert_equal("", @browser.textarea("ta1").value)
    assert(@browser.textarea(1).exists?)
    assert_equal("", @browser.textarea(1).value)
    assert(@browser.checkbox("c1").exists?)
    assert_equal("cv1", @browser.checkbox("c1").value)
    assert(@browser.checkbox(1).exists?)
    assert_equal("cv2", @browser.checkbox(1).value)
    assert(@browser.checkbox("c1[1]").exists?)
    assert_equal("cv3", @browser.checkbox("c1[1]").value)
    assert(@browser.checkbox(3).exists?)
    assert_equal("", @browser.checkbox(3).value)
    assert(@browser.radio("r1").exists?)
    assert_equal("rv1", @browser.radio("r1").value)
    assert(@browser.password("p1").exists?)
    assert_equal("", @browser.password("p1").value)
    assert(@browser.password(1).exists?)
    assert_equal("", @browser.password(1).value)
    assert(@browser.select("s1").exists?)
    assert_equal("o1", @browser.select("s1").selected_text())
    assert(@browser.select("s1Id[1]").exists?)
    assert_equal("o1", @browser.select("s1Id[1]").selected_text())
    assert(@browser.select(2).exists?)
    assert_equal("o1", @browser.select(2).selected_text())
    assert(@browser.button("button value").exists?)
    assert(@browser.button("btnName[1]").exists?)
    assert(@browser.button("btnId[2]").exists?)
    assert(@browser.button(3).exists?)
    assert(@browser.submit("Add").exists?)
    assert(@browser.submit("submitBtnName[1]").exists?)
    assert(@browser.submit("submitBtnId[2]").exists?)
    assert(@browser.submit(3).exists?)
    assert(@browser.image("imageAlt1").exists?)
    assert(@browser.image("imageId1[1]").exists?)
    assert(@browser.image(2).exists?)
    assert(!@browser.link("Back22").exists?)
    assert(@browser.link("Back").exists?)
    assert(@browser.accessor("document.getElementById('s1Id')").exists?)
  end

  def test_select()
    @browser.navigate_to(@base_url  + "/demo/formTest.htm")
    assert_equal("o1", @browser.select("s1Id[1]").selected_text())
    @browser.select("s1Id[1]").choose("o2")
    assert_equal("o2", @browser.select("s1Id[1]").selected_text())
  end

  def test_set_file()
    @browser.navigate_to(@base_url  + "/demo/php/fileUpload.htm")
    @browser.file("file").file = "scripts/demo/uploadme.txt";
    @browser.submit("Submit Single").click;
    assert(@browser.span("size").exists?)
    assert_not_nil(@browser.span("size").text().index("0.3046875 Kb"))
    assert_not_nil(@browser.span("type").text().index("Single"))
    @browser.link("Back to form").click;
  end

  def test_multi_file_upload()
    @browser.navigate_to(@base_url  + "/demo/php/fileUpload.htm")
    @browser.file("file[]").file = "scripts/demo/uploadme.txt";
    @browser.file("file[]").file = "scripts/demo/uploadme2.txt";
    @browser.submit("Submit Array").click;
    assert_not_nil(@browser.span("type").text().index("Array"))
    assert_not_nil(@browser.span("file").text().index("uploadme.txt"))
    assert_not_nil(@browser.span("size").text().index("0.3046875 Kb"))

    assert_not_nil(@browser.span("file[1]").text().index("uploadme2.txt"))
    assert_not_nil(@browser.span("size[1]").text().index("0.32421875 Kb"))
  end

  def test_clicks()
    @browser.navigate_to(@base_url  + "/demo/formTest.htm")
    assert_not_nil(@browser.checkbox("c1"))
    @browser.checkbox("c1").click;
    assert_equal("true", @browser.checkbox("c1").fetch("checked"))
    @browser.checkbox("c1").click;
    assert_equal("false", @browser.checkbox("c1").fetch("checked"))

    assert_not_nil(@browser.radio("r1"))
    @browser.radio("r1").click;
    assert_equal("true", @browser.radio("r1").fetch("checked"))
    assert(@browser.radio("r1").checked?)
    assert(!@browser.radio("r1[1]").checked?)
    @browser.radio("r1[1]").click;
    assert_equal("false", @browser.radio("r1").fetch("checked"))
    assert(@browser.radio("r1[1]").checked?)
    assert(!@browser.radio("r1").checked?)
  end

  def test_links()
    @browser.navigate_to(@base_url  + "/demo/index.htm")
    @browser.link("Link Test").click;
    @browser.link("linkByContent").click;
    @browser.link("Back").click;
    @browser.link("link with return true").click;
    assert(@browser.textarea("ta1").exists?)
    assert_equal("", @browser.textarea("ta1").value)
    @browser.link("Back").click;
    @browser.link("Link Test").click;
    @browser.link("link with return false").click;
    assert(@browser.textbox("t1").exists?)
    assert_equal("formTest link with return false", @browser.textbox("t1").value)
    assert(@browser.link("linkByContent").exists?)

    @browser.link("link with returnValue=false").click;
    assert(@browser.textbox("t1").exists?)
    assert_equal("formTest link with returnValue=false", @browser.textbox("t1").value)
    @browser.link("added handler using js").click;
    assert(@browser.textbox("t1").exists?)
    assert_equal("myFn called", @browser.textbox("t1").value)
    @browser.textbox("t1").value = ("")
    @browser.image("imgWithLink").click;
    @browser.link("Link Test").click;
    @browser.image("imgWithLinkNoClick").click;
    assert(@browser.textbox("t1").exists?)
    assert_equal("myFn called", @browser.textbox("t1").value)
    @browser.link("Back").click;
  end


  def test_popup_title_name_mix()
    @browser.navigate_to(@base_url  + "/demo/index.htm")
    @browser.link("Window Open Test").click;
    @browser.link("Window Open Test With Title").click;
    @browser.link("Table Test").click;

    popup_popwin = @browser.popup("popWin")

    popup_popwin.link("Link Test").click;
    @browser.link("Back").click;

    popup_with_title = @browser.popup("With Title")

    popup_with_title.link("Form Test").click;
    @browser.link("Table Test").click;
    popup_with_title.textbox("t1").value = ("d")
    @browser.link("Back").click;
    popup_with_title.textbox(1).value = ("e")
    @browser.link("Table Test").click;
    popup_with_title.textbox("name").value = ("f")
    assert_not_nil(popup_popwin.link("linkByHtml").exists?)

    assert_not_nil(@browser.cell("CellWithId"))
    assert_equal("Cell with id", @browser.cell("CellWithId").text)
    popup_with_title.link("Break Frames").click;

    popupSahiTests = @browser.popup("Sahi Tests")
    popupSahiTests.close()

    popup_popwin.link("Break Frames").click;
    popup_popwin.close()
    @browser.link("Back").click;
  end


  def test_in()
    @browser.navigate_to(@base_url  + "/demo/tableTest.htm")
    assert_equal("111", @browser.textarea("ta").near(@browser.cell("a1")).value)
    assert_equal("222", @browser.textarea("ta").near(@browser.cell("a2")).value)
    @browser.link("Go back").in(@browser.cell("a1").parent_node()).click;
    assert(@browser.link("Link Test").exists?)
  end

  def test_under()
    @browser.navigate_to(@base_url  + "/demo/tableTest.htm")
    assert_equal("x1-2", @browser.cell(0).near(@browser.cell("x1-0")).under(@browser.tableHeader("header 3")).text());
    assert_equal("x1-3", @browser.cell(0).near(@browser.cell("x1-0")).under(@browser.tableHeader("header 4")).text());
  end

  def test_exists()
    @browser.navigate_to(@base_url  + "/demo/index.htm")
    assert(@browser.link("Link Test").exists?)
    assert(!@browser.link("Link Test NonExistent").exists?)
  end

  def alert1(message)
    @browser.navigate_to(@base_url  + "/demo/alertTest.htm")
    @browser.textbox("t1").value = ("Message " + message)
    @browser.button("Click For Alert").click;
    @browser.navigate_to("/demo/alertTest.htm")
    sleep(1)
    assert_equal("Message " + message, @browser.last_alert())
    @browser.clear_last_alert()
    assert_nil(@browser.last_alert())
  end

  def test_alert()
    alert1("One")
    alert1("Two")
    alert1("Three")
    @browser.button("Click For Multiline Alert").click;
    assert_equal("You must correct the following Errors:\nYou must select a messaging price plan.\nYou must select an international messaging price plan.\nYou must enter a value for the Network Lookup Charge", @browser.last_alert())
  end

  def test_confirm()
    @browser.navigate_to(@base_url  + "/demo/confirmTest.htm")
    @browser.expect_confirm("Some question?", true)
    @browser.button("Click For Confirm").click;
    assert_equal("oked", @browser.textbox("t1").value)
    @browser.navigate_to("/demo/confirmTest.htm")
    sleep(1)
    assert_equal("Some question?", @browser.last_confirm())
    @browser.clear_last_confirm()
    assert_nil(@browser.last_confirm())

    @browser.expect_confirm("Some question?", false)
    @browser.button("Click For Confirm").click;
    assert_equal("canceled", @browser.textbox("t1").value)
    assert_equal("Some question?", @browser.last_confirm())
    @browser.clear_last_confirm()
    assert_nil(@browser.last_confirm())

    @browser.expect_confirm("Some question?", true)
    @browser.button("Click For Confirm").click;
    assert_equal("oked", @browser.textbox("t1").value)
    assert_equal("Some question?", @browser.last_confirm())
    @browser.clear_last_confirm()
    assert_nil(@browser.last_confirm())
  end

  def test_prompt()
    @browser.navigate_to(@base_url  + "/demo/promptTest.htm")
    @browser.expect_prompt("Some prompt?", "abc")
    @browser.button("Click For Prompt").click;
    assert_not_nil(@browser.textbox("t1"))
    assert_equal("abc", @browser.textbox("t1").value)
    @browser.navigate_to("/demo/promptTest.htm")
    @browser.waitFor(2000)
    assert_equal("Some prompt?", @browser.last_prompt())
    @browser.clear_last_prompt()
    assert_nil(@browser.last_prompt())
  end


  def test_visible
    @browser.navigate_to(@base_url  + "/demo/index.htm")
    @browser.link("Visible Test").click;
    assert(@browser.spandiv("using display").visible?)

    @browser.button("Display none").click;
    assert(!@browser.spandiv("using display").visible?)
    @browser.button("Display block").click;
    assert(@browser.spandiv("using display").visible?)

    @browser.button("Display none").click;
    assert(!@browser.spandiv("using display").visible?)
    @browser.button("Display inline").click;
    assert(@browser.spandiv("using display").visible?)

    assert(@browser.spandiv("using visibility").visible?)
    @browser.button("Visibility hidden").click;
    assert(!@browser.spandiv("using visibility").visible?)
    @browser.button("Visibility visible").click;
    assert(@browser.spandiv("using visibility").visible?)

    assert(!@browser.byId("nestedBlockInNone").visible?)
    assert(!@browser.byId("absoluteNestedBlockInNone").visible?)
  end

  def test_check()
    @browser.navigate_to(@base_url  + "/demo/")
    @browser.link("Form Test").click;
    assert_equal("false", @browser.checkbox("c1").fetch("checked"))
    assert(!@browser.checkbox("c1").checked?)
    @browser.checkbox("c1").check()
    assert_equal("true", @browser.checkbox("c1").fetch("checked"))
    assert(@browser.checkbox("c1").checked?)
    @browser.checkbox("c1").check()
    assert_equal("true", @browser.checkbox("c1").fetch("checked"))
    @browser.checkbox("c1").uncheck()
    assert_equal("false", @browser.checkbox("c1").fetch("checked"))
    @browser.checkbox("c1").uncheck()
    assert_equal("false", @browser.checkbox("c1").fetch("checked"))
    @browser.checkbox("c1").click;
    assert_equal("true", @browser.checkbox("c1").fetch("checked"))
  end

  def test_focus()
    @browser.navigate_to(@base_url  + "/demo/focusTest.htm")
    @browser.textbox("t2").focus()
    assert_equal("focused", @browser.textbox("t1").value)
    @browser.textbox("t2").remove_focus()
    assert_equal("not focused", @browser.textbox("t1").value)
    @browser.textbox("t2").focus()
    assert_equal("focused", @browser.textbox("t1").value)
  end

  def test_title()
    @browser.navigate_to(@base_url  + "/demo/index.htm")
    assert_equal("Sahi Tests", @browser.title)
    @browser.link("Form Test").click;
    assert_equal("Form Test", @browser.title)
    @browser.link("Back").click;
    @browser.link("Window Open Test With Title").click;
    assert_equal("With Title", @browser.popup("With Title").title)
  end

  def test_area()
    @browser.navigate_to(@base_url  + "/demo/map.htm")
    @browser.navigate_to("map.htm")
    assert(@browser.area("Record").exists?)
    assert(@browser.area("Playback").exists?)
    assert(@browser.area("Info").exists?)
    assert(@browser.area("Circular").exists?)
    @browser.area("Record").mouse_over()
    assert_equal("Record", @browser.div("output").text)
    @browser.button("Clear").mouse_over()
    assert_equal("", @browser.div("output").text)
    @browser.area("Record").click;
    assert(@browser.link("linkByContent").exists?)
    #@browser.navigate_to("map.htm")
  end

  def test_dragdrop()
    @browser.navigate_to("http://www.snook.ca/technical/mootoolsdragdrop/")
    @browser.div("Drag me").drag_and_drop_on(@browser.div("Item 2"))
    assert @browser.div("dropped").exists?
    assert @browser.div("Item 1").exists?
    assert @browser.div("Item 3").exists?
    assert @browser.div("Item 4").exists?
  end

  def test_wait()
    @browser.navigate_to(@base_url  + "/demo/waitCondition1.htm")
    @browser.wait(15) {"populated" == @browser.textbox("t1").value}
    assert_equal("populated", @browser.textbox("t1").value)
  end

  def test_google()
    @browser.navigate_to("http://www.google.com")
    @browser.textbox("q").value = "sahi forums"
    @browser.submit("Google Search").click
    @browser.link("Sahi - Web Automation and Test Tool").click
    @browser.link("Login").click
    assert @browser.textbox("req_username").visible?
  end

  def test_dblclick()
    @browser.navigate_to("#{@base_url}/demo/clicks.htm")
    @browser.div("dbl click me").dblclick
    assert_equal("[DOUBLE_CLICK]", @browser.textarea("t2").value)
    @browser.button("Clear").click
  end

  def test_right_click()
    @browser.navigate_to("#{@base_url}/demo/clicks.htm")
    @browser.div("right click me").right_click
    assert_equal("[RIGHT_CLICK]", @browser.textarea("t2").value)
    @browser.button("Clear").click
  end

  def test_different_domains()
    @browser.navigate_to("#{@base_url}/demo/")
    @browser.link("Different Domains External").click
    domain_tyto = @browser.domain("www.tytosoftware.com")
    domain_bing = @browser.domain("www.bing.com")

    domain_tyto.link("Link Test").click
    domain_bing.textbox("q").value = "fdsfsd"

    domain_tyto.link("Back").click
    domain_bing.div("bgDiv").click

    @browser.navigate_to("#{@base_url}/demo/");
  end

  def test_browser_types()
    @browser.navigate_to("#{@base_url}/demo/")
    if (@browser_name == "firefox")
      assert(!@browser.ie?())
      assert(@browser.firefox?())
    elsif (@browser_name == "ie")
      assert(@browser.ie?())
      assert(!@browser.firefox?())
    end
  end

  def test_browser_js()
		@browser.browser_js = "function giveMyNumber(){return '23';}"
		@browser.navigate_to("#{@base_url}/demo/")
		assert_equal("23", @browser.fetch("giveMyNumber()"))
		@browser.link("Link Test").click()
		assert_equal("23", @browser.fetch("giveMyNumber()"))
		@browser.link("Back").click()
  end

  def test_count()
    @browser.navigate_to("#{@base_url}/demo/count.htm")
    assert_equal(4, @browser.link("group 0 link").count_similar())
	assert_equal(0, @browser.link("group non existent link").count_similar());
	assert_equal(5, @browser.link("/group 1/").count_similar());
	assert_equal(2, @browser.link("/group 1/").in(@browser.div("div1")).count_similar());    
  end
  
  def test_collect()
    @browser.navigate_to("#{@base_url}/demo/count.htm")
	els = @browser.link("/group 1/").collect_similar();
	assert_equal(5, els.size());
	assert_equal("group 1 link1", els[0].text);
	assert_equal("group 1 link2", els[1].text);

	@browser.navigate_to("#{@base_url}/demo/count.htm")
	els2 = @browser.link("/group 1/").in(@browser.div("div1")).collect_similar();
	assert_equal(2, els2.size());
	assert_equal("group 1 link3", els2[0].text);
	assert_equal("group 1 link4", els2[1].text);
  end
  
  def test_strict_visible()
  	@browser.navigate_to("#{@base_url}/demo/strict_visible.htm")
	assert_equal("b", @browser.textbox("q[1]").value)
	@browser.strict_visibility_check = true
	assert_equal("c", @browser.textbox("q[1]").value)
	@browser.strict_visibility_check = true
	assert_equal("b", @browser.textbox("q[1]").value)
  end

end
