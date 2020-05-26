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

package com.thoughtworks.mingle.rack;

/** @author marques */
public class Benchmark {
    private String label;

    private long timeInitial;
    private long timeFinal;

    private long heapInitial;
    private long heapFinal;

    public Benchmark start() {
        timeInitial = System.currentTimeMillis();
        heapInitial = currentHeapSize();

        return this;
    }

    public Benchmark finish() {
        timeFinal = System.currentTimeMillis();
        heapFinal = currentHeapSize();

        return this;
    }

    public static long currentHeapSize() {
        return Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
    }

    public Benchmark(String label) {
        this.label = label;
    }

    public long duration() {
        return timeFinal - timeInitial;
    }

    public long heapUsageInBytes() {
        return heapFinal - heapInitial;
    }

    public double heapUsage() {
        return heapUsageInBytes() / (1024 * 1024.0);
    }

    public String toString() {
        return "duration: " + duration() + " msecs, heap usage: " + heapUsage() + " MB, service: " + label;
    }

}
