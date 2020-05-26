package net.sf.sahi.test;

import junit.framework.TestCase;

public class SingleSessionTestRunnerTest extends TestCase {
	private static final long serialVersionUID = 4687325716286230955L;
	private String browserType = "firefox";
	private String base = "http://sahi.co.in/demo/";
	
	public void testSingleBrowserSession() throws Exception {

		SingleSessionTestRunner testRunner = new SingleSessionTestRunner("my_session", browserType, base);
		testRunner.start();
		
		assertEquals("FAILURE", testRunner.executeSingleTest("D:/Work/Sahi/Sahi_OS/userdata/scripts/demo/clicksTest_1.sah"));
//		assertEquals("SUCCESS", testRunner.executeSingleTest("D:/Dev/Sahi/sahi_os/userdata/scripts/demo/clicksTest_2.sah"));
		assertEquals("SUCCESS", testRunner.executeSingleTest("D:/Work/Sahi/Sahi_OS/userdata/scripts/demo/label.sah"));
		
		String suiteStatus = testRunner.stop();
		System.out.println(suiteStatus);
	}
	
	
	public void testSessionSpecificInitJs() throws Exception{
		SingleSessionTestRunner testRunner = new SingleSessionTestRunner("my_session", browserType, base);
		testRunner.start();
		
		assertEquals("SUCCESS", testRunner.executeSingleTest("D:/Work/Sahi/Sahi_OS/userdata/scripts/demo/sahi_demo.sah"));
		
		testRunner.setInitJS("var $value1 = 'success1'");
		assertEquals("SUCCESS", testRunner.executeSingleTest("D:/Work/Sahi/Sahi_OS/userdata/scripts/demo/simple_1.sah"));
		testRunner.setInitJS("var $value1 = 'success2'");
		assertEquals("SUCCESS", testRunner.executeSingleTest("D:/Work/Sahi/Sahi_OS/userdata/scripts/demo/simple_2.sah"));
		
		String suiteStatus = testRunner.stop();
		System.out.println(suiteStatus);
	}
}
