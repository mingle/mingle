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
  <div class="view-popup-container">
    <div class="objective-content">
      <div class="header">
        <h1>
          <span class="number"> #{{objective.number}} </span>
          <span class="name" @click="onClick">{{objective.name}}</span>
        </h1>
      </div>
      <div class="objective-value-statement" @click="onClick">
        <div class="objective-value-statement-heading">Value Statement</div>
        <br/>
        <div class="objective-value-statement-content wiki" v-html="objective.value_statement" >
        </div>
      </div>
      <objective-properties v-bind:objectiveProperties="objectiveProperties" v-on:propertiesChanged="updateObjectiveProperties"></objective-properties>
    </div>
    <div class="actions" :class="{'display-off':readOnlyMode}">
      <a class="link_as_button edit primary" @click="$emit('edit')">
        <span class="fa fa-edit"></span>
        EDIT
      </a>
      <a class="link_as_button plan" :class="{'change-plan':planned(), plan: !planned()}" @click="planObjective(planned())">
        <span class="fa fa-calendar-plus-o"></span>
        {{ planned() ? 'CHANGE PLAN' :'PLAN ON TIMELINE'}}
      </a>
      <a class="link_as_button delete" @click="confirmDelete">
        <span class="fa fa-trash"></span>
        DELETE
      </a>
    </div>
    <confirm-delete v-bind:message="deletePopupMessage" v-bind:heading="deletePopupHeading" v-on:delete="deleteObjective"></confirm-delete>
  </div>
</template>

<script>
  import ConfirmDelete from '../ConfirmDelete'
  import ObjectiveProperties from './ObjectiveProperties'
  export default {
    components:{ConfirmDelete, ObjectiveProperties},
    props: {
      objective: {
        type: Object,
        required: true
      }
    },
    data: function(){
      return {
        deletePopupMessage: 'CAUTION! This action is final and irrecoverable. Deleting this objective will completely erase it from your Program.',
        deletePopupHeading: 'Delete Backlog Objective',
        clicks:0,
        timer:null,
        objectiveProperties: this.objective.property_definitions
      }
    },
    computed:{
      readOnlyMode(){
        return this.$store.state.toggles.readOnlyModeEnabled;
      }
    }
    ,
    methods: {
      confirmDelete() {
        this.$modal.show("confirm-delete");
      },
      deleteObjective() {
        this.$store.dispatch('deleteObjective', this.objective.number).then(() => {
          this.$emit('close');
        });
      },
      planObjective(changePlan) {
        let action = changePlan ? 'changeObjectivePlan' : 'planObjective';
        this.$store.dispatch(action, this.objective.number).then(() => {
          this.$emit('close');
        });
      },
      onClick() {
        this.clicks++;
        if(this.clicks === 1) {
          this.timer = setTimeout(()=> {
            this.clicks = 0;
          }, 1000);
        } else{
          clearTimeout(this.timer);
          this.$emit('edit');
          this.clicks = 0;
        }
      },
      updateObjectiveProperties(updatedProperties) {
        this.objectiveProperties = updatedProperties;
        let objectiveData = {};
        Object.assign(objectiveData,this.objective, {property_definitions:this.objectiveProperties});
        this.$store.dispatch('updateCurrentObjective', {objectiveData: objectiveData}).then(() => {});
      },
      planned(){
        return this.objective.status === 'PLANNED'
      }
    }
  }

</script>
<style lang="scss" scoped>

  .view-popup-container {
    height: 100%;
    width: 100%;
    position: absolute;
    padding-left: 15px;
    padding-top: 15px;
    .objective-content {
      height: calc(100% - 15px);
      width: calc(100% - 15px);
      position: inherit;
      .header {
        position: absolute;
        width: 96%;
        height: 40px;
        .number {
          font-weight: bold;
          margin-right: 10px;
          color: black;
        }
        .name {
          color: black;
        }
      }
      .objective-value-statement{
        height: calc(100% - 170px);
        width: 96%;
        top: 40px;
        position: absolute;
        margin-top: 20px;
        overflow-y: auto;
        .objective-value-statement-heading{
          font-size: 16px;
          padding: 5px 0;
          color: #666666;
        }
        .objective-value-statement-content{
          margin-left: 20px;
        }
      }
    }
    .actions {
      position: absolute;
      bottom: 18px;
    }
    .display-off {
      display: none;
    }
  }
</style>

<style lang="scss">
  blockquote {
    font-style: italic;
    padding: 2px 8px 2px 15px;
    margin: 14px 20px;
    border-style: solid;
    border-color: #ccc;
    border-width: 0;
    border-left-width: 5px;
    p {
      margin: 10px 0;
    }
  }
</style>