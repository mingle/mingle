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
/*jslint indent: 2, white: false */
var DependencyTracker = {};
(function(dt) {
   dt.dataSource = function(retrieve) {
    function convert(cards) {
      var cache = {};
      each(cards, function(card) {
        cache[card.format(dt.card.formatters.ref)] = card;
      });

      function lookup(cardReference) {
        if (typeof cardReference == 'string') {
          return cache[cardReference];
        } else {
          return find(cards, function(card) {
            return card.equals(cardReference);
          });
        }
      }

      return function(card) {
        return {
          depender: lookup(card.properties.Depender),
          dependee: lookup(card.properties.Dependee)
        };
      };
    }

    function isNotBroken(dependency) {
      return dependency.depender && dependency.dependee;
    }

    function metFlag(metCards) {
      var isMet = containedIn(metCards);
      return function(dependency) {
        dependency.met = isMet(dependency.dependee);
        return dependency;
      };
    }

    function interestingFlag(interestingCards) {
      if (!interestingCards) {
				return alwaysInteresting;
			}

      var isInteresting = containedIn(interestingCards);
      return function(card) {
        card.interesting = isInteresting(card);
        return card;
      };
    }

    function alwaysInteresting(card) {
      card.interesting = true;
      return card;
    }

    var transform = converter(function(cards, dependencies, metCards, interestingCards) {
      dependencies = map(filter(map(dependencies,
                                    convert(cards)),
                                isNotBroken),
                         metFlag(metCards));
      cards = map(cards, interestingFlag(interestingCards));
      return [cards, dependencies];
    });

    return transform(retrieve);
  };

  dt.dataRetriever = function(projects, dependencyProject, types, extraProperties, metFilter, interestingCardFilter) {
    var typeClause = 'Type IN (' + listOf(types) + ')';
    function cardQuery() {
      var properties = ['Name', 'Number'].concat(extraProperties);
      return "SELECT "+listOf(properties)+" WHERE "+typeClause;
    }
    var metQuery = "SELECT 'Number' WHERE "+typeClause+" AND ("+metFilter+')';
    var interestingCardQuery = "SELECT 'Number' WHERE ("+interestingCardFilter+")";

    function listOf(names) {
      return map(names, function(n) { return "'"+n+"'"; }).join(', ');
    }
    function queryProjects(query) {
      return map(projects, function(project) {
        return function(callbacks) {
          project.query(query, callbacks);
        };
      });
    }
    var dependencyQuery = function(callbacks) {
      dependencyProject.query("SELECT Depender, Dependee WHERE Type IS Dependency",
                              callbacks);
    };

    if(interestingCardFilter) {
      return group(concatenate(aggregate(queryProjects(cardQuery()))),
                   dependencyQuery,
                   concatenate(aggregate(queryProjects(metQuery))),
                   concatenate(aggregate(queryProjects(interestingCardQuery))));
    } else {
      return group(concatenate(aggregate(queryProjects(cardQuery()))),
                   dependencyQuery,
                   concatenate(aggregate(queryProjects(metQuery))));
    }
  };

  var aggregate = dt.aggregate = function(actions) {
    var numResults = 0;
    var results = [];
    var gotError = false;
    function handleResults(callbacks) {
      numResults++;
      if (numResults === actions.length) {
        if (gotError) {
          callbacks.error();
        } else {
          callbacks.success(results);
        }
      }
    }

    return function(callbacks) {
      each(actions, function(action) {
        action({
          success: function(newResults) {
            results.push(newResults);
            handleResults(callbacks);
          },
          error: function() {
            gotError = true;
            handleResults(callbacks);
          }
        });
      });
    };
  };

  var converter = dt.converter = function(conversion) {
    return function(action) {
      return function(callbacks) {
        action({
          success: function() {
            var result = conversion.apply(undefined, arguments);
            if (result && result.length && result.length > 1 && result.length == callbacks.success.length) {
              callbacks.success.apply(undefined, result);
            } else {
              callbacks.success(result);
            }
          },
          error: callbacks.error
        });
      };
    };
  };

  var concatenate = dt.concatenate = converter(function(results) {
    return [].concat.apply([], results);
  });

  var splat = dt.splat = function(action) {
    return function(callbacks) {
      action({
        success: function(result) {
          callbacks.success.apply(undefined, result);
        },
        error: callbacks.error
      });
    };
  };

  var group = dt.group = function() {
    var actions = arguments;
    var numResults = 0;
    var results = [];
    var gotError = false;
    function handleResults(callbacks) {
      numResults++;
      if (numResults === actions.length) {
        if (gotError) {
          callbacks.error();
        } else {
          callbacks.success.apply(undefined, results);
        }
      }
    }

    return function(callbacks) {
      each(actions, function(action, index) {
        action({
          success: function(newResults) {
            results[index] = newResults;
            handleResults(callbacks);
          },
          error: function() {
            gotError = true;
            handleResults(callbacks);
          }
        });
      });
    };
  };

  dt.project = function(name, identifier, ajax, appContext) {
    var url = appContext+'/api/v2/projects/'+identifier+'/cards.xml';
    var self = {
      name: name,
      id: identifier,
      equals: function(other) { return other && self.id == other.id; },
      cardUrl: function(cardNumber) {
	return appContext+'/projects/' + identifier + '/cards/' + cardNumber;
      },
      cardNameUrl: function(cardNumber) {
	return appContext+'/projects/' + identifier + '/cards/card_name/' + cardNumber;
      },
      createDependency: function(dependee, depender, callbacks) {
        ajax.post(url,
                  creationParams(dependee, depender),
                  {
                    success: function(xhr) {
                      var location = xhr.getResponseHeader('Location');
                      putPropertyValues(location, dependee,
                                        depender, callbacks);
                    },
                    error: callbacks.error
                  }
        );
      },
      query: function(mql, callbacks) {
        var url = appContext+'/api/v2/projects/'+identifier+'/cards/execute_mql.json';
        var success = function(_, cardsData) {
          callbacks.success(map(cardsData, function(card) {
            return dt.card.fromMingle(card, self);
          }));
        };
        var error = function(xhr) {
          callbacks.error(xhr);
        };
        ajax.getJSON(url, {mql: mql}, {success: success, error: error});
      }
    };

    function creationParams(dependee, depender) {
      return {'card[name]': nameFor(dependee, depender),
              'card[card_type_name]': 'Dependency' };
    }

    function nameFor(dependee, depender) {
      return 'dependency from '+depender.format(dt.card.formatters.ref)+
        ' on '+dependee.format(dt.card.formatters.ref);
    }

    function putPropertyValues(location, dependee, depender, callbacks) {
      ajax.put(location,
               propertyValues(dependee, depender),
               callbacks);
    }

    function propertyValues(dependee, depender) {
      return 'card[properties][][name]=Dependee&' +
				'card[properties][][value]='+dependee.format(dt.card.formatters.ref)+'&' +
				'card[properties][][name]=Depender&' +
				'card[properties][][value]='+depender.format(dt.card.formatters.ref);
    }

    return self;
  };

  dt.creatorModel = function(currentCard, projects, currentProject) {
    var dependencies;
    var cards;
    var self = {
      saveInProgress: false,
      displayErrorMessage: false,
      currentProject: currentProject,
      selectedDependeeProject: currentProject,
      dependencies: dependencies,
      onChange: function() { /* abstract */ },
      populate: function(cards, theDependencies) {
        self.cards = cards;
        self.dependencies = theDependencies;
        projects = projects.sort(function(a, b) {
          if (a.equals(currentProject)) { return -1; }
          if (b.equals(currentProject)) { return 1; }
          return(a.name > b.name ? 1 : -1);
        });

        self.onChange();
      },
      uiProjects: function() {
        return map(projects, function(project, _){
          return {
            name: project.equals(currentProject) ? "this project" : project.name,
            project: project
          };
        });
      },
      saveStarted: function() {
        self.saveInProgress = true;
        self.displayErrorMessage = false;
        self.onChange();
      },
      saveFinished: function() {
        self.refreshNeeded = true;
        self.onChange();
      },
      errorOccured: function() {
        self.displayErrorMessage = true;
        self.saveInProgress = false;
        self.onChange();
      },
      selectedDependerCard: currentCard,
      isSubmitDisabled: function() {
        return (self.selectedDependerCard == undefined ||
                self.selectedDependeeCard == undefined ||
								dependencyExists(self.selectedDependerCard, self.selectedDependeeCard) ||
								self.selectedDependerCard.equals(self.selectedDependeeCard) );
      },
      greyedOutDependers: function() {
        if (!self.selectedDependeeCard) {
					return [];
				}
        return [self.selectedDependeeCard].concat(getDependers(self.selectedDependeeCard));
      },
      greyedOutDependees: function() {
        if (!self.selectedDependerCard) {
					return [];
				}
        return [self.selectedDependerCard].concat(getDependees(self.selectedDependerCard));
      },
      visibleDependees: function() {
        return filter(self.cards, function(card, _){
          return card.project.equals(self.selectedDependeeProject);
        });
      },
      visibleDependers: function() {
        return filter(self.cards, function(card, _){
          return card.project.equals(self.currentProject) && card.interesting;
        });
      },
      cardSelectChanged: function(depender, dependee) {
        if (!currentCard) {  self.selectedDependerCard = depender; }
        self.selectedDependeeCard = dependee;
        self.onChange();
      },
      projectSelectChanged: function(dependeeProject) {
        self.selectedDependeeProject = dependeeProject;
        self.onChange();
      }
    };

    function dependencyExists(depender, dependee) {
      return filter(self.dependencies, function(d) {
        return d.depender.equals(depender) && d.dependee.equals(dependee);
      }).length > 0;
    }

    function getDependees(card){
      var upstream = filter(self.dependencies, function(d) {
        return d.depender.equals(card);
      });
      return map(upstream, function(d) { return d.dependee; });
    }

    function getDependers(card){
      var downstream = filter(self.dependencies, function(d) {
        return d.dependee.equals(card);
      });
      return map(downstream, function(d) { return d.depender; });
    }

    return self;
  };

  dt.creatorView = function(window, currentCard, appContext, model) {
    var dom;
    var self = {
      bind: function(theDom) {
        dom = theDom;
      },
      onCreateDependency: function() { /* abstract */ },
      onCardSelectChanged: function() { /* abstract */ },
      onProjectSelectChanged: function() { /* abstract */ },
      modelChanged: function(){
	clear();
        we(insert(spinner)).onlyIf(model.saveInProgress);
        we(insert(errorDiv)).onlyIf(model.displayErrorMessage);
        we(refreshPage).onlyIf(model.refreshNeeded);
        createForm();
      },
      selectedDependerCard: function() {
        if (currentCard) {
					return currentCard;
				}
        var ref = dom.find('.dt-depender-card-input option:selected').val();
        return find(model.visibleDependers(), dt.card.withRef(ref));
      },
      selectedDependeeCard: function() {
        var ref = dom.find('.dt-dependee-card-input option:selected').val();
        return find(model.visibleDependees(), dt.card.withRef(ref));
      },
      selectedDependeeProject: function() {
        var identifier = dom.find('.dt-dependee-project-input option:selected').val();
        return find(model.uiProjects(), function(project) {
          return project.project.id == identifier;
        }).project;
      }
    };

    function clear() {
      dom.empty();
    }

    var refreshPage = function() {
      window.location.reload(true);
    };

    function createForm() {
      var form = jQuery('<form>');

      form.append('Create dependency: ');
      if (currentCard) {
        form.append('this card depends on ');
      } else {
        form.append(dependers()).append(' depends on ');
      }

      if (thereIsMoreThanOneProject()) {
        form.append(projects());
      }

      form.append(' ').
				append(dependees()).
				append(' ').
				append(submit()).
				addClass('dt-dependency-creator-form').
				appendTo(dom);
    }

    function submit() {
      return jQuery('<input type="submit" value="create"/>').
				attr('disabled', !!model.isSubmitDisabled()).
				click(function(event) {
          sendOnCreateDependency();
          event.preventDefault();
      });
    }

    function dependers() {
      return cardDropdown({
	cards: model.visibleDependers(),
        disabled: model.greyedOutDependers(),
        selected: model.selectedDependerCard,
        klass: 'dt-depender-card-input'
      });
    }

    function dependees() {
      return cardDropdown({
	cards: model.visibleDependees(),
        disabled: model.greyedOutDependees(),
        selected: model.selectedDependeeCard,
        klass: 'dt-dependee-card-input'
      });
    }

    function thereIsMoreThanOneProject() {
      return model.uiProjects().length > 1;
    }

    function projects() {
      return projectDropdown({
        selected: model.selectedDependeeProject,
	klass: 'dt-dependee-project-input'
      });
    }

    function projectDropdown(spec){
      spec.entries = map(model.uiProjects(), function(uiProject) {
      	return {
          text: uiProject.name,
	  value: uiProject.project.id,
          selected: spec.selected && spec.selected.equals(uiProject.project)
        };
      });
      spec.onChange = sendOnProjectSelectChanged;
      return dropdown(spec);
    }

    function cardDropdown(spec) {
      spec.entries = map(spec.cards, function(card) {
        return {
          value: card.format(dt.card.formatters.ref),
          text: lengthLimited(card.format(dt.card.formatters.canonical)),
          selected: spec.selected && spec.selected.equals(card),
          disabled: inCardArray(card, spec.disabled)
        };
      });

      delete spec.disabled;
      spec.onChange = sendOnCardSelectChanged;
      spec.dummyText = 'choose a card...';
      spec.disabledClass = 'dt-disabled';
      return dropdown(spec);
    }

    var errorDiv = jQuery('<div class="dt-dependency-creator-error">The dependency could not be created.</div>');
    var spinner = jQuery('<img class="dt-dependency-creator-spinner" src="'+appContext+'/images/ajax-spinner-big.gif"/>');
    function insert(element) {
      var action = function() { dom.prepend(element); };
      return action;
    }

    function sendOnProjectSelectChanged() {
      self.onProjectSelectChanged(self.selectedDependeeProject());
    }
    function sendOnCardSelectChanged() {
      self.onCardSelectChanged(self.selectedDependerCard(), self.selectedDependeeCard());
    }
    function sendOnCreateDependency() {
       self.onCreateDependency(self.selectedDependerCard(), self.selectedDependeeCard());
    }
    return self;
  };

  dt.ajax = function(jquery, logger) {
    function wrapper(method, dataType) {
      dataType = dataType || 'text';
      return function(url, data, callbacks) {
        var succeeded;
        var responseData;
        jquery.ajax({
          type: method, url: url, data: data, dataType: dataType,
          success: function(data) {
            succeeded = true;
            responseData = data;
          },
          error: function() {
            succeeded = false;
          },
          complete: function(xhr) {
            if (succeeded) {
							callbacks.success(xhr, responseData);
						} else {
	      logger.requestFailed({method: method,
				    url: url,
				    params: data,
				    status: xhr.status,
				    responseBody: xhr.responseText});
	      callbacks.error(xhr);
	    }
          }
        });
      };
    }
    return {
      get: wrapper('GET'),
      post: wrapper('POST'),
      put: wrapper('PUT'),
      getJSON: wrapper('GET', 'json')
    };
  };

  dt.creatorController = function(project, model, view) {
    return {
      init: function() {
        view.onCreateDependency = function(depender, dependee) {
          model.saveStarted();
          project.createDependency(dependee, depender, {
            success: model.saveFinished,
            error: model.errorOccured
          });
        };

        view.onCardSelectChanged = function() { model.cardSelectChanged.apply(undefined, arguments); };
        view.onProjectSelectChanged = function() { model.projectSelectChanged.apply(undefined, arguments); };
        model.onChange = view.modelChanged;
      }
    };
  };

  dt.displayView = function(currentCard, model, programMacro) {
    var dom;

    function insertDropdown(theDom) {
      var textFormatter = programMacro ? 'withProjectName' : 'canonical';
      var spec = {
        size: 15,
        onChange: sendOnCardSelectChanged,
        dummyText: "Select a card to see its dependencies",
        selected: model.selectedCard()
      };

      spec.entries = map(model.cards, function(card) {
        return {
          klass: model.hasUnmetDependencies(card) ? 'dt-card-with-unmet' : 'dt-card-with-no-unmet',
          tooltip: card.format(dt.card.formatters[textFormatter]),
          text: lengthLimited(card.format(dt.card.formatters[textFormatter])),
          value: card.format(dt.card.formatters.ref),
          selected: spec.selected && spec.selected.equals(card)
        };
      });
      dom.append(dropdown(spec));
    }

    function populateUpstreamTable() {
      var spec = {klass: 'dt-upstream', caption:'Depends on'};
      if (model.upstream().length === 0) {
        spec.headers = [''];
        spec.rows = [{data: {'': noDependenciesMessage()}}];
      } else {
        var extraProperties = propertyNamesOf(model.upstream()[0].dependee.properties);
        spec.headers = ['Met?', 'Project', ''].concat(extraProperties);
        spec.rows = map(model.upstream(), rowForDependency(extraProperties));
      }
      dom.append(tableWith(spec));
    }
    function rowForDependency(properties){
      return function(dependency) {
        var metClass = dependency.met ? 'dt-met-dependency' : 'dt-unmet-dependency';
        var data = {
          'Met?': dependency.met? 'Yes' : 'No',
          'Project': dependency.dependee.project.name,
          '': dependency.dependee.format(dt.card.formatters.link)
        };
        each(properties, function(property){
          var value = dependency.dependee.properties[property];
          if (value && value.format) {
              value = value.format(dt.card.formatters.link);
          }
          data[property] = value;
        });
        return {classes: ['dt-dependency', metClass], data: data};
      };
    }

    function populateDownstreamTable() {
      var spec = {klass: 'dt-downstream', caption: 'Depended on by'};
      if (model.downstream().length === 0) {
        spec.headers = [''];
        spec.rows = [{data: {'': noDependenciesMessage()}}];
      } else {
        spec.headers = ['Project', 'Card'];
        spec.rows = map(model.downstream(), function(dependency) {
          return {
            classes: ['dt-dependency'],
            data: {
              Project: dependency.depender.project.name,
              Card: dependency.depender.format(dt.card.formatters.link)
            }
          };
        });
      }
      dom.append(tableWith(spec));
    }

    function noDependenciesMessage() {
      return programMacro ? 'There are no cross-project dependencies' : 'There are no dependencies';
    }

    function tableWith(spec) {
      var table = jQuery('<table>').
				addClass(spec.klass).
				append(jQuery('<caption>').text(spec.caption));
      var headerRow = jQuery('<tr>').
				appendTo(table);
      each(spec.headers, function(header) {
        headerRow.append('<th>'+(header ? header : '&nbsp;')+'</th>');
      });
      each(spec.rows, function(rowData) {
        var row = jQuery('<tr>').appendTo(table);
        if (rowData.classes) {
          each(rowData.classes, function(c) { row.addClass(c); });
        }
        each(spec.headers, function(header) {
          var entry = rowData.data[header];
          row.append('<td>' + (entry ? entry : '&nbsp;') + '</td>');
        });
      });
      return table;
    }

    function sendOnCardSelectChanged() {
      var ref = dom.find('select option:selected').val();
      var card = find(model.cards, dt.card.withRef(ref));
      self.onCardChanged(card);
    }

    var self = {
      bind: function(theDom) {
        dom = theDom;
      },
      modelChanged: function() {
        dom.empty();
        populateDownstreamTable();
        if (!currentCard) { insertDropdown(dom); }
        populateUpstreamTable();
      },
      onCardChanged: function(selected) { /* abstract */ }
    };

    return self;
  };

  dt.displayModel = function(currentCard, currentProject, programMacro) {
    var dependencies;
    var upstreams = {};
    var downstreams = {};
    var self = {
      onChange: function() { /* abstract */ },
      populate: function(cards, dependencies) {
        setDependencies(dependencies);
        setCards(cards);
        self.onChange();
      },
      upstream: function() {
        if (!self.selectedCard()) { return []; }
        return renameCurrentProject(sort(upstreamOf(self.selectedCard()), 'dependee'),
                                    'dependee');
      },
      downstream: function() {
        if (!self.selectedCard()) { return []; }
        return renameCurrentProject(sort(downstreamOf(self.selectedCard()), 'depender'),
                                    'depender');
      },
      hasUnmetDependencies: function(card) {
        var hasUnMet = false;
        each(upstreamOf(card), function(dependency) {
          if(!dependency.met) {
            hasUnMet = true;
					}
        });
        return hasUnMet;
      }
    };

    if (currentCard) {
      self.selectedCard = function() { return currentCard; };
    } else {
      (function() {
        var selectedCard;
        self.selectedCard = function(card) {
	  if (arguments.length != 0) {
	    selectedCard = card;
            self.onChange();
	  }
          return selectedCard;
        };
      })();
    }

    function setDependencies(theDependencies) {
      function differentProjects(dependency) {
        return !dependency.depender.project.equals(dependency.dependee.project);
      }

      if (programMacro) {
        dependencies = filter(theDependencies, differentProjects);
      } else {
        dependencies = theDependencies;
      }

      each(dependencies, function(dependency) {
        if (!upstreams[dependency.depender]) {
					upstreams[dependency.depender] = [];
				}
        upstreams[dependency.depender].push(dependency);
      });

      each(dependencies, function(dependency) {
        if (!downstreams[dependency.dependee]) {
					downstreams[dependency.dependee] = [];
				}
        downstreams[dependency.dependee].push(dependency);
      });
    }

    function setCards(rawCards) {
      function isInteresting(card) { return card.interesting; }
      function isInCurrentProject(card) { return card.isIn(currentProject); }
      function byProjectNameAndCardNumber(card1, card2) {
        if (card1.project.equals(card2.project)) {
          return card1.number - card2.number;
        }
	return(card1.project.name > card2.project.name ? 1 : -1);
      }
      function cardHash(card) { return card.number+'-'+card.project.id; }
      function withDependencies(card) {
        return upstreamOf(card).length > 0 || downstreamOf(card).length > 0;
      }

      var cards = unique(cardHash, rawCards.sort(byProjectNameAndCardNumber));
      if (programMacro) {
        cards = filter(cards, withDependencies);
      } else {
        cards = filter(cards, isInCurrentProject);
      }
      self.cards = filter(cards, isInteresting);
    }

    function upstreamOf(card) {
      return upstreams[card] || [];
    }
    function downstreamOf(card) {
      return downstreams[card] || [];
    }

    //TODO: needs refactoring
    function sort(dependencies, field) {
      return dependencies.sort(function(dependency1, dependency2){
	if(dependency1[field].project.name === dependency2[field].project.name) {
	  return (dependency1[field].number - dependency2[field].number);
	} else {
	  if(dependency1[field].project.equals(currentProject)) {
	    return 1;
	  } else if (dependency2[field].project.equals(currentProject)){
	    return -1;
	  } else if (dependency1[field].project.name > dependency2[field].project.name) {
            return 1;
	  } else {
            return -1;
          }
	}
      });
    }
    function renameCurrentProject(dependencies, field) {
      return jQuery.map(dependencies, function(dependency, _){
	if (dependency[field].project.equals(currentProject)) {
	  dependency[field].project.name = "this project";
	}
	return dependency;
      });
    }
    return self;
  };

  dt.displayController = function(model, view) {
    return {
      init: function() {
        view.onCardChanged = model.selectedCard;
        model.onChange = function() { view.modelChanged(); };
      }
    };
  };

  dt.statusBarController = function(model, view) {
    return {
      init: function() {
	model.onChange = view.modelChanged;
	view.onToggleErrorDetails = model.toggleLogs;
      }
    };
  };

  dt.statusBarView = function(model, appContext) {
    var dom;
    var spinnerDiv = jQuery('<p><img class="dt-status-spinner" src="' + appContext + '/images/ajax-spinner-big.gif"></img>The Dependency Tracker is loading.</p>');

    var self = {
      onToggleErrorDetails: function() { /* abstract */ },
      bind: function(theDom) {
	dom = theDom;
      },
      modelChanged: function() {
	dom.empty();
	we(insert(logs())).onlyIf(model.showLogs());
	we(insert(errorDiv())).onlyIf(model.displayErrorMessage);
	we(insert(spinnerDiv)).onlyIf(model.displaySpinner);
      }
    };

    function logs() {
      var els = jQuery('<ul class="dt-logs"/>');
      jQuery.each(model.logs(), function(_, log) {
	var itemText = "Request failed: " + JSON.stringify(log);
	jQuery("<li>").text(itemText).appendTo(els);
      });
      return els;
    }

    function errorDiv() {
      var errorText = model.showLogs() ? 'Hide details' : 'Show details';
      var errorLink = jQuery('<a href="#">'+errorText+'</a>').
				click(self.onToggleErrorDetails);
      return jQuery('<div class="dt-status-error">There was an error in loading the Dependency Tracker data. There may be a problem with the macro configuration or with your Mingle server.</div>').
				append(' (').append(errorLink).append(')');
    }

    function insert(element) {
      return function() { dom.prepend(element); };
    }

    return self;
  };

  dt.statusBarModel = function(logger) {
    var showLogs = false;

    var self = {
      displayErrorMessage: false,
      displaySpinner: false,
      logs: function() { return logger.errorDetails; },
      toggleLogs: function() {
        showLogs = !showLogs;
        self.onChange();
      },
      showLogs: function(show) {
	return showLogs;
      },
      onChange: function() { /* abstract */ },
      errorOccurred: function() {
	self.displayErrorMessage = true;
	self.onChange();
      },
      loadingStarted: function() {
	self.displaySpinner = true;
	self.onChange();
      },
      loadingFinished: function() {
        self.displaySpinner = false;
        self.onChange();
      }
    };
    return self;
  };

  dt.card = function(number, name, properties, project) {
    var self = {
      number: number,
      name: name,
      project: project,
      properties: properties,
      format: function(formatter) { return formatter(number, name, project); },
      toString: function() {
        return self.format(dt.card.formatters.ref);
      },
      equals: function(other) {
        if (!other) {
          return false;
        }
        if ((typeof self.project !== "undefined") && (typeof other.project !== "undefined")) {
          return (self.number === other.number) && (self.project.equals(other.project));
        } else {
          return self.number === other.number;
        }
      },
      isIn: function(project) {
        return project.equals(self.project);
      }
    };
    if (properties) {
      each(self.properties, function(value, key){
        var parsed = dt.card.parse(value, {}, project);
        if(parsed) {
          self.properties[key] = parsed;
        }
      });
    }
    return self;
  };
  dt.card.fromMingle = function(c, project) {
    var properties = {};
    each(c, function(value, property) {
      if ((property !== 'Name') && (property !== 'Number')) {
        properties[property] = value;
      }
    });
    return dt.card(c.Number, c.Name, properties, project);
  };
  dt.card.parse = function(cardString, props, project) {
    var match = cardString && cardString.match(/^#(\d+) (.*)/);
    return match && dt.card(match[1], match[2], props, project);
  };
  dt.card.formatters = {
    canonical: function(number, name) { return '#'+number+' '+name; },
    withProjectName: function(number, name, project) {
      return project.name+': '+dt.card.formatters.canonical(number, name);
    },
    ref: function(number, name, project) {
      return project.id+'/#'+number;
    },
    link: function(number, name, project) {
      var anchor = jQuery('<a>#' + number + '</a>');
      var div = jQuery('<div>').append(jQuery('<span>').append(anchor));
      anchor.attr('onmouseover', 'new Tooltip(this, event)');
      anchor.attr('href', project.cardUrl(number));
      anchor.attr('card_name_url', project.cardNameUrl(number));
      anchor.addClass('card-link-' + number);
      div.append(' ' +name);
      return div.html();
    }
  };
  dt.card.withRef = function(ref) {
    return function(card) { return card.format(dt.card.formatters.ref) == ref; };
  };

  dt.emptyModel = function() {
    return {
      populate: function() {}
    };
  };

  dt.emptyView = function() {
    return {
      bind: function() {}
    };
  };

  dt.emptyController = function() {
    return {
      init: function() {}
    };
  };

  dt.containerModel = function(display, creator, statusBar) {
    var self = {
      onChange: function() { /* abstract */ },
      populate: function(cards, dependencies) {
        self.onChange();
        display.populate(cards, dependencies);
        creator.populate(cards, dependencies);
      },
      errorOccurred: function() {
        self.onChange();
	statusBar.errorOccurred();
      },
      loadingStarted: function() {
        self.onChange();
	statusBar.loadingStarted();
      },
      loadingFinished: function() {
        self.onChange();
	statusBar.loadingFinished();
      }
    };
    return self;
  };

  dt.containerView = function(display, creator, statusBar) {
    var dom;
    return {
      bind: function(theDom) {
	dom = theDom;
      },
      modelChanged: function() {
	dom.empty();

	var displayDom = jQuery('<div>').addClass('dt-display').appendTo(dom);
	var creatorDom = jQuery('<div>').addClass('dt-creator').appendTo(dom);
	var statusBarDom = jQuery('<div>').addClass('dt-status-bar').appendTo(dom);

	display.bind(displayDom);
	creator.bind(creatorDom);
	statusBar.bind(statusBarDom);
      }
    };
  };

  dt.containerController = function(dataSource, display, creator, statusBar, model, view) {
    return {
      init: function() {
        model.onChange = view.modelChanged;

	statusBar.init();
	model.loadingStarted();

        dataSource({
          success: function(cards, dependencies) {
            model.loadingFinished();
            model.populate(cards, dependencies);
          },
	  error: function() {
            model.loadingFinished();
	    model.errorOccurred();
	  }
        });

        display.init();
        creator.init();
      }
    };
  };

  dt.logger = function() {
    var self = {
      errorDetails: [],
      requestFailed: function(details) {
	self.errorDetails.push(details);
      }
    };
    return self;
  };

   dt.mingle = function(appContext, ajax) {
    return {
      getProjects: function(requestedIds, callbacks) {
        var url = appContext + '/api/v2/projects.xml?name_and_id_only';
        ajax.get(url, null, {
          success: processResults,
          error: callbacks.error
        });

        function processResults(xhr) {
          var projects = [];
          var retrievedIds = [];
          jQuery(xhr.responseText).find('project').each(function (_, node) {
            var project = jQuery(node);
            var id = project.children('identifier').text();
            var name = project.children('name').text();
            if (inArray(id, requestedIds)) {
              projects.push(dt.project(name, id, ajax, appContext));
              retrievedIds.push(id);
            }
          });

          var invalidProjects = [];
          if (retrievedIds.length < requestedIds.length) {
            each(requestedIds, function(id) {
              if (!inArray(id, retrievedIds)) {
                invalidProjects.push(id);
              }
            });
          }

          callbacks.success(projects, invalidProjects);
        }
      }
    };
  };

  dt.init = function(appContext, dom, currentProjectIdentifier, currentCardNumber, projectIds, dependencyProjectId,
                     extraProperties, cardTypes, metFilter, programMacro,
                     interestingCardFilter) {
    var logger = dt.logger();
    var ajax = dt.ajax(jQuery, logger);
    var dependencyProject = dt.project(undefined, dependencyProjectId, ajax,
                                       appContext);

    var mingle = dt.mingle(appContext, ajax);

    mingle.getProjects(projectIds, {
      success: function(projects, invalidIds) {
        if (invalidIds.length > 0) {
          reportInvalidProjects(invalidIds);
        } else {
          runApp(projects);
        }
      },
      error: reportError
    });

    function runApp(projects) {
      var currentProject = findProp(projects, 'id', currentProjectIdentifier);
      var currentCard = currentCardNumber ? dt.card.fromMingle({Number: currentCardNumber}, currentProject) : undefined;

      var dataSource = dt.dataSource(dt.dataRetriever(projects, dependencyProject, cardTypes,
                                                      extraProperties, metFilter, interestingCardFilter));
      var container = createComponents(currentCard, window, appContext, currentProject,
                                       dataSource, programMacro, projects, dependencyProject,
                                       logger);
      container.view.bind(dom);
      container.controller.init();
    }

    function reportInvalidProjects(ids) {
      jQuery('<p>').
				text("Some of the projects specified in the Dependency Tracker macro parameters could not be found. Either they do not exist or you do not have permissions to access them. The projects that couldn't be found are:").
				appendTo(dom);
      var list = jQuery('<ul>').appendTo(dom);
      each(ids, function(id) {
        jQuery('<li>').text(id).appendTo(list);
      });
    }

    function reportError() {
      jQuery('<p>').text('There was an error in loading the Dependency Tracker data. There may be a problem with the macro configuration or with your Mingle server:').appendTo(dom);
      each(logger.errorDetails, function(log) {
        jQuery('<p>').text(JSON.stringify(log)).appendTo(dom);
      });
    }
  };

  function createComponents(currentCard, window, appContext, currentProject, dataSource,
                            programMacro, projects, dependencyProject, logger) {
    var displayModel = dt.displayModel(currentCard, currentProject, programMacro);
    var displayView = dt.displayView(currentCard, displayModel, programMacro);
    var displayController = dt.displayController(displayModel, displayView);

    var creatorModel;
    var creatorView;
    var creatorController;
    if (programMacro) {
      creatorModel = dt.emptyModel();
      creatorView = dt.emptyView();
      creatorController = dt.emptyController();
    } else {
      creatorModel = dt.creatorModel(currentCard, projects, currentProject);
      creatorView = dt.creatorView(window, currentCard, appContext, creatorModel);
      creatorController = dt.creatorController(dependencyProject, creatorModel, creatorView);
    }

    var statusBarModel = dt.statusBarModel(logger);
    var statusBarView = dt.statusBarView(statusBarModel, appContext);
    var statusBarController = dt.statusBarController(statusBarModel, statusBarView);

    var containerModel = dt.containerModel(displayModel, creatorModel, statusBarModel);
    var containerView = dt.containerView(displayView, creatorView, statusBarView);
    var containerController = dt.containerController(dataSource,
				displayController, creatorController, statusBarController,
				containerModel, containerView);
    return {
      model: containerModel,
      view: containerView,
      controller: containerController
    };
  }

  function dropdown(spec) {
    var select = jQuery('<select>').
			change(spec.onChange).
			addClass(spec.klass);

    if(spec.size) {
      select.attr('size', spec.size.toString());
    }

    var options = [];

    spec.dummyText && options.push('<option>'+spec.dummyText+'</option>');

    each(spec.entries, function(entry) {
      var classes = [];
      entry.klass && classes.push(entry.klass);
      entry.disabled && classes.push(spec.disabledClass);

      var klass = classes.length ? ' class="'+classes.join(' ')+'"' : '';
      var title = entry.tooltip ? ' title="'+entry.tooltip+'"' : '';
      var selected = entry.selected ? ' selected="selected"' : '';
      var disabled = entry.disabled ? ' disabled="disabled"' : '';

      options.push('<option value="'+entry.value+'"'+klass+title+selected+disabled+'>'+entry.text+'</option>');
    });
    select.html(options.join());

    return select;
  }

  function we(action) {
    return {
      onlyIf: function(predicate) {
        if(predicate) {
          action();
        }
      }
    };
  }
  function lengthLimited(text) {
    return text.length<45 ? text : text.substring(0, 40)+'...';
  }
  function unique(reduction, array) {
    var result = [];
    var ids = [];
    each(array, function(item) {
      if (!inArray(reduction(item), ids)) {
        result.push(item);
        ids.push(reduction(item));
      }
    });
    return result;
  }
  function filterProp(name, value, array) {
    return filter(array, function(item) { return item[name]==value; });
  }
  function mapProp(property, array) {
    return map(array, function(i) { return i[property]; });
  }
  function find(list, predicate) {
    return filter(list, predicate)[0];
  }
  function findProp(array, name, value) {
    return find(array, function(item) { return item[name] == value; });
  }
  var filter = jQuery.grep;
  var map = jQuery.map;
  function inArray(item, array) {
    return -1 != jQuery.inArray(item, array);
  }
  function each(list, f) {
    jQuery.each(list, function(index, item) {
      f(item, index);
    });
  }
  function propertyNamesOf(object) {
    var names = [];
    for (var name in object) {
      names.push(name);
    }
    return names;
  }
  function and(predicate1, predicate2) {
    return function(subject) {
      return predicate1(subject) && predicate2(subject);
    };
  }

  // Uses hashing to determine membership, rather than equality
  function containedIn(array) {
    var hash = {};
    each(array, function(item) {
      hash[item] = true;
    });
    return function(item) {
      return hash[item];
    };
  }

  function inCardArray(card, array) {
    if (array == undefined) { return false; }
    var match = filter(array, function(arrayCard){
      return arrayCard.equals(card);
    });
    return match.length != 0;
  }
})(DependencyTracker);
