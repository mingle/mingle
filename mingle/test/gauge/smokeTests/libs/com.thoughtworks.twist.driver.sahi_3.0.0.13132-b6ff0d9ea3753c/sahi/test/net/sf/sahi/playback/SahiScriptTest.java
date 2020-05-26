package net.sf.sahi.playback;

import java.util.ArrayList;
import java.util.List;
import java.io.IOException;

import net.sf.sahi.config.Configuration;

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
public class SahiScriptTest extends TestCase {
	static {
		Configuration.init();
	}
	
	private static final long serialVersionUID = -3933249717685341073L;
    TestScript testScript = new TestScript("scrName", null, "scrName");

	public void testGetInclude() {
		assertEquals("prof.sah", SahiScript
				.getInclude("/*asdad*/ _include(\"prof.sah\"); //asdasd\n"));
	}

	public void testGetIncludeSingleQuote() {
		assertEquals("prof.sah", SahiScript.getInclude("_include('prof.sah')"));
	}

	public void testModify() {
        assertEquals("_sahi.schedule(\"_sahi._assertEqual(_sahi._table(\\\"aa\\\"))\", \"scrName&n=1\");\r\n",
                testScript.modify("_assertEqual(_table(\"aa\"))"));

		assertEquals("_sahi._assertEqual(_sahi._table(\"aa\"))\r\n", testScript
				.modify("__assertEqual(_table(\"aa\"))"));

		assertEquals("if(_sahi._table(\"aa\"))\r\n", testScript.modify("if(_table(\"aa\"))"));

		assertEquals(
				"_sahi.schedule(\"_sahi._setGlobal(\\\"newFinanceTypeName\\\", \'sahiTestFT\'+_sahi._random(10000))\", \"scrName&n=1\");\r\n",
				testScript
						.modify("_setGlobal(\"newFinanceTypeName\", \'sahiTestFT\'+_random(10000))"));

		assertEquals("var $n = _sahi._getGlobal(\"nv\");\r\n", testScript
				.modify("var $n = _getGlobal(\"nv\");\r\n"));

		assertEquals("var $n = _sahi._getGlobal(\"nv\");\r\n", testScript
				.modify("var $n = _sahi._getGlobal(\"nv\");\r\n"));

		assertEquals("_sahi._setGlobal(\"n\", \'aa\'+_sahi._random(10000));\r\n", testScript
				.modify("_sahi._setGlobal(\"n\", \'aa\'+_random(10000));"));

		assertEquals("_sahi._textbox(\"username\").value=\"kk\";\r\n", testScript
				.modify("_textbox(\"username\").value=\"kk\";"));

		assertEquals("_sahi._textbox(\"username\").value=\"kk\";\r\n", testScript
				.modify("__textbox(\"username\").value=\"kk\";"));
		assertEquals("_sahi.schedule(\"_sahi._call(fn1())\", \"scrName&n=1\");\r\n", testScript
				.modify("_call(fn1())"));

        assertEquals("_sahi.schedule(\"_sahi._click(\"+s_v($ar[$i[1][\"COL\"]])+\")\", \"scrName&n=1\");\r\n", testScript
				.modify("_click($ar[$i[1][\"COL\"]])"));

	}

	public void testKeywordsAsASubstringFails() {
		assertEquals(
				"_sahi.schedule(\"_sahi._setValue(_sahi._textbox (\\\"form_loginname\\\"), \\\"narayanraman\\\");\", \"scrName&n=1\");\r\n",
				testScript
						.modify("_setValue(_textbox (\"form_loginname\"), \"narayanraman\");"));
	}

	public void testModifyFunctionNames() {
		assertEquals("_sahi._setGlobal(", TestScript.modifyFunctionNames("_setGlobal("));
		assertEquals("_insert  (", TestScript.modifyFunctionNames("_insert  ("));
		assertEquals("_sahi._setValue (", TestScript.modifyFunctionNames("__setValue ("));
	}

	public void testGetRegExp() {
		ArrayList<String> keywords = new ArrayList<String>();
		keywords.add("_accessor");
		keywords.add("_alert");
		assertEquals("_sahi._?(_accessor|_alert)(\\s*\\()", TestScript.getRegExp(true, keywords));
	}

	public void testGetActionRegExp() {
		ArrayList<String> keywords = new ArrayList<String>();
		keywords.add("_alert");
		keywords.add("_assertEqual");
		assertEquals("^(?:_alert|_assertEqual)\\s*\\(.*", TestScript.getActionRegExp(keywords));
	}

	public void testLineStartsWithActionKeyword() {
		assertTrue(TestScript.lineStartsWithActionKeyword("_alert()"));
	}

	public void xtestEfficiency() {
		long start = System.currentTimeMillis();
		TestScript.lineStartsWithActionKeyword("_alert()");

		for (int i = 0; i < 10000; i++) {
			TestScript.lineStartsWithActionKeyword("_alert()");
		}
		long t1 = System.currentTimeMillis() - start;

		start = System.currentTimeMillis();
		for (int i = 0; i < 10000; i++) {
			TestScript.lineStartsWithActionKeyword("_alert()");
		}
		long t2 = System.currentTimeMillis() - start;
		System.out.println(t1 + "\n" + t2);
	}

	public void testRegEx() {
		assertEquals("sahi_alert", "__alert".replaceAll("_?(_alert)", "sahi$1"));
		assertEquals("sahi_alert", "_alert".replaceAll("_?(_alert)", "sahi$1"));
	}

	class TestScript extends SahiScript {
        public TestScript() {
            super(null, new ArrayList<String>(), null);
        }

        public TestScript(String fileName, ArrayList<String> parents, String scriptName) {
            super(fileName, parents, scriptName);
        }

        String getFQN(String include) {
            return null;
        }

		SahiScript getNewInstance(String scriptName, ArrayList<?> parentScriptName) {
			return null;
		}

		protected void loadScript(String url) {
		}
	}

	public void testBrackets() {
		assertEquals("axx", "a((".replaceAll("\\(", "x"));
		assertEquals("sahi_log (form_login", "_log (form_login".replaceAll(
				"_?(_log|_textbox)(\\s*\\()", "sahi$1$2"));
		assertEquals("sahi_log(form_login", "_log(form_login".replaceAll(
				"_?(_log|_textbox)(\\s*\\()", "sahi$1$2"));
		assertTrue("_assertEqual(".matches("^(_assertEqual)\\s*\\("));
		assertTrue("_assertEqual           (".matches("^(_assertEqual)\\s*\\("));
	}

	public void testGetActionKeywords() {
		List<?> keywords = SahiScript.getActionKeyWords();
		assertTrue(keywords.contains("_alert"));
		assertTrue(keywords.contains("_assertEqual"));
		assertTrue(keywords.contains("_assertNotEqual"));
		assertTrue(keywords.contains("_assertNotNull"));
		assertTrue(keywords.contains("_assertNull"));
		assertTrue(keywords.contains("_assertTrue"));
		assertTrue(keywords.contains("_assertNotTrue"));
		assertTrue(keywords.contains("_click"));
		assertTrue(keywords.contains("_clickLinkByAccessor"));
		assertTrue(keywords.contains("_dragDrop"));
		assertTrue(keywords.contains("_setSelected"));
		assertTrue(keywords.contains("_setValue"));
		assertTrue(keywords.contains("_simulateEvent"));
		assertTrue(keywords.contains("_call"));
		assertTrue(keywords.contains("_eval"));
		assertTrue(keywords.contains("_setGlobal"));
		assertTrue(keywords.contains("_wait"));
		assertTrue(keywords.contains("_popup"));
		assertTrue(keywords.contains("_highlight"));
		assertTrue(keywords.contains("_log"));
		assertTrue(keywords.contains("_navigateTo"));
	}

	public void testGetKeywords() {
		List<?> keywords = SahiScript.getKeyWords();
		assertTrue(keywords.contains("_accessor"));
		assertTrue(keywords.contains("_alert"));
		assertTrue(keywords.contains("_assertEqual"));
		assertTrue(keywords.contains("_assertNotEqual"));
		assertTrue(keywords.contains("_assertNotNull"));
		assertTrue(keywords.contains("_assertNull"));
		assertTrue(keywords.contains("_assertTrue"));
		assertTrue(keywords.contains("_assertNotTrue"));
		assertTrue(keywords.contains("_button"));
		assertTrue(keywords.contains("_checkbox"));
		assertTrue(keywords.contains("_click"));
		assertTrue(keywords.contains("_clickLinkByAccessor"));
		assertTrue(keywords.contains("_dragDrop"));
		assertTrue(keywords.contains("_getCellText"));
		assertTrue(keywords.contains("_getSelectedText"));
		assertTrue(keywords.contains("_image"));
		assertTrue(keywords.contains("_imageSubmitButton"));
		assertTrue(keywords.contains("_link"));
		assertTrue(keywords.contains("_password"));
		assertTrue(keywords.contains("_radio"));
		assertTrue(keywords.contains("_select"));
		assertTrue(keywords.contains("_setSelected"));
		assertTrue(keywords.contains("_setValue"));
		assertTrue(keywords.contains("_simulateEvent"));
		assertTrue(keywords.contains("_submit"));
		assertTrue(keywords.contains("_textarea"));
		assertTrue(keywords.contains("_textbox"));
		assertTrue(keywords.contains("_event"));
		assertTrue(keywords.contains("_call"));
		assertTrue(keywords.contains("_eval"));
		assertTrue(keywords.contains("_setGlobal"));
		assertTrue(keywords.contains("_getGlobal"));
		assertTrue(keywords.contains("_wait"));
		assertTrue(keywords.contains("_random"));
		assertTrue(keywords.contains("_savedRandom"));
		assertTrue(keywords.contains("_cell"));
		assertTrue(keywords.contains("_table"));
		assertTrue(keywords.contains("_containsText"));
		assertTrue(keywords.contains("_containsHTML"));
		assertTrue(keywords.contains("_popup"));
		assertTrue(keywords.contains("_byId"));
		assertTrue(keywords.contains("_highlight"));
		assertTrue(keywords.contains("_log"));
		assertTrue(keywords.contains("_navigateTo"));
	}

    public void testUnicode() throws IOException {
//        assertEquals("??", "\u4E2D\u6587");
//        File file = new File("C:\\unicode.txt");
//        FileOutputStream out = new FileOutputStream(file);
        String s = "\u4E2D\u6587";
        assertEquals(2, s.getBytes().length);
        assertEquals("\u4E2D\u6587", "\u4e2d\u6587");
//        out.write(s.getBytes("UTF-16"));
//        out.close();
//        System.out.print("\u4E2D\u6587");
    }

    public void testFindCondition(){
        assertEquals("'' == _textbox(\"t1\").value", testScript.findCondition("_condition('' == _textbox(\"t1\").value)"));
        assertEquals("'$x' == _textbox(\"t1\").value", testScript.findCondition("_condition('$x' == _textbox(\"t1\").value)"));
    }
    
    public void testIsSet() throws Exception {
    	assertTrue(testScript.isSet("_set($a, \"abc\")"));
    	assertFalse(testScript.isSet("_setValue(xxx, \"abc\")"));
    	assertTrue(testScript.isSet("_popup(\"abc\")._set($a, \"abc\")"));
    	assertTrue(testScript.isSet("_popup($win)._set($a, \"abc\")"));    	
    	assertFalse(testScript.isSet("_xx_set(xxx, \"abc\")"));
	}

    public void testModifyConditionWithTwo$Vars() throws Exception {
		assertEquals("if (_sahi._condition(\"\"+s_v($a)+\"==\"+s_v($b)+\"\", \"scrName&n=0\"))", testScript.modifyCondition("if (_condition($a==$b))", 0));
    }
    
    public void testModifyCondition() throws Exception {
		assertEquals("if (_sahi._condition(\"a==b\", \"scrName&n=0\"))", testScript.modifyCondition("if (_condition(a==b))", 0));
		assertEquals("if (_sahi._condition(\"\"+s_v($i)+\"==10\", \"scrName&n=0\"))", testScript.modifyCondition("if (_condition($i==10))", 0));
		assertEquals("if (_sahi._condition(\"\"+s_v($x[$i])+\"==10\", \"scrName&n=0\"))", testScript.modifyCondition("if (_condition($x[$i]==10))", 0));
			assertEquals("if (_sahi._condition(\"_sahi._link('a').href == \\\"abcd\\\"\", \"scrName&n=0\"))", testScript.modifyCondition("if (_condition(_link('a').href == \"abcd\"))", 0));
	}

//    public void testIf(){
//        assertEquals("_sahi.schedule(\"_sahi.saveCondition('' == _sahi._textbox(\\\"t1\\\").value);\", \"scrName&n=10\");\r\nif (\"true\" == _sahi.getServerVar(\"condn\")) {",
//                testScript.modifyIf("if (_condition('' == _textbox(\"t1\").value)) {", 10));
//    }

    public void testWait(){
        assertEquals("_sahi.executeWait(\"_sahi._wait(1000, \\\"_sahi._byId(\\\\\\\"abc\\\\\\\")\\\");\", \"scrName&n=12\");\r\n", testScript.modifyWait("_wait(1000, _byId(\"abc\"))", 12));
        assertEquals("_sahi.executeWait(\"_sahi._wait(1000, \\\"_sahi._byId(\\\"+s_v(\"+s_v($abc)+\")+\\\")\\\");\", \"scrName&n=12\");\r\n", testScript.modifyWait("_wait(1000, _byId($abc))", 12));
    }

	public void testProcessSet() {
//		String tempVarName = "$aaaa[$i]".replaceAll("[$]", "\\\\\\$");
//		System.out.println("tempVarName="+tempVarName);		
		assertEquals("_sahi.schedule(\"_sahi.setServerVar('abc', document.links);\", \"scrName&n=23\");\r\nabc = _sahi.getServerVar('abc');\r\n", testScript.processSet("_set(abc, document.links)", 23));
		assertEquals("_sahi.schedule(\"_sahi.setServerVar('abc', getLinks());\", \"scrName&n=23\");\r\nabc = _sahi.getServerVar('abc');\r\n", testScript.processSet("_set(  	abc, getLinks())", 23));
		assertEquals("_sahi.schedule(\"_sahi.setServerVar('\\\\$abc', getLinks());\", \"scrName&n=23\");\r\n$abc = _sahi.getServerVar('\\$abc');\r\n", testScript.processSet("_set(  	$abc, getLinks())", 23));
		assertEquals("_sahi.schedule(\"_sahi.setServerVar('\\\\$abc[\\\\$i]', getLinks());\", \"scrName&n=23\");\r\n$abc[$i] = _sahi.getServerVar('\\$abc[\\$i]');\r\n", testScript.processSet("_set(  	$abc[$i], getLinks())", 23));
		assertEquals("_sahi.schedule(\"_sahi._popup('win')._sahi.setServerVar('abc', document.links);\", \"scrName&n=23\");\r\nabc = _sahi.getServerVar('abc');\r\n", 
				testScript.processSet("_popup('win')._set(abc, document.links)", 23));
	}

	public void testRemoveBrowserJS(){
		assertEquals("a                  \n              b                                c", testScript.removeBrowserJS("a <browser> asbs sd\n sd </browser>b<browser> asbs sd sd </browser> c"));
	}

	public void test2Params(){
		assertEquals("_assertEqual(\\\"Rs. 18\\\", \"+s_v($table.get(\"Soap\", \"Price\"))+\");", 
				SahiScript.separateVariables("_assertEqual(\"Rs. 18\", $table.get(\"Soap\", \"Price\"));"));
		assertEquals("_assertEqual(\\\"Rs. 18\\\", \"+s_v($table.get(\"Soap\",\t\"Price\"))+\");", 
				SahiScript.separateVariables("_assertEqual(\"Rs. 18\", $table.get(\"Soap\",\t\"Price\"));"));
	}
	
	public void testExtractBrowserJS(){
		assertEquals("  alert(123);\n  print('abc');\n", testScript.extractBrowserJS("a <browser>\n  alert(123);\n</browser>\nb\n<browser>\n  print('abc');\n</browser>\nc\n", false));
	}
	
	public void testWhiteSpaces(){
		assertEquals("a();\r\n\r\nb();\r\n", testScript.modify("a();\r\n\r\nb();"));
		assertEquals("a();\r\n\r\nb();\r\n", testScript.modify("a();\r\n\r\nb();\r\n"));
	}
	
	public void testQuotedDollarVariables(){
		assertEquals("_sahi.schedule(\"_sahi.setServerVar('abc', \\\"$url\\\");\", \"scrName&n=23\");\r\nabc = _sahi.getServerVar('abc');\r\n", testScript.processSet("_set(abc, \"$url\")", 23));
	}
	
	public void testSeparateVariablesNoDollar(){
		assertEquals("_setValue(_textbox(1), \\\"url\\\")", SahiScript.separateVariables("_setValue(_textbox(1), \"url\")"));
	}
	
	public void testSeparateVariablesWithQuotedDollar(){
		assertEquals("_setValue(_textbox(1), \\\"$url\\\")", SahiScript.separateVariables("_setValue(_textbox(1), \"$url\")"));
	}

	public void testSeparateVariablesWithDollar(){
		assertEquals("_setValue(_textbox(1), \"+s_v($url)+\")", SahiScript.separateVariables("_setValue(_textbox(1), $url)"));
	}
	
	public void testSeparateVariablesWith2Dollar(){
		assertEquals("\"\"+s_v($a)+\"==\"+s_v($b)+\"\"", "\"" + SahiScript.separateVariables("$a==$b") + "\"");
		assertEquals("\"_setValue(\"+s_v($a)+\", \"+s_v($b)+\")\"", "\"" + SahiScript.separateVariables("_setValue($a, $b)") + "\"");
	}

	public void testSeparateVariablesWithRegExp(){
		assertEquals("_assertEqual(\"+s_v($fullFilePath.replace(/\\/g, '/'))+\", 'a');", SahiScript.separateVariables("_assertEqual($fullFilePath.replace(/\\/g, '/'), 'a');"));
		assertEquals("_assertEqual(\"+s_v($fullFilePath.replace(/\\/g, '/'))+\", \"+s_v($resolvedPath.replace(/\\/g, '/'))+\");", SahiScript.separateVariables("_assertEqual($fullFilePath.replace(/\\/g, '/'), $resolvedPath.replace(/\\/g, '/'));"));
	}
	
	public void testNormalizeNewLinesForOSes() throws Exception {
		assertEquals("a\nb\nc", testScript.normalizeNewLinesForOSes("a\r\nb\r\nc"));
		assertEquals("a\nb\nc", testScript.normalizeNewLinesForOSes("a\nb\nc"));
		assertEquals("a\nb\nc", testScript.normalizeNewLinesForOSes("a\rb\rc"));
		assertEquals("a\nb\n\nc", testScript.normalizeNewLinesForOSes("a\nb\n\nc"));
		assertEquals("a\nb\n\nc", testScript.normalizeNewLinesForOSes("a\rb\r\rc"));
		assertEquals("a\nb\n\nc", testScript.normalizeNewLinesForOSes("a\r\nb\r\n\r\nc"));
	}

}
