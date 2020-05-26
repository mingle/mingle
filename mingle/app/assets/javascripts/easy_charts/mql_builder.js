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
var MQLBuilder;
(function() {
  var AGGREGATE_TEMPLATE = {
    'sum': 'SUM({aggregateProperty})',
    'avg': 'AVG({aggregateProperty})',
    'count': 'COUNT(*)'
  }, MULTIVALUED_CONDITION_TEMPLATE = {
    eq: '{property} {context}IN ({value})',
    ne: 'NOT ({property} {context}IN ({value}))'
  }, DEFAULTS = {
    aggregate: 'aggregate',
    property: 'property',
    condition: 'condition'
  }, RESERVED_KEYWORDS = { '(current user)': 'CURRENT USER', '(today)' : 'TODAY', 'this card': 'THIS CARD'};

  function isSpecialValue(val, isForCardProperty) {
    return !!(val === 'null' || ( isForCardProperty && val.startsWith('(') ) || RESERVED_KEYWORDS[val.toLowerCase()]);
  }

  function getSpecialValue(val) {
    return RESERVED_KEYWORDS[val.toLowerCase()] || val;
  }

  function smartQuote(val) {
    return !val || isSpecialValue(val, true) || +val ? getSpecialValue(val) : '"{val}"'.supplant({val: val});
  }

  function buildConditionClause(property, operator, values, condition) {
    values = values || [];
    values = Array.isArray(values) ? values : new Array(values);
    if (values.length < 1) return '';

    var isMultiValued = values.length > 1, context = '';
    if (condition && condition.isForCardProperty() && values.all(function (value) { return value.match(/^\d+$/); })) {
      context = isMultiValued ? 'NUMBERS ' : 'NUMBER ';
    }
    var templateParams = {
      property: smartQuote(property),
      op: MQLBuilder.OPERATOR_SYMBOL_MAP[operator],
      context: context
    };

    if (isMultiValued && (operator === 'eq' || operator === 'ne')) {
      templateParams.value = values.collect(smartQuote).join(',');
      return MULTIVALUED_CONDITION_TEMPLATE[operator].supplant(templateParams);
    }

    templateParams.value = smartQuote(values.toString());
    return "{property} {op} {context}{value}".supplant(templateParams);
  }

  function buildConditionClauseWithSpecialValues(property, operator, values, condition) {
    var specialValues = [], normalValues = [], connector = operator === 'eq' ? ' OR ' : ' AND ',
        isForCardProperty = condition.isForCardProperty();
    values = Array.isArray(values) ? values : new Array(values);
    values.each(function(value) {
      isSpecialValue(value, isForCardProperty) ? specialValues.push(value) : normalValues.push(value);
    });

    var conditions = specialValues.collect(function(plv) { return buildConditionClause(property, operator, plv, condition); });
    normalValues.length > 0  && conditions.push(buildConditionClause(property, operator, normalValues, condition));
    var conditionsClause = conditions.join(connector);

    return specialValues.length > 1 || (specialValues.length > 0  &&  normalValues.length > 0) ? '(' + conditionsClause + ')' : conditionsClause;
  }

  function validCondition(condition) {
    return !!condition;
  }

  MQLBuilder = function (options) {
    var property = options.property, aggregateType = options.aggregateType, aggregateProp = options.aggregateProp || '',
        cardTypes = options.cardTypes, additionalConditions = options.additionalConditions || [],
        tags = options.tags || [], project = options.project;

    function buildTagsClause() {
      return tags.collect(function (tag) {
        return "TAGGED WITH \"{tag}\"".supplant({tag: tag});
      }).join(' AND ');
    }

    this.buildConditionsClause = function () {
      var cardTypesClause = buildConditionClause('Type', 'eq', cardTypes),
          additionalConditionsClause = additionalConditions.collect(MQLBuilder.mqlForFilter).filter(validCondition).join(' AND '),
          tagsClause = buildTagsClause();

      var conditionsClause = cardTypesClause;
      additionalConditionsClause && ( conditionsClause += conditionsClause ? ' AND ' + additionalConditionsClause : additionalConditionsClause );
      tagsClause && (conditionsClause += conditionsClause ? ' AND ' + tagsClause : tagsClause );

      return conditionsClause;
    };

    this.buildAggregate = function () {
      return aggregateType ? AGGREGATE_TEMPLATE[aggregateType.toLowerCase()].supplant({
        aggregateProperty: smartQuote(aggregateProp)
      }) : '';
    };

    this.build = function () {
      return "SELECT {property}, {aggregate} WHERE {conditions}".supplant({
        property: smartQuote(property || DEFAULTS.property),
        aggregate: this.buildAggregate() || DEFAULTS.aggregate,
        conditions: this.buildConditionsClause() || DEFAULTS.condition
      });
    };

    this.buildBurnDownMql = function () {
      return "SELECT {aggregate}".supplant({
          aggregate: this.buildAggregate() || DEFAULTS.aggregate
        });
    };
  };
  MQLBuilder.mqlForFilter = function (condition) {
    if (!condition.isValid()) return '';

    return buildConditionClauseWithSpecialValues(
        condition.property.value(),
        condition.operator.value(),
        condition.value.value(),
        condition);
  };

  MQLBuilder.OPERATOR_SYMBOL_MAP = {
    eq: '=',
    ne: '!=',
    gt: '>',
    lt: '<'
  };
})();
