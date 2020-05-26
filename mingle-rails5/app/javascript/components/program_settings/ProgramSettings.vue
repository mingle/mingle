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
  <div class="program-settings">
    <message-box :message="message"/>
    <objective-default class="objective-default" v-bind:objectiveType="objectiveType" v-on:updateMessage="updateMessage"></objective-default>
    <side-bar class="settings-side-bar"></side-bar>
  </div>
</template>

<script>
  import ObjectiveDefault from './ObjectiveDefault'
  import SideBar from './SideBar'
  import MessageBox from '../MessageBox'
  import { EventBus } from "../../shared/event_bus"

  export default {
    components: {ObjectiveDefault, MessageBox, SideBar},
    data: function () {
      return {
        objectiveType: this.$store.state.objectiveTypes.objectiveTypes[0],
        message: {}
      }
    },

    methods: {
      updateMessage(message) {
        this.message = message;
      }
    },
    mounted() {
      EventBus.$on('updateMessage', this.updateMessage);
    }
  }
</script>

<style lang="scss" scoped>
  .objective-default {
    width: 75%;
    display: inline-block;
  }
  .settings-side-bar{
    width: 25%;
    margin-right: -15px;
  }
</style>

<style lang="scss">
  body {
    min-width: 1130px;
  }
</style>