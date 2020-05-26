/**
 * User: nraman
 * Date: May 18, 2005
 * Time: 10:19:59 PM
 */
package net.sf.sahi.playback;

import junit.framework.TestCase;
import net.sf.sahi.config.Configuration;
import net.sf.sahi.util.Utils;

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
public class ScriptHandlerTest extends TestCase {
	static {
		Configuration.init();
	}
	private static final long serialVersionUID = 6341354901708835100L;
	private SahiScript script;

    protected void setUp() {
        script = new MockFileScript("fileName");
    }

    public void testModify() {
        assertEquals("_sahi.schedule(\"_sahi._setValue ( elements['username'] , 'test'+\"+s_v($ix)+\" )\", \"fileName&n=1\");\r\n", script.modify("_setValue ( elements['username'] , 'test'+$ix )"));
    }

    public void testSeparateVariables(){
        assertEquals("_click(\"+s_v($ix)+\")", script.separateVariables("_click($ix)"));
        assertEquals("aaa \"+s_v($ix)+\" bbb", script.separateVariables("aaa $ix bbb"));
        assertEquals("aaa + \"+s_v($ix)+\" + bbb", script.separateVariables("aaa + $ix + bbb"));
        assertEquals("aaa + \"+s_v($i.x)+\" + bbb", script.separateVariables("aaa + $i.x + bbb"));
        assertEquals("aaa + \"+s_v($i.fn())+\" + bbb", script.separateVariables("aaa + $i.fn() + bbb"));
        assertEquals("aaa + \"+s_v($i[1])+\" + bbb", script.separateVariables("aaa + $i[1] + bbb"));
        assertEquals("aaa + \"+s_v($i[1].a())+\" + bbb", script.separateVariables("aaa + $i[1].a() + bbb"));
        assertEquals("aaa + \"+s_v($i[1][\"COL\"])+\" + bbb", script.separateVariables("aaa + $i[1][\"COL\"] + bbb"));
        assertEquals("aaa + \"+s_v($i[1]['COL'])+\" + bbb", script.separateVariables("aaa + $i[1]['COL'] + bbb"));
        assertEquals("_click(_img(\"+s_v($i[1]['COL'])+\")", script.separateVariables("_click(_img($i[1]['COL'])"));
        assertEquals("_click(\"+s_v($ar[$ix])+\")", script.separateVariables("_click($ar[$ix])"));
        assertEquals("_click(\"+s_v($ar[$i[1]['COL']])+\")", script.separateVariables("_click($ar[$i[1]['COL']])"));
        assertEquals("_click(\"+s_v($ar[$i[1]['C(OL']])+\")", script.separateVariables("_click($ar[$i[1]['C(OL']])"));
        assertEquals("_click(\"+s_v($ar[$i[1]['C)OL']])+\")", script.separateVariables("_click($ar[$i[1]['C)OL']])"));
        assertEquals("_click(\"+s_v($ar[$i[1]['C\\'OL']])+\")", script.separateVariables("_click($ar[$i[1]['C\\'OL']])"));
        assertEquals("_click(\"+s_v($ar[$i[1]['C\\\"OL']])+\")", script.separateVariables("_click($ar[$i[1]['C\\\"OL']])"));
        assertEquals("_click(\"+s_v($ar.get(\"a\", \"b\"))+\")", script.separateVariables("_click($ar.get(\"a\", \"b\"))"));
        assertEquals("_click(\"+s_v($ar.get($i, $j))+\")", script.separateVariables("_click($ar.get($i, $j))"));
    }

    public void testEscape(){
    	assertEquals("\\\\", "\\".replaceAll("\\\\", "\\\\\\\\"));
        assertEquals("aaa \\\" bbb", Utils.escapeDoubleQuotesAndBackSlashes("aaa \" bbb"));
        assertEquals("aaa \\\\\\\" bbb", Utils.escapeDoubleQuotesAndBackSlashes("aaa \\\" bbb"));
    }

    public void testForUnderstanding(){
        assertFalse(Character.isJavaIdentifierPart('.'));
        assertFalse(Character.isUnicodeIdentifierPart('.'));
    }

    public void testModifyFunctionNames(){
        assertEquals("_sahi._setValue ( _sahi._textbox('username') , 'test'+$ix )", SahiScript.modifyFunctionNames("_setValue ( _textbox('username') , 'test'+$ix )"));
        assertEquals("_sahi._setValue(_sahi._textbox('username') , 'test'+$ix )", SahiScript.modifyFunctionNames("_setValue(_textbox('username') , 'test'+$ix )"));
        assertEquals("_sahi._click(_sahi._image(\"Link Quote Application \" + _sahi._getCellText(_sahi._accessor(\"top.content.creditFrameContent.document.getElementById('tblRecentlyAccessedQuotes').rows[3].cells[1]\"))));", SahiScript.modifyFunctionNames("_click(_image(\"Link Quote Application \" + _getCellText(_accessor(\"top.content.creditFrameContent.document.getElementById('tblRecentlyAccessedQuotes').rows[3].cells[1]\"))));"));
    }

    public void testStripSahiFromFunctionNames(){
        assertEquals("_setValue ( _textbox('username') , 'test'+$ix )", SahiScript.stripSahiFromFunctionNames( "_sahi._setValue ( _sahi._textbox('username') , 'test'+$ix )"  ));
        assertEquals("_setValue(_textbox('username') , 'test'+$ix )", SahiScript.stripSahiFromFunctionNames( "_sahi._setValue(_sahi._textbox('username') , 'test'+$ix )"));
    }

    private class MockFileScript extends FileScript{
		public MockFileScript(String fileName) {
			super(fileName);
		}

		protected void loadScript(String fileName) {}
	}
}

