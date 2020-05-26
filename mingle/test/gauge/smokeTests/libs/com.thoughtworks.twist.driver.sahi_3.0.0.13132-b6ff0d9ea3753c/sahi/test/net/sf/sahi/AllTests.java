package net.sf.sahi;

import junit.framework.Test;
import junit.framework.TestSuite;

import net.sf.sahi.command.CommandExecuterTest;
import net.sf.sahi.playback.FileScriptTest;
import net.sf.sahi.playback.SahiScriptHTMLAdapterTest;
import net.sf.sahi.playback.SahiScriptTest;
import net.sf.sahi.playback.ScriptHandlerTest;
import net.sf.sahi.playback.URLScriptTest;
import net.sf.sahi.response.HttpFileResponseTest;
import net.sf.sahi.ssl.SSLHelperTest;
import net.sf.sahi.util.URLParserTest;
import net.sf.sahi.util.UtilsTest;
import net.sf.sahi.request.MultiPartSubRequestTest;

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
public class AllTests extends TestSuite {
    public AllTests(String name) {
        super(name);
    }

    public static Test suite() {
        TestSuite suite = new TestSuite();
        suite.addTestSuite(FileScriptTest.class);
        suite.addTestSuite(SahiScriptTest.class);
        suite.addTestSuite(ScriptHandlerTest.class);
        suite.addTestSuite(URLScriptTest.class);
        suite.addTestSuite(HttpFileResponseTest.class);
        suite.addTestSuite(SahiScriptHTMLAdapterTest.class);
        suite.addTestSuite(UtilsTest.class);
        suite.addTestSuite(URLParserTest.class);
        suite.addTestSuite(CommandExecuterTest.class);
        suite.addTestSuite(SSLHelperTest.class);
        suite.addTestSuite(MultiPartSubRequestTest.class);
        return suite;
    }

    public static void main(String[] args) {
        junit.textui.TestRunner.run(suite());
    }
}
