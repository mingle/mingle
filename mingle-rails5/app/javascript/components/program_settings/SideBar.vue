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
  <div class="side-bar">
    <div class="side-bar-option">
      <div class="option" @click="togglePanel">
        <span class="option-title">CONFIGURE PROPERTIES</span>
        <span class="fa fa-angle-up" v-if="openPanel"></span>
        <span class="fa fa-angle-down" v-else></span>
      </div>
      <master-property-set v-if="openPanel" ></master-property-set>
    </div>
  </div>
</template>

<script>
  import MasterPropertySet from "./MasterPropertySet";
  export default {
    name: "SideBar",
    components: {MasterPropertySet},
    data: function () {
      return {
        openPanel: true
      }
    },
    methods: {
      togglePanel() {
        this.openPanel = !this.openPanel;
      }
    }
  }
</script>

<style lang="scss" scoped>
  .side-bar {
    display: inline-block;
    float: right;
    border: 1px solid #ccc;
    .side-bar-option {
      .option{
        cursor: pointer;
        padding: 5px;
        background-color: #3fbeea;
        .option-title{
          font-size: 14px;
          font-weight: 300;
          color: white;
          display: inline-block;
          width: 85%;
          line-height: 28px;
          vertical-align: top;
        }
        .fa {
          font-size: 28px;
          color: white;
          width: 10%;
          text-align: right;
        }
      }
    }
  }
</style>