package net.sf.sahi.client;

import junit.framework.TestCase;

/**
 * Sahi - Web Automation and Test Tool
 * 
 * Copyright  2006  V Narayan Raman
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
public class SahiBrowserTestCase extends TestCase {
	private static final long serialVersionUID = -7323657270745640059L;
	private Browser browser;
	public ElementStub _accessor(Object... args) {return new ElementStub("accessor", browser, args);}
	public ElementStub _button(Object... args) {return new ElementStub("button", browser, args);}
	public ElementStub _check(Object... args) {return new ElementStub("check", browser, args);}
	public ElementStub _checkbox(Object... args) {return new ElementStub("checkbox", browser, args);}
	public ElementStub _image(Object... args) {return new ElementStub("image", browser, args);}
	public ElementStub _imageSubmitButton(Object... args) {return new ElementStub("imageSubmitButton", browser, args);}
	public ElementStub _link(Object... args) {return new ElementStub("link", browser, args);}
	public ElementStub _password(Object... args) {return new ElementStub("password", browser, args);}
	public ElementStub _radio(Object... args) {return new ElementStub("radio", browser, args);}
	public ElementStub _select(Object... args) {return new ElementStub("select", browser, args);}
	public ElementStub _submit(Object... args) {return new ElementStub("submit", browser, args);}
	public ElementStub _textarea(Object... args) {return new ElementStub("textarea", browser, args);}
	public ElementStub _textbox(Object... args) {return new ElementStub("textbox", browser, args);}
	public ElementStub _event(Object... args) {return new ElementStub("event", browser, args);}
	public ElementStub _cell(Object... args) {return new ElementStub("cell", browser, args);}
	public ElementStub _table(Object... args) {return new ElementStub("table", browser, args);}
	public ElementStub _containsText(Object... args) {return new ElementStub("containsText", browser, args);}
	public ElementStub _containsHTML(Object... args) {return new ElementStub("containsHTML", browser, args);}
	public ElementStub _byId(Object... args) {return new ElementStub("byId", browser, args);}
	public ElementStub _row(Object... args) {return new ElementStub("row", browser, args);}
//	public ElementStub _getText(Object... args) {return new ElementStub("getText", args);}
//	public ElementStub _getCellText(Object... args) {return new ElementStub("getCellText", args);}
	public ElementStub _div(Object... args) {return new ElementStub("div", browser, args);}
	public ElementStub _span(Object... args) {return new ElementStub("span", browser, args);}
	public ElementStub _spandiv(Object... args) {return new ElementStub("spandiv", browser, args);}
	public ElementStub _option(Object... args) {return new ElementStub("option", browser, args);}
	public ElementStub _lastConfirm(Object... args) {return new ElementStub("lastConfirm", browser, args);}
	public ElementStub _reset(Object... args) {return new ElementStub("reset", browser, args);}
	public ElementStub _file(Object... args) {return new ElementStub("file", browser, args);}
	public ElementStub _lastPrompt(Object... args) {return new ElementStub("lastPrompt", browser, args);}
	public ElementStub _lastAlert(Object... args) {return new ElementStub("lastAlert", browser, args);}
	public ElementStub _get(Object... args) {return new ElementStub("get", browser, args);}
	public ElementStub _style(Object... args) {return new ElementStub("style", browser, args);}
	public ElementStub _byText(Object... args) {return new ElementStub("byText", browser, args);}
	public ElementStub _cookie(Object... args) {return new ElementStub("cookie", browser, args);}
	public ElementStub _position(Object... args) {return new ElementStub("position", browser, args);}
	public ElementStub _label(Object... args) {return new ElementStub("label", browser, args);}
	public ElementStub _rteHTML(Object... args) {return new ElementStub("rteHTML", browser, args);}
	public ElementStub _rteText(Object... args) {return new ElementStub("rteText", browser, args);}
	public ElementStub _prompt(Object... args) {return new ElementStub("prompt", browser, args);}
	public ElementStub _isVisible(Object... args) {return new ElementStub("isVisible", browser, args);}
	public ElementStub _listItem(Object... args) {return new ElementStub("listItem", browser, args);}
	public ElementStub _parentNode(Object... args) {return new ElementStub("parentNode", browser, args);}
	public ElementStub _parentCell(Object... args) {return new ElementStub("parentCell", browser, args);}
	public ElementStub _parentRow(Object... args) {return new ElementStub("parentRow", browser, args);}
	public ElementStub _parentTable(Object... args) {return new ElementStub("parentTable", browser, args);}
	public ElementStub _in(Object... args) {return new ElementStub("in", browser, args);}
	public ElementStub _near(Object... args) {return new ElementStub("near", browser, args);}
	public ElementStub _rte(Object... args) {return new ElementStub("rte", browser, args);}
	public ElementStub _iframe(Object... args) {return new ElementStub("iframe", browser, args);}
	public String _getText(ElementStub _cell) {
		return null;
	}
	public void _click(ElementStub link) {
	}
	public void _setValue(ElementStub textbox, String string) {
	}
	public void _navigateTo(String string) {
	}
	public void initBrowser(String browserName){
		this.browser = new Browser(browserName);
	}
}