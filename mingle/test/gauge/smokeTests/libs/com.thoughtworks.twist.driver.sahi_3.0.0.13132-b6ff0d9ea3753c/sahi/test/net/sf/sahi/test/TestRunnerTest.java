package net.sf.sahi.test;

import java.io.IOException;
import java.util.HashMap;

import net.sf.sahi.test.TestRunner;
import net.sf.sahi.util.Utils;
import net.sf.sahi.ant.Report;
import junit.framework.TestCase;

public class TestRunnerTest extends TestCase {
	private static final long serialVersionUID = 3104595408470646058L;

	protected void setUp() throws Exception {
		super.setUp();
	}
	
	/*
	 * java -cp %SAHI_HOME%\lib\ant-sahi.jar net.sf.sahi.test.TestRunner scripts/demo/sahi_demo.sah 
	 * "C:\Program Files\Mozilla Firefox\firefox.exe" http://sahi.co.in/demo/ logs/playback/aaa 
	 * localhost 9999 3 
	 * firefox.exe "-profile %SAHI_USERDATA_DIR%/browser/ff/profiles/sahi$threadNo -no-remote"
	 * 
	 */
	
	public void testExecute() throws Exception {
		runSingleTest("scripts/demo/link_test.sah");
	}
	
	public void testPreconfiguredBrowsers() throws Exception {
		final String suiteName = "scripts/demo/integration.sah";
		final String browserType = "firefox";
		String base = "http://sahi.co.in/demo/training/";
		String threads = "1";

		String initJS = "$user='test';$pwd='secret';";
		String logDir = "D:/Dev/sahi/sahi_993/userdata/logs/junit/";
		
		
		TestRunner testRunner = 
			new TestRunner(suiteName, browserType, base, threads);
		
		testRunner.addReport(new Report("junit", logDir));
		testRunner.setInitJS(initJS);
		String status = testRunner.execute();
		System.out.println(status);
		assertEquals("SUCCESS", status);
	}

	private void runSingleTest(String suiteName) throws IOException, InterruptedException {
		String browser = "C:\\Program Files\\Mozilla Firefox\\firefox.exe";
		String base = "http://sahi.co.in/demo/";
		String sahiHost = "localhost";
		String port = "9999";
		String threads = "1";
		String browserOption = "-profile D:/sahi/sf/sahi_993/userdata/browser/ff/profiles/sahi$threadNo -no-remote";
		String browserProcessName = "firefox.exe";
		String logDir = "D:/temp/logs/"; // relative paths will be resolved relative to userdata dir.
		
		TestRunner testRunner = new TestRunner(suiteName, browser, base, sahiHost, 
					port, threads, browserOption, browserProcessName);
		testRunner.addReport(new Report("html", logDir));
        String status = testRunner.execute();
        System.out.println(status);
        assertEquals("SUCCESS", status);
	}
	
	public void testEOP() throws IOException, InterruptedException {
		String browserType = "firefox";
		String base = "http://sahi.co.in/demo/training/";
		String sahiHost = "localhost";
		String port = "9999";
		String threads = "1";
		String logDir = "D:/temp/logs/"; // relative paths will be resolved relative to userdata dir.
		String suiteName = "scripts/demo/integration.sah";

		TestRunner testRunner = new TestRunner(suiteName, browserType, base, sahiHost, port, threads);
		HashMap<String, Object> variableHashMap = new HashMap<String, Object>();
		variableHashMap.put("$user", "test");
		variableHashMap.put("$pwd", "secret");
		testRunner.setInitJS(variableHashMap);
		testRunner.addReport(new Report("tm6", logDir));
        String status = testRunner.execute();
        System.out.println(status);
        assertEquals("SUCCESS", status);
        
        
        System.out.println(Utils.readFileAsString("D:/temp/logs/integration.xml"));
	}
}
