package net.sf.sahi.stream.filter;

import java.io.IOException;

import net.sf.sahi.config.Configuration;
import net.sf.sahi.stream.filter.HTMLModifierFilter;

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
public class HTMLModifierFilterTest extends AbstractFilterTestCase {
	private static final long serialVersionUID = -8595824041373557849L;


	static{
		Configuration.init();
	}

	String injectionTop = "<X x><Y y>";
	String injectionBottom = "<Z z>";

	private String getFiltered(String[] ss, boolean isXHTML) throws IOException {
		String charset = "utf-8";
		HTMLModifierFilter modifierFilter = new HTMLModifierFilterWithInjectContent(charset, isXHTML, false);
		return getFiltered(ss, modifierFilter, charset);
	}

	public void testSingleLine() throws IOException {
		String output;
		String s1 = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />";
		output = getFiltered(new String[] { s1 }, false);
		assertEquals(
				injectionTop + "<html>" 
				+"<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />"
				+ injectionBottom
				,
				output);
	}
	
	public void testSingleLineXHTML() throws IOException {
		String output;
		String s1 = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">" +
				"<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />";
		output = getFiltered(new String[] { s1 }, true);
		assertEquals(
				"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">" +
				"<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>" + injectionTop 
				+"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />"
				,
				output);
	}

	public void testMultiLine1() throws IOException {
		String output;
		String s1 = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\"";
		String s2 = "><html xmlns=\"http://www.w3.org/1999/xhtml\"><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />";
		output = getFiltered(new String[] { s1, s2 }, true);
		assertEquals(
				"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">" +
				"<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>"+injectionTop+
				"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />",
				output);
	}


	class HTMLModifierFilterWithInjectContent extends HTMLModifierFilter {

		public HTMLModifierFilterWithInjectContent(String charset, boolean isXHTML, boolean isSSL) {
			super(charset, isXHTML, isSSL);
		}

		protected String getInjectAtTop() {
			return injectionTop;
		}
		protected String getInjectAtBottom() {
			return injectionBottom;
		}

	}
}