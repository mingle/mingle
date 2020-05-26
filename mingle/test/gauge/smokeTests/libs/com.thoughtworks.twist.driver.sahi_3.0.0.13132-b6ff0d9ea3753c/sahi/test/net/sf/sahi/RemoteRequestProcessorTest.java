package net.sf.sahi;

import net.sf.sahi.config.Configuration;
import junit.framework.TestCase;

public class RemoteRequestProcessorTest extends TestCase {
	private static final long serialVersionUID = 1346774483290088617L;
	static{
		Configuration.init();
	}
	
	public void testGetScheme() throws Exception {
		RemoteRequestProcessor rrp = new RemoteRequestProcessor();
		assertEquals("somethingelse", rrp.getScheme("SomeThingElse"));
		assertEquals("basic", rrp.getScheme("Basic"));
		assertEquals("basic", rrp.getScheme("Basic realm=\"WallyWorld\""));
		assertEquals("basic", rrp.getScheme("Basic   realm=\"WallyWorld\""));
		assertEquals("digest", rrp.getScheme("Digest realm=\"testrealm@host.com\",qop=\"auth,auth-int\",nonce=\"dcd98b7102dd2f0e8b11d0f600bfb0c093\",opaque=\"5ccc069c403ebaf9f0171e9517f40e41\""));
		assertEquals("ntlm", rrp.getScheme("NTLM"));
	}
	
	public void testGetRealm() throws Exception {
		RemoteRequestProcessor rrp = new RemoteRequestProcessor();
		assertEquals(null, rrp.getRealm("Basic"));
		assertEquals("WallyWorld", rrp.getRealm("Basic realm=\"WallyWorld\""));
		assertEquals("WallyWorld", rrp.getRealm("Basic   realm=\"WallyWorld\""));
		assertEquals("WallyWorld", rrp.getRealm("Basic realm=\"WallyWorld\",adasd"));
		assertEquals("WallyWorld", rrp.getRealm("Basic realm=\"WallyWorld\"  ,adasd"));
		assertEquals("\"WallyWorld\"", rrp.getRealm("Basic realm=\"\"WallyWorld\"\"  ,adasd"));
		assertEquals("testrealm@host.com", rrp.getRealm("Digest realm=\"testrealm@host.com\",qop=\"auth,auth-int\",nonce=\"dcd98b7102dd2f0e8b11d0f600bfb0c093\",opaque=\"5ccc069c403ebaf9f0171e9517f40e41\""));
		assertEquals(null, rrp.getRealm("NTLM"));
	}
	
	public void testDownloadableContentType() throws Exception {
		RemoteRequestProcessor rrp = new RemoteRequestProcessor();
		assertTrue(rrp.isDownloadContentType("zip"));
		assertTrue(rrp.isDownloadContentType("abcd/zip"));
		assertTrue(rrp.isDownloadContentType("abcd/zip/xyz"));
		assertTrue(rrp.isDownloadContentType("application/vnd.ms-excel"));
		assertTrue(rrp.isDownloadContentType("application/mspowerpoint"));
		assertFalse(rrp.isDownloadContentType("application/x-dos_ms_excel"));
		assertFalse(rrp.isDownloadContentType("application/x-javascript"));
		assertTrue(rrp.isDownloadContentType("application/octet-stream"));		
	}
}
