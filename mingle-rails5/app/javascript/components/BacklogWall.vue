<!--
Copyright 2020 ThoughtWorks, Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
-->
<template>
    <div>
        <message-box/>
        <div class="add-objective-container" >
            <h1>Capture and Prioritize Objectives</h1>

            <input class="new-objective-name" type="text" maxlength="80" placeholder="Create a new objective for your program"
                   v-model="newObjectiveName" v-if="showCreateObjective" @keyup.enter="enterKeyPressed"/>
            <button :disabled="emptyNewObjectiveName" class="create-objective primary" @click="openAddObjectivePopup" v-if="showCreateObjective">
                <span class="fa fa-plus"></span>
                CREATE
            </button>
        </div>
        <div class="objectives-swim-lanes">
            <swim-lane v-for="objectiveGroupName in objectiveGroupNames()"
                       :objectives="objectiveGroups[objectiveGroupName]||[]"
                       :swim-lane-name="objectiveGroupName"
                       @open-objective="openObjectivePopup"/>
        </div>
        <modal v-bind="modalConfig"  :name="objectivePopupName" @resize="resizeEditor" >
            <component :is="modalComponent" v-bind="objectivePopupParams" @close="$modal.hide(objectivePopupName)" />
        </modal>
    </div>
</template>

<script>
  import Objective from './objectives/Objective';
  import MessageBox from './MessageBox.vue';
  import ObjectivePopUp from './objectives/ObjectivePopUp.vue';
  import Draggable from 'vuedraggable';
  import SwimLane from "./SwimLane";

  export default {
    components: {
      SwimLane,
      'objective': Objective,
      draggable: Draggable,
      'message-box': MessageBox
    },
    data: function () {
      return {
        newObjectiveName: '',
        objectivePopupName: 'objective_popup',
        modalComponent: ObjectivePopUp,
        modalConfig: {
          resizable: true, minWidth: 800, minHeight: 558, width: 800, height: 558, scrollable: true, reset: true
        },
        objectivePopupParams: {popupResized: false, mode: 'VIEW'} ,
      };
    },
    computed:{
      objectiveGroups() {
        return this.$store.getters.groupObjectiveBy('status');
      },

      emptyNewObjectiveName() {
        return this.newObjectiveName.trim() === '';
      },
      showCreateObjective() {
        return !this.$store.state.toggles.readOnlyModeEnabled;
      }
    },
    methods: {
      openAddObjectivePopup() {
        let newObjectiveData = {
          name: this.newObjectiveName,
          number: this.$store.state.nextObjectiveNumber,
          value_statement: this.$store.state.defaultObjectiveType.value_statement,
          property_definitions:this.$store.state.defaultObjectiveType.property_definitions
        };
        this.$store.dispatch('updateCurrentObjectiveToDefault', newObjectiveData);
        this.objectivePopupParams.mode = 'ADD';
        this.$modal.show(this.objectivePopupName);
        this.resetNewObjectiveName();
      },

      enterKeyPressed() {
        if (!this.emptyNewObjectiveName) {
          this.openAddObjectivePopup();
        }
      },

      resizeEditor() {
        this.objectivePopupParams.popupResized = !this.objectivePopupParams.popupResized;
      },

      openObjectivePopup() {
        this.objectivePopupParams.mode = 'VIEW';
        this.$modal.show(this.objectivePopupName);
        this.resetNewObjectiveName();
      },

      resetNewObjectiveName() {
        this.newObjectiveName = '';
      },
      objectiveGroupNames() {
        return ['BACKLOG', 'PLANNED'];
      }
    }
  }
</script>
<style lang="scss">
    .objectives-swim-lanes {
        margin-top: 10px;
        display: flex;
        min-height: 200px;
    }

    .add-objective-container {
        margin-bottom: 20px;
        input.new-objective-name {
            width: 35%;
            margin-right: 20px;
        }
    }

    button:disabled {
        background: #EEE;
        border: 1px #c9c9c9 solid;
        color: #999;
        cursor: default;
        opacity: 1;

        &:hover {
            background: #EEE;
            color: #999;
        }
    }
</style>
