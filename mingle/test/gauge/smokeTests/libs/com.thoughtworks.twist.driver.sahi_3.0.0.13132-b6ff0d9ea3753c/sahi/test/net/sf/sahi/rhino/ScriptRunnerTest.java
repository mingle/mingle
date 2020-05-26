package net.sf.sahi.rhino;

import junit.framework.TestCase;
import net.sf.sahi.config.Configuration;
import net.sf.sahi.session.Status;

import org.mozilla.javascript.Context;
import org.mozilla.javascript.JavaScriptException;
import org.mozilla.javascript.RhinoException;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;

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
public class ScriptRunnerTest extends TestCase {
	private static final long serialVersionUID = 2339574815897200140L;

	static {
		Configuration.init();
	}

	public void testGetPopupNameFromStep(){
		ScriptRunner scriptRunner = new RhinoScriptRunner("");
		assertEquals("abca", scriptRunner.getPopupNameFromStep("_sahi._popup('abca')._click()"));
		assertEquals("abca", scriptRunner.getPopupNameFromStep("_sahi._popup( 'abca')._click()"));
		assertEquals("abca", scriptRunner.getPopupNameFromStep("_sahi._popup('abca' )._click()"));
		assertEquals("abca", scriptRunner.getPopupNameFromStep("_sahi._popup ('abca')._click()"));
	}

	public void testGetDomainFromStep(){
		ScriptRunner scriptRunner = new RhinoScriptRunner("");
		assertEquals("a.example.com", scriptRunner.getDomainFromStep("_sahi._domain('a.example.com')._click()"));
		assertEquals("x.example.co.in", scriptRunner.getDomainFromStep("_sahi._domain( 'x.example.co.in')._click()"));
		assertEquals("a.example.com", scriptRunner.getDomainFromStep("_sahi._domain('a.example.com' )._click()"));
		assertEquals("a.example.com", scriptRunner.getDomainFromStep("_sahi._domain ('a.example.com')._click()"));
	}	
	public String evaluate(String code){
		String lib = Configuration.getRhinoLibJS();
		// Creates and enters a Context. The Context stores information
		// about the execution environment of a script.
		Context cx = Context.enter();
		try {
		    // Initialize the standard objects (Object, Function, etc.)
		    // This must be done before scripts can be executed. Returns
		    // a scope object that we use in later calls.
		    Scriptable scope = cx.initStandardObjects();

			Object wrappedOut = Context.javaToJS(new RhinoScriptRunner(""), scope);
			ScriptableObject.putProperty(scope, "ScriptRunner", wrappedOut);		    
		    
		    // Now evaluate the string we've colected.
		    cx.evaluateString(scope, lib, "<cmd>", 1, null);
		    Object result = cx.evaluateString(scope, code + ".toString()", "<cmd>", 1, null);

		    // Convert the result to a string and print it.
		    return (Context.toString(result.toString()));

		} catch (JavaScriptException e1){
			System.out.println(e1.getMessage());
		} catch (RhinoException e){
			e.printStackTrace();
		} finally {
		    // Exit from the context.
		    Context.exit();
		}
		return "";
	}
	
	public void testStubs(){
	    check("_sahi._cell('AA')");		
	    check("document.forms[0]");		
	    check("_sahi._cell('AA').parentNode.parentNode");		
	    check("_sahi._link('abcd').getElementsByTagName('DIV')[0]");		
	    check("_sahi._link('abcd').getElementsByTagName('DIV')[25]");		
	    check("_sahi._link('abcd').getElementsByTagName('DIV')[99]");		
	    check("_sahi._cell('AA').parentNode.childNodes[22].previousSibling");		
	    check("_sahi._cell('AA').document.forms[0].elements[11].value");		
	    check("_sahi._checkbox(0, _sahi._near(_sahi._spandiv(\"To: narayan.raman\")))");
	    check("_sahi._textbox(0).value.substring(_sahi._textbox(0).value.indexOf('aa'), 12)");
	    check("_sahi._link(/hi/)");
	    check("_sahi._table('t1').rows[0].cells[1]");
	}

	private void check(String s) {
		System.out.println(evaluate(s));
		assertEquals(s.replace('\'', '"'), evaluate(s));
	}
	
	public void testAreSameShouldReturnFalseIfStringIsBlank(){
		ScriptRunner scriptRunner = new RhinoScriptRunner("");
		assertFalse(scriptRunner.areSame("", "/.*/")); // blank should always return false
	}

	public void testAreSame(){
		ScriptRunner scriptRunner = new RhinoScriptRunner("");
//		assertTrue(scriptRunner.areSame("abcd", "/bc/"));
		assertTrue(scriptRunner.areSame("abcd", "/.*/"));
		assertTrue(scriptRunner.areSame("abcd", "abcd"));
		assertTrue(scriptRunner.areSame("1234", "/[\\d]*/"));
		assertTrue(scriptRunner.areSame("/abcd1234/", "/[/]abcd[\\d]*[/]/"));
		assertTrue(scriptRunner.areSame("ABCd", "/abcd/i"));
		assertTrue(scriptRunner.areSame("ABCd", "/bc/i"));
		assertTrue(scriptRunner.areSame("abcd", "/bc/"));
		assertFalse(scriptRunner.areSame("aBCd", "/bc/"));
		assertFalse(scriptRunner.areSame("abcd1234", "abcd"));
	}
	
	public void testSahiException(){
		evaluate("throw new SahiException('Step took too long')");
	}
	
	public void testFailureIncrementsErrorCount() throws Exception {
		ScriptRunner scriptRunner = new RhinoScriptRunner("");
		final int errorCount = scriptRunner.errorCount();
		scriptRunner.setStatus(Status.FAILURE);
		assertEquals(errorCount + 1, scriptRunner.errorCount());
	}	
	
	public void testErrorDoesNotIncrementErrorCount() throws Exception {
		ScriptRunner scriptRunner = new RhinoScriptRunner("");
		final int errorCount = scriptRunner.errorCount();
		scriptRunner.setStatus(Status.ERROR);
		assertEquals(errorCount, scriptRunner.errorCount());
	}
	
	public void testSetHasErrorIncrementsErrorCount() throws Exception {
		RhinoScriptRunner scriptRunner = new RhinoScriptRunner("");
		final int errorCount = scriptRunner.errorCount();
		scriptRunner.setHasError();
		assertEquals(errorCount + 1, scriptRunner.errorCount());
	}
}
