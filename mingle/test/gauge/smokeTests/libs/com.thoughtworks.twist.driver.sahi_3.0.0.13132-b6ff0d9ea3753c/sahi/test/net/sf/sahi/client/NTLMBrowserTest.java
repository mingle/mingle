package net.sf.sahi.client;

import junit.framework.TestCase;
import net.sf.sahi.config.Configuration;

public class NTLMBrowserTest extends TestCase {
	private static final long serialVersionUID = -4296085986550978115L;
	private Browser browser;
	private String sahiBasePath = ".";
	private String userDataDirectory = "./userdata/";
	private String baseURL = "http://sahi.co.in";
	
	
	public void testNTLMBrowser(){
		browser.navigateTo(baseURL + "/demo/formTest.htm");
		browser.textbox("t1").setValue("aaa");
		
		
		browser.waitFor(10000); 
		browser.restartPlayback();
		
		browser.link("Back").click();
		browser.link("Table Test").click();		
		assertEquals("Cell with id", browser.cell("CellWithId").getText());		
		
	}
	
	public void toggleIEProxy(boolean enable){
		try {
			Runtime.getRuntime().exec(new String[]{sahiBasePath + "\\tools\\toggle_IE_proxy.exe", (enable ? "enable" : "disable")});
			Thread.sleep(1000);
		} catch (Exception e) {
			e.printStackTrace();
		}		
	}		
	
	@Override
	protected void setUp() throws Exception {
		Configuration.initJava(sahiBasePath, userDataDirectory);
		
		toggleIEProxy(true);
		
		browser = new Browser("ie");		
		browser.open();	
	}
	
	@Override
	protected void tearDown() throws Exception {
		browser.close();
		toggleIEProxy(false);
	}
	

}
