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
(function($) {
  function Bat(atX, atY) {
    var random = Math.random,
      doc = document,
      win = window,
      img = doc.createElement('img'),
      div = doc.createElement('div'),
      divStyle = div.style;
      divStyle.zIndex = 666666666;

    function randomCoordinate(previousMove, upper) {
      var plusOrMinus200 = ((random() - 0.5) * 400);
      var coord = Math.min(previousMove + plusOrMinus200, upper - 50); // move no more than most of the width
      return Math.max(coord, 50); // but move at least 50
    }

    function plusOrMinus200() {
      return ((random() - 0.5) * 400);
    }


    var priorX = plusOrMinus200() * random(), priorY = plusOrMinus200() * random();
    divStyle.position = "fixed";
    divStyle.left = atX + "px";
    divStyle.top = atY + "px";

    img.style.opacity = 0;
    img.style.transition = img.style.webkitTransition = 'opacity 0.25s linear';
    img.src = 'data:image/gif;base64,R0lGODlhMAAwAJECAAAAAEJCQv///////yH/C05FVFNDQVBFMi4wAwEAAAAh+QQJAQACACwAAAAAMAAwAAACdpSPqcvtD6NcYNpbr4Z5ewV0UvhRohOe5UE+6cq0carCgpzQuM3ut16zvRBAH+/XKQ6PvaQyCFs+mbnWlEq0FrGi15XZJSmxP8OTRj4DyWY1lKdmV8fyLL3eXOPn6D3f6BcoOEhYaHiImKi4yNjo+AgZKTl5WAAAIfkECQEAAgAsAAAAADAAMAAAAnyUj6nL7Q+jdCDWicF9G1vdeWICao05ciUVpkrZIqjLwCdI16s+5wfck+F8JOBiR/zZZAJk0mAsDp/KIHRKvVqb2KxTu/Vdvt/nGFs2V5Bpta3tBcKp8m5WWL/z5PpbtH/0B/iyNGh4iJiouMjY6PgIGSk5SVlpeYmZqVkAACH5BAkBAAIALAAAAAAwADAAAAJhlI+py+0Po5y02ouz3rz7D4biSJbmiabq6gCs4B5AvM7GTKv4buby7vsAbT9gZ4h0JYmZpXO4YEKeVCk0QkVUlw+uYovE8ibgaVBSLm1Pa3W194rL5/S6/Y7P6/f8vp9SAAAh+QQJAQACACwAAAAAMAAwAAACZZSPqcvtD6OctNqLs968+w+G4kiW5omm6ooALeCusAHHclyzQs3rOz9jAXuqIRFlPJ6SQWRSaIQOpUBqtfjEZpfMJqmrHIFtpbGze2ZywWu0aUwWEbfiZvQdD4sXuWUj7gPos1EAACH5BAkBAAIALAAAAAAwADAAAAJrlI+py+0Po5y02ouz3rz7D4ZiCIxUaU4Amjrr+rDg+7ojXTdyh+e7kPP0egjabGg0EIVImHLJa6KaUam1aqVynNNsUvPTQjO/J84cFA3RzlaJO2495TF63Y7P6/f8vv8PGCg4SFhoeIg4UQAAIfkEBQEAAgAsAAAAADAAMAAAAnaUj6nL7Q+jXGDaW6+GeXsFdFL4UaITnuVBPunKtHGqwoKc0LjN7rdes70QQB/v1ykOj72kMghbPpm51pRKtBaxoteV2SUpsT/Dk0Y+A8lmNZSnZlfH8iy93lzj5+g93+gXKDhIWGh4iJiouMjY6PgIGSk5eVgAADs=';

    function randomCoord2(priorChange) {
      var currentX = parseInt(divStyle.left, 10);
      var currentY = parseInt(divStyle.top, 10);

      var changeX = priorChange.x + plusOrMinus200();
      var changeY = priorChange.y + plusOrMinus200();

      // limit movement to within viewable space
      if (changeX < 0) {
        changeX = Math.max(changeX, 0 - currentX);
      } else {
        changeX = Math.min(changeX, (win.innerWidth - img.offsetWidth) - currentX);
      }

      if (changeY < 0) {
        changeY = Math.max(changeY, 0 - currentY);
      } else {
        changeY = Math.min(changeY, (win.innerHeight - img.offsetHeight) - currentY);
      }

      return {x: changeX, y: changeY};
    }

    div.appendChild(img);

    var self = this;
    this.times = 0;
    this.timer = null;

    function randomMovement() {
      var dxy = randomCoord2({x: priorX, y: priorY});
      var dx = dxy.x, dy = dxy.y,
        time = self.times === 0 ? 400 : 5 * Math.sqrt((priorX - dx) * (priorX - dx) + (priorY - dy) * (priorY - dy));

      divStyle.transition = divStyle.webkitTransition = time / 1000 + 's linear';
      divStyle.transform = divStyle.webkitTransform = 'translate(' + dx + 'px,' + dy + 'px)';

      img.style.transform = img.style.webkitTransform = (priorX > dx) ? '' : 'scaleX(-1)';
      priorX = dx;
      priorY = dy;

      self.times += 1;

      if (self.times > 5) {
        self.destroy();
      } else {
        self.timer = setTimeout(randomMovement, time); // if we limit this, we can stop bats
      }
    }

    this.destroy = function destroy() {
      self.timer !== null && clearTimeout(self.timer);
      img.style.opacity = 0;
      setTimeout(function () {
        doc.body.removeChild(div);
      }, 275);
    };

    this.start = function start() {
      doc.body.appendChild(div);

      setTimeout(function () {
        img.style.opacity = 1;
        randomMovement();
      }, 0);
    };
  }

  $.fn.createBats = function createBats() {
    var coordsToDocument = $(this).offset();
    var coordsToWindow = {x: coordsToDocument.left - $(document).scrollLeft(), y: coordsToDocument.top - $(document).scrollTop()};

    var num = Math.floor((Math.random() * 10) % 5);
    num = Math.max(1, num);

    for (var i = 0; i < num; i++)
      new Bat(coordsToWindow.x, coordsToWindow.y).start();
  };
})(jQuery);
