package in.co.sahi;

import junit.framework.TestCase;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.ExecutionException;
import net.sf.sahi.config.Configuration;

/**
 * 
 * This is a sample class to get started with Sahi Java.<br/> 
 * Have a look at DriverClientTest.java in sample_java_project dir for more detailed use of APIs.<br/>
 * You need sahi/lib/sahi.jar in your classpath.</br>
 * 
 */
public class JavaClientTest extends TestCase {
	private Browser browser;
	private String userDataDirectory;

	/**
	 * This starts the Sahi proxy, toggles the proxy settings on Internet Explorer
	 * and starts a browser instance. This could be part of your setUp method in a JUnit test.
	 * 
	 */
	public void setUp(){
		String sahiBase = "../"; // where Sahi is installed or unzipped
		userDataDirectory = "myuserdata"; 
		Configuration.initJava(sahiBase, userDataDirectory); // Sets up configuration for proxy. Sets Controller to java mode.
		
		browser = new Browser("firefox");	
		browser.open();
	}	
	
	public void testGoogle() throws ExecutionException{
		browser.navigateTo("http://www.google.com");
		browser.textbox("q").setValue("sahi forums");
		browser.submit("Google Search").click();
		browser.waitFor(1000);
		browser.link("Forums - Sahi - Web Automation and Test Tool").click();		
		browser.link("Login").click();
		System.out.println(":: browser.textbox(\"req_username\").exists() = " + browser.textbox("req_username").exists());
	}

	
	public void testSahiDemoSite(){
		browser.navigateTo("http://sahi.co.in/demo/training/");
		browser.textbox("user").setValue("test");
		browser.password("password").setValue("secret");
		browser.submit("Login").click();
		browser.textbox("q").setValue("2");
		browser.textbox("q[1]").setValue("9");
		browser.textbox("q[2]").setValue("4");
		browser.button("Add").click();	
		System.out.println(":: browser.textbox(\"total\").value()=" + browser.textbox("total").value());
	}
	
	/**
	 * This closes the browser instance, stops the proxy and toggles back the IE proxy settings.
	 * This could be part of your JUnit tearDown.
	 */
	
	public void tearDown(){
		browser.close();		
	}
		
}
