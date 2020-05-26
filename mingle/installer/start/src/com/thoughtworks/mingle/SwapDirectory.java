/*
*  Copyright 2020 ThoughtWorks, Inc.
*  
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*  
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*  
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/

package com.thoughtworks.mingle;

import java.io.File;

public class SwapDirectory {
    private String swapDir;

    public static SwapDirectory defaultInstance(DataDirectory dataDirectory) {
        return new SwapDirectory(dataDirectory.subdirectoryNamed("tmp").getAbsolutePath());
    }

    public SwapDirectory(String swapDir) {
        this.swapDir = swapDir.trim();
        if (this.swapDir.endsWith(File.separator)) {
            this.swapDir = this.swapDir.substring(0, this.swapDir.length() - 1);
        }
    }

    public boolean isEmpty() {
        return (this.swapDir == null || this.swapDir.equals(""));
    }

    public String toString() {
        return this.swapDir;
    }
}
