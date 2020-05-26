package net.sf.sahi.stream.filter;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import junit.framework.TestCase;
import net.sf.sahi.stream.filter.StreamFilter;

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
public abstract class AbstractFilterTestCase extends TestCase {
	private static final long serialVersionUID = -7765749910538404904L;

	protected String getFiltered(String[] strings, StreamFilter modifierFilter) throws IOException {
		return getFiltered(strings, modifierFilter, "iso-8859-1");
	}

	protected String getFiltered(String[] strings, StreamFilter modifierFilter, String charset) throws IOException {
		ByteArrayOutputStream baro = new ByteArrayOutputStream();
		for (int i=0; i<strings.length; i++){
			byte[] input = strings[i].getBytes();
			byte[] r1 = modifierFilter.modify(input);
			baro.write(r1);
		}
		byte[] remaining = modifierFilter.getRemaining();
		if (remaining != null) baro.write(remaining);
		byte[] outputBytes = baro.toByteArray();
		String output = new String(outputBytes);
		return output;
	}
}
