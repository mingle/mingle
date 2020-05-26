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
  <div class="master-property-set">
    <h4 class="title">Master Property set</h4>
    <ol class="properties">
      <li v-for="property in properties">
        <span class="property-name" :title="property.description">{{property.name}}</span>
        <span class="icons">
          <span class="fa fa-pencil" @click="openEditPopUp(property)"></span>
          <span class="fa fa-trash"></span>
        </span>
        <span class="add">Added</span>
      </li>
    </ol>
    <p class="create-property" @click="openCreatePopUp">Create new property</p>
    <modals-container></modals-container>
  </div>
</template>
<modals-container/>


<script>
  import CreatePropertyPopUp from "./CreatePropertyPopUp";
  export default {
    name: "MasterPropertySet",
    components: {CreatePropertyPopUp},
    data: function () {
      return {
        properties: this.$store.state.programProperties.properties
      }
    },
    methods:{
      openCreatePopUp()  {
        this.$modal.show(CreatePropertyPopUp, {heading: 'Create New Property', mode: 'CREATE'}, {height :400, width:550, classes: ['create-property-modal'], clickToClose: false});
      },
      openEditPopUp(property) {
        this.$modal.show(CreatePropertyPopUp, {heading: 'Edit Property', mode: 'EDIT', currentPropertyData: property}, {height :270, width:550, classes: ['edit-property-modal'], clickToClose: false});
      }
    }
  }
</script>

<style lang="scss" scoped>
.master-property-set {
  padding-left: 10px;
  padding-top: 10px;

  ol {
    list-style-type: none;
    margin: 10px 10px 10px 0;
    max-height: 457px;
    overflow-y: scroll;

    li:nth-child(odd) {
      background: #f3f3f3;
    }

    li:nth-child(even) {
      background: white;
    }
    li {
      font-size: 14px;
      padding: 5px;
      margin: 0;
      .icons {
        display: inline-block;
        width: 20%;
      }
      .property-name {
        word-wrap: break-word;
        cursor: default;
        width: 60%;
        display: inline-block;
        line-height: 20px;
        vertical-align: top;
      }
      .add{
        display: inline-block;
        text-align: right;
        width: 15%;
        color: #CCC;
      }
      .fa {
        color: #CCC;
        font-size: 20px;
        padding-left: 5%;
        &.fa-pencil{
          cursor: pointer;
          color: #999;
        }
      }
    }
  }

  p.create-property {
    color: #3fbeea;
    font-size: 14px;
    text-align: center;
    text-decoration: underline;
    cursor: pointer;
    margin-bottom: 10px;
  }

  .title {
    color: #3fbeea;
    margin: 0;
    padding: 0;
    font-weight: 400;
  }
}
</style>