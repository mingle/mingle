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
/**
This class provides a Schema that has been preinitialized with HTML
elements, attributes, and character entity declarations.  All the declarations
normally provided with HTML 4.01 are given, plus some that are IE-specific
and NS4-specific.  Attribute declarations of type CDATA with no default
value are not included.
*/

package org.ccil.cowan.tagsoup;
public class HTMLSchema extends Schema implements HTMLModels {

	/**
	Returns a newly constructed HTMLSchema object independent of
	any existing ones.
	*/

	public HTMLSchema() {
		// Start of Schema calls
		@@SCHEMA_CALLS@@
		// End of Schema calls
		}


	}
