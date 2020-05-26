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
import Vuex from 'vuex';
import createToggles from './modules/toggles'

export default function createStore(objectivesService, data) {
  return new Vuex.Store({
    state: {
      objectives: data.objectives,
      disableDragging: false,
      message: {},
      currentObjectiveData: {},
      nextObjectiveNumber: data.nextObjectiveNumber,
      defaultObjectiveType: data.defaultObjectiveType,
    },
    modules: {
      toggles: createToggles(data.toggles)
    },
    getters:{
      groupObjectiveBy(state){
        return function(groupBy) {
          return state.objectives.reduce((groupedObjectives, objective) => {
            let groupingProp = objective[groupBy];
            if (!groupedObjectives.hasOwnProperty(groupingProp)) groupedObjectives[groupingProp] = [];
            groupedObjectives[groupingProp].push(objective);
            return groupedObjectives;
          }, {});
        }
      }
    }
    ,
    mutations: {
      deleteObjective(state, number) {
        for (let i = state.objectives.length - 1; i >= 0; i--) {
          if (state.objectives[i].number === number) {
            state.objectives.splice(i, 1);
            break;
          }
        }
      },

      updateMessage(state, message) {
        state.message = message;
      },

      updateObjectives(state, objective){
        for (let i =0; i <= state.objectives.length - 1; i++) {
          if (state.objectives[i].number === objective.number) {
            state.objectives.splice(i, 1, objective);
            break;
          }
        }
      },

      updateCurrentObjective(state, objective) {
        state.currentObjectiveData = objective;
      },

      updateNextObjectiveNumber(state, newNumber) {
        state.nextObjectiveNumber = newNumber;
      },

      addNewObjective(state, objective) {
        state.objectives.unshift(objective);
      }
    },

    actions: {
      updateObjectivesOrder(context, objectives) {
        context.state.disableDragging = true;
        return new Promise((resolver) => {
          objectivesService.reorder({
            ordered_backlog_objective_numbers: objectives.map(obj => obj.number)
          }).then(response => {
            context.state.objectives = response.data;
            context.state.disableDragging = false;
            resolver();
          }, (response) => {
            console.log('[ERROR]:', response);
            context.state.disableDragging = false;
            resolver();
          });
        });
      },
      fetchObjective(context, number) {
        return new Promise((resolver) => {
          objectivesService.fetchFor(number).then((result) => {
            if (!result.success) {
              if (result.errorType === "deleted") {
                this.commit("deleteObjective", number);
              }
              this.commit("updateMessage", {type: 'error', text: result.error});
              resolver({success: false});
            } else {
              this.commit('updateCurrentObjective', result.data);
              resolver({success: true, data: result.data});
            }
          });
        });
      },

      deleteObjective(context, number) {
        return new Promise((resolver) => {
          objectivesService.delete(number).then((result) => {
            if (result.success) {
              this.commit("deleteObjective", number);
              this.commit("updateMessage", {
                type: 'success',
                text: `Objective #${number} was deleted successfully.`
              });
            } else {
              this.commit("updateMessage", {type: 'error', text: result.error});
            }
            resolver(result);
          }
          )
        }
        );
      },

      updateCurrentObjective(context, options) {
        return new Promise((resolver) => {
          objectivesService.update(options.objectiveData).then((result) => {
            let message;
            if (result.success) {
              options.scopedMessage = !options.scopedMessage
              this.commit("updateCurrentObjective", result.data);
              this.commit('updateObjectives', result.data);
              message = {
                type: 'success',
                text: `Objective #${options.objectiveData.number} was updated successfully.`
              };
            } else {
              message = {type: 'error', text: result.error};
            }
            if(result.errorType == 'deleted' || (!options.scopedMessage && options.eventName == 'Save and Close')){
              this.commit('updateMessage', message);
              options.scopedMessage = !options.scopedMessage; 
              resolver(result);   
            }
            options.scopedMessage ? resolver({message,success:result.success}) : resolver({success:result.success});

          });
        });
      },

      planObjective(context, number) {
        return new Promise((resolver) => {
          objectivesService.planObjective(number).then((result) => {
            if(!result.success) {
              this.commit("updateMessage", {type: 'error', text: result.error});
              if(result.errorType === "deleted") {
                this.commit("deleteObjective", number);
              }
              resolver(result);
            }
          });
        });
      },

      changeObjectivePlan(context, number) {
        return new Promise((resolver) => {
          objectivesService.changePlan(number).then((result) => {
            if(!result.success) {
              this.commit("updateMessage", {type: 'error', text: result.error});
              if(result.errorType === "deleted") {
                this.commit("deleteObjective", number);
              }
              resolver(result);
            }
          });
        });
      },

      updateCurrentObjectiveToDefault(context, newObjectiveData) {
        this.commit('updateCurrentObjective', newObjectiveData);
      },

      createObjective(context, objectiveData){
        return new Promise((resolver) => {
          objectivesService.create(objectiveData).then((result) => {
            let response = {};
            if(result.success){
              let objective = result.data;
              this.commit('addNewObjective', {name:objective.name, position:objective.position, number:objective.number, value: objective.value, size: objective.size, status:objective.status});
              this.commit('updateCurrentObjective', result.data);
              this.commit('updateNextObjectiveNumber', objective.number +1);
              response.success = result.success;
            }else{
              response.success = result.success;
              response.message = {type:'error', text:result.error};
            }
            resolver(response);
          });
        });
      }
    }
  });
}
