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

package org.ccil.cowan.tagsoup.jaxp;

import java.io.*;

import javax.xml.parsers.*;
import org.w3c.dom.Document;

/**
 * Trivial non-robust test class, to show that TagSoup can be accessed using
 * JAXP interface.
 */
public class JAXPTest
{
    public static void main(String[] args)
        throws Exception
    {
        new JAXPTest().test(args);
    }

    private void test(String[] args)
        throws Exception
    {
        if (args.length != 1) {
            System.err.println("Usage: java "+getClass()+" [input-file]");
            System.exit(1);
        }
        File f = new File(args[0]);
        //System.setProperty("javax.xml.parsers.SAXParserFactory", SAXFactoryImpl.class.toString());
        System.setProperty("javax.xml.parsers.SAXParserFactory", "org.ccil.cowan.tagsoup.jaxp.SAXFactoryImpl");

        SAXParserFactory spf = SAXParserFactory.newInstance();
        System.out.println("Ok, SAX factory JAXP creates is: "+spf);
        System.out.println("Let's parse...");
        spf.newSAXParser().parse(f, new org.xml.sax.helpers.DefaultHandler());
        System.out.println("Done. And then DOM build:");

        Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(f);

        System.out.println("Succesfully built DOM tree from '"+f+"', -> "+doc);
    }
}
