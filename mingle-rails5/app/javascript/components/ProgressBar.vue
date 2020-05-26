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
  <span class="linear-progress-bar" :style="getStyle"></span>
</template>

<script>
  export default {
    name: "progress-bar",
    props: {
      boxstyle: {
        default() {
          return {};
        }
      },
      target:{
        required:true,
        type:String
      }
    },
    data() {
      return {
        defaultStyle: {
          position: 'absolute',
          float: 'left',
          left: 0,
          top: 0
        }
      }
    },
    computed: {
      getStyle() {
        let target = document.querySelector(this.target);
        return {
          width: (`${target.getWidth()}px`),
          position: (this.boxstyle.position || this.defaultStyle.position),
          float: (this.boxstyle.float || this.defaultStyle.float),
          top: `${(target.positionedOffset().top || this.defaultStyle.top)}px`,
          left: `${(target.positionedOffset().left || this.defaultStyle.left)}px`,
          margin:target.getStyle('margin-top'),
          padding:target.getStyle('padding-top')
        }
      }
    }
  }
</script>

<style scoped>
  .linear-progress-bar {
    height: 3px;
    width: 100%;
    float: left;
    opacity: 0.5;
    background-image: linear-gradient(45deg, #CEE83A, #3AFE6D);
    animation: hue 1s infinite linear;
  }

  @keyframes hue {
    from {
      -webkit-filter: hue-rotate(0deg);
      filter: hue-rotate(0deg);
    }
    to {
      -webkit-filter: hue-rotate(-360deg);
      filter: hue-rotate(-360deg);
    }
  }
</style>