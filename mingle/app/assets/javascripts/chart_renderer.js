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
var C3Renderer = {
  render: function(chartOptions, bindTo) {
    var titleText = chartOptions.title && chartOptions.title.text;
    delete chartOptions.title;
    if ( c3.version !== "0.4.11" ) {
      var message = 'Patch getHorizontalAxisHeight and dyForXAxisLabel again...';
      alert(message);
      throw new Error(message);
    }
    if (($j.isEmptyObject(chartOptions.data) || chartOptions.data.columns.empty()) && !chartOptions.displayWithoutData) {
      $j(bindTo).html("We could not find any data for this chart.");
      return false;
    }

    function hideToolTip() {
      if ($j('.c3-tooltip-container').length > 0) {
        $j('.c3-tooltip-container').hide();
      }
    }

    function addTitle() {
      if (!titleText) return;
      $j(bindTo).find('div.title').remove();
      var titleHtml = $j('<div></div>', {class: 'title', text: titleText.truncate(75), title: titleText});
      $j(bindTo).prepend(titleHtml);
    }

    $j(window).on("scroll", function () {
      hideToolTip();
    });
    $j("*").on("scroll", function () {
      hideToolTip();
    });

    function toolTipPosition() {
      return {left: d3.event.clientX, top: d3.event.clientY + 20};
    }

    function removeAnimatedFromLightBox() {
      if ($j('.lightbox').length > 0 && window.navigator.userAgent.toLowerCase().indexOf('firefox') > -1)
        $j('.lightbox').removeClass('animated');
    }

    function haveHiddenSeries() {
      return !$j.isEmptyObject(chartOptions.data.colors) && Object.values(chartOptions.data.colors).include('transparent');
    }

    function isHiddenSeries(seriesName) {
      return chartOptions.data.colors[seriesName] === 'transparent';
    }

    function hideTooltipForHiddenSeries() {
      if (!haveHiddenSeries()) return;

      var tooltipContentGenerator = chartOptions.tooltip.contents;
      chartOptions.tooltip.contents = function(d) {
        if (!isHiddenSeries(d[0].name)) return tooltipContentGenerator.apply(this, arguments);
      };
    }

    function disableInteractiveFiltersForHiddenSeries() {
      if (!haveHiddenSeries()) return;

      var onClickHandler = chartOptions.data.onclick;
      chartOptions.data.onclick = function(d) {
        if (!isHiddenSeries(d.id)) return onClickHandler.apply(this, arguments);
      };
    }
    chartOptions.bindto = bindTo;
    chartOptions.tooltip = chartOptions.tooltip || {};
    chartOptions.tooltip.position = toolTipPosition;
    hideTooltipForHiddenSeries();
    disableInteractiveFiltersForHiddenSeries();
    var chart = c3.generate(chartOptions);
    removeAnimatedFromLightBox();
    addTitle();
    return chart;
  }
};

function PieChartRenderer(data, bindTo) {
  var self = this;
  this.chartOptions = data;
  this.sectorData = data.region_data;
  this.sectorMql = data.region_mql;
  this.bindTo = bindTo;
  this.labelType = data.label_type;
  this.toolTipContent = (function (sectorData, labelType) {
    var _sectorData = sectorData;
    var _labelType = labelType;
    return function (d, defaultTitleFormat, defaultValueFormat, color) {
      var sectorName = d[0].name;
      var sectorInfoSuffix = _labelType === 'percentage' ? '%' : '';
      var sectorInfoValue = _labelType === 'percentage' ? (d[0].ratio * 100).toFixed(1) : d[0].value;
      var sectorInfoText = (sectorName.truncate(50) + ' : ' + sectorInfoValue + sectorInfoSuffix);
      var cards = _sectorData[sectorName].cards;
      var count = _sectorData[sectorName].count;

      var cardsInfoText = 'Showing ' + cards.length + ' of ' + count + ' cards';
      var cardsInfo = count ? [cardsInfoText] : [];


      var tableContent = {
        headers: [sectorInfoText],
        footers: cardsInfo,
        body: cards
      };
      return createToolTip(tableContent).get(0).outerHTML;
    };
  })(this.sectorData, this.labelType);

  this.onSectorClick = (function (sectorMql) {
    return function (d, element) {
      var _conditions = sectorMql['conditions'][d.name];
      var _projectIdentifier = sectorMql['project_identifier'];
      if (_conditions && _projectIdentifier) {
        window.open(AbsoluteUrlHelper.sectorUrl(_projectIdentifier, _conditions));
      }
      MingleUI.EasyCharts.ActionTracker.postClickedEvent('pie-chart');
    };
  })(this.sectorMql);

  this.render = function () {
    if (!$j.isEmptyObject(this.sectorData)) {
      this.chartOptions.tooltip = {
        contents: this.toolTipContent
      };
      this.chartOptions.data["onclick"] = this.onSectorClick;
    }
    this._initializeCustomLabel();
    C3Renderer.render(this.chartOptions, bindTo);
  };

  this._initializeCustomLabel = function () {
    if (this.labelType && this.labelType.toLowerCase() === 'whole-number') {
      this.chartOptions.pie = {
        label: {
          format: function (value, ratio, id) {
            return value;
          }
        }
      };
    }
  };
}

function StackedBarChartRenderer(data, bindTo) {
  this.chartOptions = data;
  var xAxisLabels  = this.chartOptions.axis.x.categories, chart, afterInit;
  var stackCount = getCount(data.data.columns, xAxisLabels);
  this.bindTo = bindTo;
  this.stackData = data.region_data;
  this.stackMql = data.region_mql;
  this.chartOptions.axis.x.tick.format = function(d){
    return this.chartOptions.axis.x.categories[d].truncate(30);
  }.bind(this);

  this.toolTipContent = (function(this_chart) {
    var _stackData = this_chart.stackData;
    return function(d, ratio, id) {
      var stackName = xAxisLabels[d[0].index];
      var seriesName = d[0].id;
      var stackDatum = _stackData[stackName] && _stackData[stackName][seriesName];
      var cards = stackDatum ? stackDatum.cards : [];
      var count = stackDatum ? stackDatum.count : 0;
      var stackInfoText = (seriesName.truncate(50) + ' : ' + (d[0].value) + ' of ' + stackCount[stackName]);
      var cardsInfoText = 'Showing ' + cards.length + ' of ' + count + ' cards';
      var cardsInfo  =  count ? [cardsInfoText] : [];

      var tableContent = {
        headers:[stackInfoText],
        footers:cardsInfo,
        body:cards
      };
      return createToolTip(tableContent).get(0).outerHTML;
    };
  })(this);

  this.chartOptions.data.onclick = function (d, element) {
    var stackName = xAxisLabels[d.index];
    var seriesName = d.id;
    var _conditions = this.stackMql['conditions'][stackName][seriesName];
    var _projectIdentifier = this.stackMql['project_identifier'][seriesName];
    if (_conditions && _projectIdentifier) {
      window.open(AbsoluteUrlHelper.sectorUrl(_projectIdentifier, _conditions));
    }
    MingleUI.EasyCharts.ActionTracker.postClickedEvent('stack-bar-chart');
  }.bind(this);

  this.render = function() {
    if (!$j.isEmptyObject(this.stackData)) {
      this.chartOptions.tooltip.contents = this.toolTipContent;
    }
    chart = C3Renderer.render(this.chartOptions, this.bindTo);
    afterInit && afterInit();
  };

  function getCount(dataSet, xLabels) {
    var stackCount = {};
    for (var i = 0; i < xLabels.length; i++) {
      var sum = 0;
      for (var j = 0; j < dataSet.length; j++) {
        sum += dataSet[j][i+1];
      }
      stackCount[xLabels[i]] = sum;
    }
    return stackCount;
  }
}

function RatioBarChartRenderer(data, bindTo) {
  this.chartOptions = data;
  this.barData = data.region_data;
  this.barMql = data.region_mql;
  this.bindTo = bindTo;
  this.chartOptions.axis.y.tick = {
    outer: false,
    format: function (d) {
      return d + '%';
    }
  };

  var _xAxis_labels  = this.chartOptions.axis.x.categories;
  this.chartOptions.axis.x.tick.format = function(d){
      return this.chartOptions.axis.x.categories[d].truncate(30);
    }.bind(this);

  this.toolTipContent = (function(this_chart) {
    var _barData = this_chart.barData;
    return function(d, ratio, id) {
      var barName = _xAxis_labels[d[0].index];
      var barInfoSuffix = '%';
      var barDatum = _barData[barName];
      var cards = barDatum ? barDatum.cards : [];
      var count = barDatum ? barDatum.count : 0;
      var barInfoText = (barName.truncate(50) + ' : ' + (d[0].value).toFixed(1) + barInfoSuffix);

      var cardsInfoText = 'Showing ' + cards.length + ' of ' + count + ' cards';
      var cardsInfo  =  count ? [cardsInfoText] : [];

      var tableContent = {
        headers:[barInfoText],
        footers:cardsInfo,
        body:cards
      };
      return createToolTip(tableContent).get(0).outerHTML;
    };
  })(this);

  this.chartOptions.data.onclick = function (d, element) {
    var barName = _xAxis_labels[d.index], conditions = this.barMql['conditions'][barName],
        projectIdentifier = this.barMql['project_identifier'];
    if (conditions && projectIdentifier) {
      window.open(AbsoluteUrlHelper.sectorUrl(projectIdentifier, conditions));
    }
    MingleUI.EasyCharts.ActionTracker.postClickedEvent('ratio-bar-chart');
  }.bind(this);

  this.render = function() {
    if (!$j.isEmptyObject(this.barData)) {
      this.chartOptions.tooltip = {
        contents: this.toolTipContent
      };
    }
    C3Renderer.render(this.chartOptions, this.bindTo);
  };
}

function CumulativeFlowGraphRenderer(data, bindTo) {
  var customDataSymbolOptions = new CustomC3DataSymbols(data).chartOptions();
  data.onrendered = customDataSymbolOptions.onRendered;
  data.legend.item = data.legend.item || {};
  data.legend.item.onclick = customDataSymbolOptions.onLegendClick;
  StackedBarChartRenderer.call(this, data, bindTo);
}

function DailyHistoryChartRenderer(data, bindTo) {
  $j(bindTo).empty();
  var messageContainer = $j('<div></div>', {class: 'chart-progress-message'}),
      projectDateFormat = MingleUI.RUBY_TO_JS_DATE_FORMAT_MAPPING[data.axis.x.tick.format],
  chartContainer = $j('<div></div>', {class: 'chart-content'});
  var customSeriesLabels = data.custom_series_labels || {};
  delete data.custom_series_labels;
  var labelsFormat =  {};
  Object.keys(customSeriesLabels).forEach(function (key) {
    labelsFormat[key] = function (value, seriesName, valueIndex) {
      if(customSeriesLabels[seriesName].constructor  === Object)
        return customSeriesLabels[seriesName].positions.indexOf(valueIndex) < 0  ?  '' : value;
      return customSeriesLabels[seriesName];
    };
  });
  data.data.labels = data.data.labels || {};
  data.axis.x.tick.culling = data.axis.x.tick.culling || false;
  data.data.labels.format = labelsFormat;
  $j(bindTo).append(messageContainer);
  $j(bindTo).append(chartContainer);

  data.displayWithoutData = true;
  data.tooltip = data.tooltip || {};
  data.tooltip.contents = function (datum) {
    var seriesName = datum[0].id;
    if (data.series_without_tooltip && data.series_without_tooltip.indexOf(seriesName) >= 0) return '';
    var yValue = datum[0].value;
    var xValue = datum[0].x.format(projectDateFormat);
    var text = "{seriesName}: {x}, {y}".supplant({seriesName: seriesName, y: yValue, x: xValue});
    return createToolTip({headers: [text], body: [], footers: []}).get(0).outerHTML;
  };

  DataSeriesChartRenderer.call(this, data, bindTo + ' .chart-content');

  this.getCustomizations = function () {
    var customizations = new CustomC3DataSymbols(data).chartOptions(), existingRenderedCallback = customizations.onRendered;
    customizations.onRendered = function () {
      var $$ = this;
      existingRenderedCallback.call($$);
      if (data.grid.y.lines)
        $$.ygridLines.selectAll('line').style('stroke', data.grid.y.lines[0].color);
    };
    return customizations;
  };
  var messageText = data.message || '';
  messageContainer.text(messageText);
}

function CustomC3DataSymbols(chartOptions) {
  function updateDataPointSymbolStyle(target, style) {
    var $$ = this,
        shapeClass = 'c3-' + style.toLowerCase(),
        shapesClasses = $$.classShapes(target) + ' ' + $$.generateClass(shapeClass + 's', target.id),
        targetClassContainer = $$.main.select('.' + $$.CLASS.chartLines).select($$.selectorTarget(target.id)),
        shapesContainer = targetClassContainer.selectAll('g.' + shapeClass + 's');

    $$.updateCircleY();
    if (style.toLowerCase() === 'circle') {
      shapesContainer.selectAll(style).style('opacity', 1);
    } else {
      shapesContainer.remove();
      var dataPoints = targetClassContainer.append('g')
          .classed(shapesClasses, true)
          .selectAll('.' + shapeClass)
          .data(target.values);
      dataPoints.enter().append("path")
          .classed(shapeClass, true)
          .attr("d", d3.svg.symbol().type(style).size(15))
          .attr('transform', function (d) {
            return "translate(" + $$.x(d.x) + "," + $$.circleY(d) + ")";
          })
          .style('fill', $$.color)
          .style('stroke', $$.color)
          .style('opacity', 1);
      dataPoints.exit().remove();
    }
  }

  function updateLegend(target, dataPointSymbolStyle, lineStyle, targetType) {
    var $$ = this, legendItemClass = $$.selectorLegend(target.id);

    var legendItemWrapper = $$.legend.select(legendItemClass),
        legendTile = legendItemWrapper.select('.c3-legend-item-tile'),
        legendTileX1 = parseFloat(legendTile.attr('x1')), legendTileX2 = parseFloat(legendTile.attr('x2')),
        x = legendTileX1 + Math.abs(legendTileX2 - legendTileX1) / 2,
        y = legendTile.attr('y1');
    if (targetType.match(/line|area/i)) {
      legendTile.attr('stroke-width', 2);
      if (lineStyle === 'dashed') {
        legendTile.attr('stroke-dasharray', [1, 2]);
      }
    }
    if (dataPointSymbolStyle && legendItemWrapper.selectAll('path').size() === 0) {
      legendItemWrapper.append('path')
          .classed('c3-' + dataPointSymbolStyle, true)
          .attr('d', d3.svg.symbol().type(dataPointSymbolStyle).size(21))
          .attr('transform', "translate(" + x + "," + y + ")")
          .style('fill', $$.color)
          .style('stroke', $$.color)
          .style('opacity', 1);
    }
  }

  function removeTrendInteractivity() {
    var $$ = this;
    chartOptions.data.trends.forEach(function (trendLineLabel) {
      var circlesClass = $$.classCircles({id: trendLineLabel}).split(' ').last();
      $$.main.select('.' + $$.CLASS.chartLines).select($$.selectorTarget(trendLineLabel)).select('.' + circlesClass).remove();
    });

  }


  function seriesType(seriesLabel) {
    return chartOptions.data.types[seriesLabel] || chartOptions.data.type;
  }

  function seriesSymbol(seriesLabel) {
    return chartOptions.point.symbols[seriesLabel];
  }

  function getLegendStyle(regions, targetId) {
    var styleOptions = chartOptions.data.regions.hasOwnProperty(targetId) ? chartOptions.data.regions[targetId][0] : {style: null};
    if(chartOptions.hasOwnProperty('legends_style') && chartOptions.legends_style.hasOwnProperty(targetId))
      styleOptions = chartOptions.legends_style[targetId];
    return styleOptions.style;
  }
  function onRendered() {
    var $$ = this;
    $$.data.targets.each(function (target) {
      var dataPointSymbolStyle = seriesSymbol(target.id),
          lineStyle = getLegendStyle(chartOptions.data.regions, target.id),
          targetType = seriesType(target.id);

      updateLegend.call($$, target, dataPointSymbolStyle, lineStyle, targetType);
      if (!dataPointSymbolStyle) return;
      updateDataPointSymbolStyle.call($$, target, dataPointSymbolStyle);
    });
    removeTrendInteractivity.call($$);
  }

  function onLegendClick(id) {
    var $$ = this;

    ['diamonds', 'squares'].forEach(function (dataPointSymbol) {
      $$.main.selectAll('g.c3-' + dataPointSymbol).style('opacity', 0);
    });

    if ($$.d3.event.altKey) {
      $$.api.hide();
      $$.api.show(id);
    } else {
      $$.api.toggle(id);
      if ($$.isTargetToShow(id)) {
        $$.api.focus(id);
      } else {
        $$.api.revert();
      }
    }
  }

  this.chartOptions = function () {
    return {
      onRendered: onRendered,
      onLegendClick: onLegendClick
    };
  };
}

function DataSeriesChartRenderer(chartOptions, bindTo){
  var xAxisLabels  = chartOptions.axis.x.categories, d3EventMouseMoveEvent, toolTipContentForSamePosition = '',
      seriesRegionData = chartOptions.region_data, seriesRegionMql = chartOptions.region_mql;

  function toolTipContents(d, ratio, id) {
    if(d3EventMouseMoveEvent !== this.d3.event) {
      d3EventMouseMoveEvent = this.d3.event;
      toolTipContentForSamePosition = '';
    }
    var regionName = xAxisLabels[d[0].index], seriesName = d[0].id,
        regionDatum = seriesRegionData[regionName] && seriesRegionData[regionName][seriesName];
    if (!regionDatum)  return '';
    var cards = regionDatum ? regionDatum.cards : [],
        cardsCount = regionDatum ? regionDatum.count : 0,
        regionInfoText =  seriesName.truncate(50) + ' : ' + regionName + ', ' + d[0].value,
        cardsInfoText = 'Showing ' + cards.length + ' of ' + cardsCount + ' cards',
        cardsInfo  =  cardsCount ? [cardsInfoText] : [];

    toolTipContentForSamePosition += createToolTip({
      body: cards,
      footers: cardsInfo,
      headers: [regionInfoText]
    }).get(0).outerHTML;
    return toolTipContentForSamePosition;
  }

  function interactiveFilters(d, element) {
    var regionName = xAxisLabels[d.index], seriesName = d.id,
        conditions = seriesRegionMql['conditions'][regionName][seriesName],
        projectIdentifier = seriesRegionMql['project_identifier'][seriesName];
    if (conditions && projectIdentifier) {
      window.open(AbsoluteUrlHelper.sectorUrl(projectIdentifier, conditions));
    }
    MingleUI.EasyCharts.ActionTracker.postClickedEvent('data-series-chart');
  }

  this.getCustomizations = function () {
    return new CustomC3DataSymbols(chartOptions).chartOptions();
  };

  this.render = function() {
    if(!$j.isEmptyObject(seriesRegionData)) {
      chartOptions.tooltip.contents = toolTipContents;
      chartOptions.data.onclick = interactiveFilters;
    }
    var customizations = this.getCustomizations();
    chartOptions.legend.item = chartOptions.legend.item || {};
    chartOptions.onrendered = customizations.onRendered;
    chartOptions.legend.item.onclick = customizations.onLegendClick;

    C3Renderer.render(chartOptions, bindTo);
  };
}

var ChartRenderer = {
  renderChart: function (chartType, dataUrl, bindTo) {
    var spinner = $j('<img>', {src: '/images/spinner.gif'});
    $j(bindTo).append(spinner);
    var renderers = {
      pieChart: PieChartRenderer,
      stackedBarChart: StackedBarChartRenderer,
      cumulativeFlowGraph: CumulativeFlowGraphRenderer,
      ratioBarChart: RatioBarChartRenderer,
      dataSeriesChart: DataSeriesChartRenderer,
      dailyHistoryChart: DailyHistoryChartRenderer
    };
    $j.ajax({
      url: dataUrl,
      dataType: "json"
    }).done(function (data, status, xhr) {
      new renderers[chartType](data, bindTo).render();
    }).always(function (data, status, xhr) {
      spinner.remove();
    });
  }
};

function createToolTip(content){
  var table = $j('<table></table>');
  var tHead = $j('<thead></thead>');
  var tFoot = $j('<tfoot></tfoot>');
  var tBody = $j('<tbody></tbody>');

  function createRow(htmlContent){
    var row = $j('<tr></tr>');
    htmlContent.forEach(function(html){
      row.append(html);
    });
    return row;
  }

  var headers = content.headers.map(function(header){
    return $j('<th></th>',{text: header, colspan:2 });
  });
  tHead.append(createRow(headers));

  var cards = content.body.map(function (card, _) {
    return ['#'+card.number,card.name.truncate(50)];
  });
  cards.forEach(function(trContent){
    var content = trContent.map(function(tdContent){
      return $j('<td></td>',{text: tdContent });
    });
    tBody.append(createRow(content));
  });

  var footers = content.footers.map(function(footer){
    return $j('<td></td>',{text: footer, colspan:2, class:'notes'});
  });

  tFoot.append(createRow(footers));
  table.append(tHead,tFoot, tBody);
  return table;
}