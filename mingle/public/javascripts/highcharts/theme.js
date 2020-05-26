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
var defaultFont = 'normal 12px Arial, Helvetica, sans-serif';

Highcharts.theme = {
  colors: ['#26A9E0', '#C4629D', '#F7C23E', '#8DC15B','#626655',  '#9B60A5', '#4A737C', '#BF5847', '#E08F19'],
  chart: {
    
    borderWidth: 0,
    borderRadius: 15,
    plotBackgroundColor: null,
    plotShadow: false,
    plotBorderWidth: 0,
    shadow: false
  },
  title: {
    style: { 
      color: '#111',
      font: "18px Helvetica Neue, Arial",
      fontWeight: 300
    }
  },
  subtitle: {
    style: { 
      color: '#111',
      font: defaultFont.replace('12px', '11px')
    }
  },
  xAxis: {
    gridLineWidth: 0,
    lineColor: '#DDD',
    tickColor: '#DDD',
    labels: {
      style: {
        color: '#333',
        font: defaultFont
      }
    },
    title: {
      style: {
        color: '#AAA',
        font: defaultFont.replace('normal', 'bold')
      }       
    }
  },
  yAxis: {
    alternateGridColor: null,
    minorTickInterval: null,
    gridLineColor: '#DDD',
    lineWidth: 0,
    tickWidth: 0,
    labels: {
      style: {
        color: '#333',
        font: defaultFont
      }
    },
    title: {
      style: {
        color: '#111',
        font: defaultFont
      }       
    }
  },
  legend: {
    itemStyle: {
      color: '#CCC'
    },
    itemHoverStyle: {
      color: '#FFF'
    },
    itemHiddenStyle: {
      color: '#333'
    }
  },
  labels: {
    style: {
      color: '#CCC'
    }
  },
  tooltip: {
    backgroundColor: 'rgba(0, 0, 0, .85)',
    borderWidth: 1,
    borderColor: '#333333',
    borderRadius: 0,
    shadow: true,
    snap: 10,
    style: {
      color: '#FFF',
      font: defaultFont,
      padding: '6px 10px',
      whiteSpace: 'nowrap'
    }
  },
  
  
  plotOptions: {
    line: {
      dataLabels: {
        color: '#CCC'
      },
      marker: {
        lineColor: '#333'
      }
    },
    spline: {
      marker: {
        lineColor: '#333'
      }
    },
    scatter: {
      marker: {
        lineColor: '#333'
      }
    },
    column: {
      shadow: false
    }
  },
  
  toolbar: {
    itemStyle: {
      color: '#CCC'
    }
  },
  
  navigation: {
    buttonOptions: {
      backgroundColor: {
        linearGradient: [0, 0, 0, 20],
        stops: [
          [0.4, '#606060'],
          [0.6, '#333333']
        ]
      },
      borderColor: '#000000',
      symbolStroke: '#C0C0C0',
      hoverSymbolStroke: '#FFFFFF'
    }
  },
  
  exporting: {
    buttons: {
      exportButton: {
        symbolFill: '#55BE3B'
      },
      printButton: {
        symbolFill: '#7797BE'
      }
    }
  },  
  
  // special colors for some of the demo examples
  legendBackgroundColor: 'rgba(48, 48, 48, 0.8)',
  legendBackgroundColorSolid: 'rgb(70, 70, 70)',
  dataLabelsColor: '#444',
  textColor: '#E0E0E0',
  maskColor: 'rgba(255,255,255,0.3)'
};

// Apply the theme
var highchartsOptions = Highcharts.setOptions(Highcharts.theme);
