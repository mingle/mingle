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
    <div class="objectives-swim-lane" :id="`${swimLaneName.toLowerCase()}_swim_lane`">
        <div class="objectives-swim-lane-header" :class="{'cell-highlighted': draggingInProgress}">
            <strong>{{swimLaneName.toTitleCase()}} ({{orderedObjectives.length}})</strong>
        </div>
        <div class="objectives" :class="{'cell-highlighted': draggingInProgress}">
            <draggable class="list-group" :list="orderedObjectives"
                       :options="{ghostClass: 'ghost', disabled:isDraggingDisabled}"
                       @start="draggingStarted" @end="draggingEnded">
                <transition-group type="transition" :name="'flip-list'" tag="ul">
                    <objective v-for="objective in orderedObjectives"
                               :objective="objective"
                               :dropped-objective-number="droppedObjectiveNumber"
                               :key="objective.number"
                               v-bind:style="{cursor: computedCursorStyle}"
                               @open-objective="$emit('open-objective')"/>
                </transition-group>
            </draggable>
        </div>
    </div>
</template>

<script>
  import Objective from './objectives/Objective';
  import Draggable from 'vuedraggable';

  export default {
    components: {
      'objective': Objective,
      draggable: Draggable,
    },
    props: {
      objectives: {
        required: true,
        type: Array
      },
      swimLaneName: {
        required: true,
        type: String
      }
    },
    data: function () {
      return {
        draggingInProgress: false,
        droppedObjectiveNumber: null,
      };
    },
    computed: {
      orderedObjectives() {
        return (this.objectives || []).sort((leftObjective, rightObjective) => {
          return leftObjective.position - rightObjective.position;
        });
      },

      isDraggingDisabled: function () {
        return this.$store.state.disableDragging||this.$store.state.toggles.readOnlyModeEnabled;
      },

      computedCursorStyle: function () {
        return this.$store.state.toggles.readOnlyModeEnabled ? 'default' : 'move';
      }
    },
    methods: {
      draggingStarted() {
        this.draggingInProgress = true;
      },
      draggingEnded(event) {
        this.draggingInProgress = false;
        this.droppedObjectiveNumber = +event.item.dataset.objectiveNumber;
        this.$store.dispatch('updateObjectivesOrder', this.objectives).then(() => {
          this.droppedObjectiveNumber = null;
        });
      }
    }
  }
</script>
<style lang="scss">
    .objectives-swim-lane {
        flex: 1;
        .objectives-swim-lane-header {
            width: 100%;
            background: #eeeeee;
            text-align: center;
            padding: 10px;
        }
        .objectives {
            background-color: #eeeeee;
            height: 100%;
        }
        .ghost {
            background-color: #fbf9ef !important;
            box-shadow: none !important;
            * {
                opacity: 0;
            }
        }
        .cell-highlighted {
            background-color: #cee7ed;
        }
    }

    #backlog_swim_lane.objectives-swim-lane {
        margin-right: 20px;
    }

</style>
