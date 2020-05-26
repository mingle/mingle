package net.sf.sahi.util;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
public class UtilsTest extends TestCase {
	private static final long serialVersionUID = 2636931487031933499L;
	public UtilsTest(String name) {
        super(name);
    }

    public void testBlankLinesDoNotCauseProblemsInNumbering() {
        String s = "1\na\n\nbx\ny";
        assertEquals(5, Utils.getTokens(s).size());
        s = "1\na\n\nbx\ny\n";
        assertEquals(5, Utils.getTokens(s).size());
        s = "\n\n\n";
        assertEquals(3, Utils.getTokens(s).size());
        s = "";
        assertEquals(1, Utils.getTokens(s).size());
        s = "\n";
        assertEquals(1, Utils.getTokens(s).size());
    }

    public void testConvertStringToASCII() {
        assertEquals("Elephant", Utils.convertStringToASCII("Éléphant"));
    }

    public void testMakeString() {
        assertEquals("a\\nb", Utils.makeString("a\nb"));
    }

    public void testStripChildSessionId() {
        assertEquals("2371283", Utils.stripChildSessionId("2371283sahix34x"));
        assertEquals("2371283sahixx", Utils.stripChildSessionId("2371283sahixx"));
        assertEquals("2371283sahix", Utils.stripChildSessionId("2371283sahix"));
        assertEquals("1423530803cef04658083dd04ea6eaf6f5c0", Utils.stripChildSessionId("1423530803cef04658083dd04ea6eaf6f5c0sahix5986fee00ab5704bbd083480be104d1035afx"));
    }

    public void xtestConcatPaths() {
        assertEqualPaths("D:/my/sahi/certs/a.txt", Utils.concatPaths("../certs", "a.txt"));
    }

    private void assertEqualPaths(String expected, String actual){
        assertEquals(Utils.makePathOSIndependent(expected), Utils.makePathOSIndependent(actual));
    }

    public void testMakeOSInedpendent() {
        if (Utils.isWindows())
            assertEquals("D:/my/sahi/certs/a.txt", Utils.makePathOSIndependent("D:\\my\\sahi\\certs\\a.txt"));
    }

    public void testSplit(){
        assertEquals("aa", "aa\nbb\r\ncc".replaceAll("\r", "").split("[\n]")[0]);
        assertEquals("bb", "aa\nbb\r\ncc".replaceAll("\r", "").split("[\n]")[1]);
        assertEquals("cc", "aa\nbb\r\ncc".replaceAll("\r", "").split("[\n]")[2]);
    }

    public void testInclude(){
        String inputStr = "_click(_link($linkText));\r\n_include(\"includes/sahi_demo_include.sah\");\r\n//_include(\"http://localhost:9999/_s_/scripts/sahi_demo_include.sah\");";
        String patternStr = "[^\"']*[.]sah";
        Pattern pattern = Pattern.compile(patternStr);
        Matcher matcher = pattern.matcher(inputStr);
        while (matcher.find()) {
            String includeStatement = matcher.group(0);
            System.out.println(includeStatement);
        }
    }

    public void testGetCommandTokensDoubleQuotes(){
    	String s = "sh -c \"ps -ef | grep firefox-bin\"";
    	String[] tokens = Utils.getCommandTokens(s);
    	assertEquals("sh", tokens[0]);
    	assertEquals("-c", tokens[1]);
    	assertEquals("ps -ef | grep firefox-bin", tokens[2]);
    }

    public void testGetCommandTokensSingleQuotes(){
    	String s = "sh -c 'ps -ef | grep firefox-bin'";
    	String[] tokens = Utils.getCommandTokens(s);
    	assertEquals("sh", tokens[0]);
    	assertEquals("-c", tokens[1]);
    	assertEquals("ps -ef | grep firefox-bin", tokens[2]);
    }
    
    public void testGetCommandTokensMixedQuotes(){
    	assertEquals("ps -ef | grep \\'firefox-bin\\'", Utils.getCommandTokens("sh -c 'ps -ef | grep \\'firefox-bin\\''")[2]);
    	assertEquals("ps -ef | grep \"firefox-bin\"", Utils.getCommandTokens("sh -c 'ps -ef | grep \"firefox-bin\"'")[2]);
//    	assertEquals("'ps -ef | grep \\'firefox-bin\\''", Utils.getCommandTokens("sh -c 'ps -ef | grep \\'firefox-bin\\''")[2]);
    }
    
    public void testGetUUIDn(){
    	for (int i=0; i<100; i++){
    		checkGetUUID();
    	}
    }
    
    public void testQuotesAndSpacesBug(){
    	assertEquals("-genkey", Utils.getCommandTokens("\"keytool\" -genkey")[1]);
    }
    
    public void checkGetUUID(){
    	String uuid1 = Utils.getUUID();
    	String uuid2 = Utils.getUUID();
//    	System.out.println(uuid1);
//    	System.out.println(uuid2);
    	assertFalse(uuid1.equals(uuid2));
    }
    
    public void testEncode() throws Exception {
		assertEquals("1+%2B+2", Utils.encode("1 + 2"));
	}
    
    public void testEnv() throws Exception {
    	final String osName = System.getProperty("os.name");
		if ("Windows 7".equals(osName))
			assertEquals("C:\\Program Files\\a\\b", Utils.expandSystemProperties("$ProgramFiles\\a\\b"));
	}

    public void testExecuteWithTimeout() throws Exception {
//    	final String str = Utils.executeCommand("\"C:\\Program Files\\Internet Explorer\\iexplore.exe\"", false, 10000);
//    	System.out.println(">> str: " + str);
    	final String osName = System.getProperty("os.name");
    	if ("Windows 7".equals(osName)) {
	    	final long start = System.currentTimeMillis();
	    	final String str2 = Utils.executeCommand("cmd.exe /c dir", true, 10000);
	    	System.out.println(">> str2: " + str2 + " " + (System.currentTimeMillis() - start));
    	}
    }        
}


