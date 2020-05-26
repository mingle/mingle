// This file is part of TagSoup.
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.  You may also distribute
// and/or modify it under version 3.0 of the Academic Free License.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
// 
// 
package org.ccil.cowan.tagsoup;
import java.io.*;
import org.xml.sax.SAXException;
import org.xml.sax.Locator;

/**
This class implements a table-driven scanner for HTML, allowing for lots of
defects.  It implements the Scanner interface, which accepts a Reader
object to fetch characters from and a ScanHandler object to report lexical
events to.
*/

public class HTMLScanner implements Scanner, Locator {

	// Start of state table
	@@STATE_TABLE@@
	// End of state table

	private String thePublicid;			// Locator state
	private String theSystemid;
	private int theLastLine;
	private int theLastColumn;
	private int theCurrentLine;
	private int theCurrentColumn;

	int theState;					// Current state
	int theNextState;				// Next state
	char[] theOutputBuffer = new char[200];	// Output buffer
	int theSize;					// Current buffer size
	int[] theWinMap = {				// Windows chars map
		0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
		0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
		0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
		0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178};

	// Compensate for bug in PushbackReader that allows
	// pushing back EOF.
	private void unread(PushbackReader r, int c) throws IOException {
		if (c != -1) r.unread(c);
		}

	// Locator implementation

	public int getLineNumber() {
		return theLastLine;
		}
	public int getColumnNumber() {
		return theLastColumn;
		}
	public String getPublicId() {
		return thePublicid;
		}
	public String getSystemId() {
		return theSystemid;
		}


	// Scanner implementation

	/**
	Reset document locator, supplying systemid and publicid.
	@param systemid System id
	@param publicid Public id
	*/

	public void resetDocumentLocator(String publicid, String systemid) {
		thePublicid = publicid;
		theSystemid = systemid;
		theLastLine = theLastColumn = theCurrentLine = theCurrentColumn = 0;
		}

	/**
	Scan HTML source, reporting lexical events.
	@param r0 Reader that provides characters
	@param h ScanHandler that accepts lexical events.
	*/

	public void scan(Reader r0, ScanHandler h) throws IOException, SAXException {
		theState = S_PCDATA;
		int savedState = 0;
		int savedSize = 0;
		PushbackReader r;
		if (r0 instanceof PushbackReader) {
			r = (PushbackReader)r0;
			}
		else if (r0 instanceof BufferedReader) {
			r = new PushbackReader(r0);
			}
		else {
			r = new PushbackReader(new BufferedReader(r0));
			}

		int firstChar = r.read();	// Remove any leading BOM
		if (firstChar != '\uFEFF' && firstChar != -1) r.unread(firstChar);

		while (theState != S_DONE) {
			int ch = r.read();
			if (ch >= 0x80 && ch <= 0x9F) ch = theWinMap[ch-0x80];
			if (ch == '\n') {
				theCurrentLine++;
				theCurrentColumn = 0;
				}
			else {
				theCurrentColumn++;
				}
			if (ch < 0x20 && ch != '\n' && ch != '\r' && ch != '\t' && ch != -1) continue;
			// Search state table
			int action = 0;
			for (int i = 0; i < statetable.length; i += 4) {
				if (theState != statetable[i]) {
					if (action != 0) break;
					continue;
					}
				if (statetable[i+1] == 0) {
					action = statetable[i+2];
					theNextState = statetable[i+3];
					}
				else if (statetable[i+1] == ch) {
					action = statetable[i+2];
					theNextState = statetable[i+3];
					break;
					}
				}
//			System.err.println("In " + debug_statenames[theState] + " got " + nicechar(ch) + " doing " + debug_actionnames[action] + " then " + debug_statenames[theNextState]);
			switch (action) {
			case 0:
				throw new Error(
"HTMLScanner can't cope with " + Integer.toString(ch) + " in state " +
Integer.toString(theState));
        		case A_ADUP:
				h.adup(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_ADUP_SAVE:
				h.adup(theOutputBuffer, 0, theSize);
				theSize = 0;
				save(ch, h);
				break;
        		case A_ADUP_STAGC:
				h.adup(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.stagc(theOutputBuffer, 0, theSize);
				break;
        		case A_ANAME:
				h.aname(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_ANAME_ADUP:
				h.aname(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.adup(theOutputBuffer, 0, theSize);
				break;
        		case A_ANAME_ADUP_STAGC:
				h.aname(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.adup(theOutputBuffer, 0, theSize);
				h.stagc(theOutputBuffer, 0, theSize);
				break;
        		case A_AVAL:
				h.aval(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_AVAL_STAGC:
				h.aval(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.stagc(theOutputBuffer, 0, theSize);
				break;
			case A_CDATA:
				mark();
				// suppress the final "]]" in the buffer
				if (theSize > 1) theSize -= 2;
				h.pcdata(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
			case A_ENTITY:
				mark();
				char ch1 = (char)ch;
//				System.out.println("Got " + ch1 + " in state " + ((theState == S_ENT) ? "S_ENT" : ((theState == S_NCR) ? "S_NCR" : "UNK")));
				if (theState == S_ENT && ch1 == '#') {
					theNextState = S_NCR;
					save(ch, h);
					break;
					}
				else if (theState == S_NCR && (ch1 == 'x' || ch1 == 'X')) {
					theNextState = S_XNCR;
					save(ch, h);
					break;
					}
				else if (theState == S_ENT && Character.isLetterOrDigit(ch1)) {
					save(ch, h);
					break;
					}
				else if (theState == S_NCR && Character.isDigit(ch1)) {
					save(ch, h);
					break;
					}
				else if (theState == S_XNCR && (Character.isDigit(ch1) || "abcdefABCDEF".indexOf(ch1) != -1)) {
					save(ch, h);
					break;
					}

//				System.err.println("%%" + new String(theOutputBuffer, 0, theSize));
				h.entity(theOutputBuffer, savedSize + 1, theSize - savedSize - 1);
				int ent = h.getEntity();
//				System.err.println("%% value = " + ent);
				if (ent != 0) {
					theSize = savedSize;
					if (ent >= 0x80 && ent <= 0x9F) {
						ent = theWinMap[ent-0x80];
						}
					if (ent < 0x20) ent = 0x20;
					if (ent < 0x10000) {
						save(ent, h);
						}
					else {
						ent -= 0x10000;
						save((ent>>10) + 0xD800, h);
						save((ent&0x3FF) + 0xDC00, h);
						}
					if (ch != ';') {
						unread(r, ch);
						theCurrentColumn--;
						}
					}
				else {
					unread(r, ch);
					theCurrentColumn--;
					}
				theNextState = savedState;
				break;
        		case A_ETAG:
				h.etag(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_DECL:
				h.decl(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_GI:
				h.gi(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
			case A_GI_STAGC:
				h.gi(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.stagc(theOutputBuffer, 0, theSize);
				break;
        		case A_LF:
				save('\n', h);
				break;
        		case A_LT:
				mark();
				save('<', h);
				break;
			case A_LT_PCDATA:
				mark();
				save('<', h);
				h.pcdata(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_PCDATA:
				mark();
				h.pcdata(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
			case A_CMNT:
				mark();
				h.cmnt(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
			case A_MINUS3:
				save('-', h);
				save(' ', h);
				break;
			case A_MINUS2:
				save('-', h);
				save(' ', h);
				// fall through into A_MINUS
			case A_MINUS:
				save('-', h);
				save(ch, h);
				break;
        		case A_PI:
				mark();
				h.pi(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_PITARGET:
				h.pitarget(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
        		case A_PITARGET_PI:
				h.pitarget(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.pi(theOutputBuffer, 0, theSize);
				break;
			case A_PCDATA_SAVE_PUSH:
				h.pcdata(theOutputBuffer, 0, theSize);
				theSize = 0;
				// fall through into A_SAVE_PUSH
        		case A_SAVE_PUSH:
				savedState = theState;
				savedSize = theSize;
				// fall through into A_SAVE
        		case A_SAVE:
				save(ch, h);
				break;
        		case A_SKIP:
				break;
        		case A_SP:
				save(' ', h);
				break;
        		case A_STAGC:
				h.stagc(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
			case A_EMPTYTAG:
				mark();
//				System.err.println("%%% Empty tag seen");
				if (theSize > 0) h.gi(theOutputBuffer, 0, theSize);
				theSize = 0;
				h.stage(theOutputBuffer, 0, theSize);
				break;
			case A_UNGET:
				unread(r, ch);
				theCurrentColumn--;
				break;
        		case A_UNSAVE_PCDATA:
				if (theSize > 0) theSize--;
				h.pcdata(theOutputBuffer, 0, theSize);
				theSize = 0;
				break;
			default:
				throw new Error("Can't process state " + action);
				}
			theState = theNextState;
			}
		h.eof(theOutputBuffer, 0, 0);
		}

	/**
	* Mark the current scan position as a "point of interest" - start of a tag,
	* cdata, processing instruction etc.
	*/

	private void mark() {
		theLastColumn = theCurrentColumn;
		theLastLine = theCurrentLine;
		}

	/**
	A callback for the ScanHandler that allows it to force
	the lexer state to CDATA content (no markup is recognized except
	the end of element.
	*/

	public void startCDATA() { theNextState = S_CDATA; }

	private void save(int ch, ScanHandler h) throws IOException, SAXException {
		if (theSize >= theOutputBuffer.length - 20) {
			if (theState == S_PCDATA || theState == S_CDATA) {
				// Return a buffer-sized chunk of PCDATA
				h.pcdata(theOutputBuffer, 0, theSize);
				theSize = 0;
				}
			else {
				// Grow the buffer size
				char[] newOutputBuffer = new char[theOutputBuffer.length * 2];
                                System.arraycopy(theOutputBuffer, 0, newOutputBuffer, 0, theSize+1);
				theOutputBuffer = newOutputBuffer;
				}
			}
		theOutputBuffer[theSize++] = (char)ch;
		}

	/**
	Test procedure.  Reads HTML from the standard input and writes
	PYX to the standard output.
	*/

	public static void main(String[] argv) throws IOException, SAXException {
		Scanner s = new HTMLScanner();
		Reader r = new InputStreamReader(System.in, "UTF-8");
		Writer w = new OutputStreamWriter(System.out, "UTF-8");
		PYXWriter pw = new PYXWriter(w);
		s.scan(r, pw);
		w.close();
		}


        private static final String nicechar(int in) {
            if (in=='\n') {
                return "\n";
            } else if (in=='\r') {
                return "\r";
            } else if (in < 32) {
                return "0x"+Integer.toHexString(in);
            } else {
                return "'"+((char)in)+"'";
            }
        }

	}
