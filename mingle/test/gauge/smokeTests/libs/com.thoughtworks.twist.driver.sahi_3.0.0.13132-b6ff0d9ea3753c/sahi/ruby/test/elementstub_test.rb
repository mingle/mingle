require 'test/unit'
require '../lib/sahi'

class TC_MyTest < Test::Unit::TestCase
  # def setup
  # end

  # def teardown
  # end

  def test_to_s_single()
    assert_equal("_sahi._div(\"id\")", Sahi::ElementStub.new(nil, "div", ["id"]).to_s())
    assert_equal("_sahi._lastAlert()",  Sahi::ElementStub.new(nil, "lastAlert", []).to_s())
  end
  
  def test_to_s_multi_strings()
    assert_equal("_sahi._div(\"id\", \"id2\")", Sahi::ElementStub.new(nil, "div", ["id", "id2"]).to_s())
  end
  
  def test_to_s_multi_stubs()
    stub2 = Sahi::ElementStub.new(nil, "div", ["id2"])
    near = Sahi::ElementStub.new(nil, "near", [stub2])
    stub1 = Sahi::ElementStub.new(nil, "div", ["id1", near])
    assert_equal("_sahi._div(\"id1\", _sahi._near(_sahi._div(\"id2\")))", stub1.to_s())
  end
  
  def test_browser_multi_stubs()
    browser = Sahi::Browser.new("", "", "")
    assert_equal("_sahi._div(\"id\")", browser.div("id").to_s)
    assert_equal("_sahi._div(\"id\", \"id2\")", browser.div("id", "id2").to_s())
    assert_equal("_sahi._div(\"id1\", _sahi._near(_sahi._div(\"id2\")))", browser.div("id1").near(browser.div("id2")).to_s())
  end
  
  def test_xy()
    browser = Sahi::Browser.new("", "", "")
    assert_equal("_sahi._xy(_sahi._div(\"id\"), 10, 20)", browser.div("id").xy(10, 20).to_s)
  end  
end