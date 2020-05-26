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
    <li class="objective" :class="{'dragging-disabled':isDraggingDisabled}" :id="`objective_${objective.number}`"
        v-on:click="openObjectivePopup(objective)" :data-objective-number="objective.number" :data-position="objective.position" :data-status="objective.status">
        <progress-bar v-if="showProgressBar || showProgressBarOnDrop" :target="`#objective_${objective.number}`" />
        <div class="card-content">
    <span class="number">{{ objective.number }}</span>
    <div class="name">{{ objective.name }}</div>
        </div>
  </li>
</template>

<script>
  import ProgressBar from "../ProgressBar";

  export default {
    components: {ProgressBar},
    props: {
      objective: {
        type: Object,
        required: true
      },
      disableDragging: {
        default: false
      },
      droppedObjectiveNumber:{
        type: Number,
        default: null
      }
    },
    data() {
      return {
        showProgressBar: false
      };
    },
    methods: {
      toggleProgress() {
        this.showProgressBar = !this.showProgressBar;
      },
      openObjectivePopup: function (objective) {
        this.toggleProgress();
        this.$store.dispatch('fetchObjective', objective.number).then((result) => {
          this.toggleProgress();
          if (result.success) {
            this.$emit('open-objective');
          }
        });
      }
    },
    computed:{
      isDraggingDisabled: function() {
        return this.$store.state.disableDragging;
      },
      showProgressBarOnDrop(){
        return this.droppedObjectiveNumber === this.objective.number;
      }
    }
  };
</script>

<style lang="scss" scoped>
    li.objective {
        width: 200px;
        height: 125px;
        list-style: none;
        background-color: #FFFFFF;
        box-shadow: 1px 2px 3px 0 #989393;
        display: inline-block;
        margin: 10px;
        vertical-align: top;
        cursor: move;
        .card-content {
            padding-top: 5px;
        }
        .name {
            padding-left: 5px;
        }
        .number {
            float: right;
            padding-right: 5px;
            text-decoration: underline;
            font-weight: bold;

            &:before {
                content: "#";
            }
        }
        &.dragging-disabled {
            cursor: not-allowed;
        }
        &:hover {
            box-shadow: -0.1px -0.1px 3px 0px #989393;
        }
    }
</style>
