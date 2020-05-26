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
    var gameOverInitialized = false;
    function tweetjs() {
        !function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?"http":"https";if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document, "script", "twitter-wjs");
    }

    function tweet(score) {
        message = ($j(document.body).data("show-holiday-fun") && $j(document.body).data("holiday-name") == "Halloween 2016") ? 'I%20found%20the%20Halloween%20treat%20on%20@thatsmingle,%20and%20scored%20'+score+'%20points.' : 'I%20found%20the%20Easter%20Egg%20on%20@thatsmingle%20and%20scored%20'+score+'%20points.';
        return $('<a href="https://twitter.com/intent/tweet?text=' + message +'" class="twitter-mention-button" data-url="false">Tweet to @thatsmingle</a>');
    }

    function initFont() {
        $(document.head).append($('<style>@font-face {font-family: "Press Start 2P"; font-style: normal; font-weight: 400; src: local("Press Start 2P"), local("PressStart2P-Regular"), url(https://themes.googleusercontent.com/static/fonts/pressstart2p/v2/8Lg6LX8-ntOHUQnvQ0E7o2jf3WypfQQP02nP_ZmoBRo.woff) format("woff");} .classic-text {font: 36px "Press Start 2P", cursive;}</style>'));
    }

    function showGameOverPanel(score) {
        var p = $('<div><p>Game Over</p><p style="font-size: 16px">Score: '+score+'</p></div>');
        p.addClass('classic-text');
        p.addClass('game-text');
        p.append(tweet(score));
        $('#greedy_snake').append(p);
        if (gameOverInitialized) {
            twttr.widgets.load();
        } else {
            tweetjs();
        }
        gameOverInitialized = true;
    }

    function createPlayGround() {
        var panel = $('<div id="greedy_snake"><canvas style="width: 100%"></canvas></div>');
        showPlayGround(panel);
        return panel.find('canvas')[0];
    }

    function showPlayGround(panel) {
        InputingContexts.push(new LightboxInputingContext(null, {closeOnBlur: true}));
        InputingContexts.top().update(panel[0]);
    }

    function createSnake(direction, data) {
        var color = '#3FBEEA';
        var directionChanges = [];

        $.each(data, function(i, p) {
            p.color = color;
        });

        var head = function() {
            return data[data.length - 1];
        };
        var nextHead = function() {
            var h = head();
            var p = {color: h.color, x: h.x, y: h.y};
            switch(direction) {
            case 'left':
                p.x--;
                break;
            case 'right':
                p.x++;
                break;
            case 'up':
                p.y++;
                break;
            case 'down':
                p.y--;
                break;
            default:
                break;
            }
            return p;
        };
        var changeDirection = function(d) {
            directionChanges.push(d);
        };
        var keyboardController = function(e){
            switch(e.which){
            case 37:  //left
                if(direction !== 'right'){
                    changeDirection('left');
                }
                break;
            case 38 : //down
                if(direction !== "up"){
                    changeDirection('down');
                }
                break;
            case 39 :  //right
                if(direction !== 'left'){
                    changeDirection('right');
                }
                break;
            case 40 :  //up
                if(direction !== 'down'){
                    changeDirection('up');
                }
                break;
            default:
                break;
            }
        };
        var swipeleftController = function(e) {
            if(direction === 'left') {
                changeDirection('down');
            } else if (direction === 'right') {
                changeDirection('up');
            } else if (direction === 'up') {
                changeDirection('left');
            } else {
                changeDirection('right');
            }
        };
        var swiperightController = function(e) {
            if(direction === 'left') {
                changeDirection('up');
            } else if (direction === 'right') {
                changeDirection('down');
            } else if (direction === 'up') {
                changeDirection('right');
            } else {
                changeDirection('left');
            }
        };

        return {
            head: head,
            eat: function(f) {
                var h = head();
                if (f.x === h.x && f.y === h.y) {
                    data.push({ x : f.x, y : f.y, color: color });
                    return true;
                } else {
                    return false;
                }
            },

            move: function() {
                var h = nextHead();
                data.splice(0, 1);
                data.push(h);
            },

            updateDirection: function() {
                var newDirection = directionChanges.splice(0, 1)[0];
                if (newDirection) {
                    direction = newDirection;
                }
            },

            hitSelf: function() {
                var h = head();
                for(var i=0; i<data.length - 1; i++) {
                    if(data[i].x === h.x && data[i].y === h.y) {
                        return true;
                    }
                }
                return false;
            },

            paint: function(board) {
                $.each(data, function(i, d) {
                    board.paintDot(d);
                });
            },

            unbindControls: function() {
                $(document).unbind("keydown", keyboardController);
                $(window).unbind("swipeleft", swipeleftController);
                $(window).unbind("swiperight", swiperightController);
            },

            bindControls: function() {
                $(document).bind("keydown", keyboardController);
                $(window).bind("swipeleft", swipeleftController);
                $(window).bind("swiperight", swiperightController);
            }
        };
    }

    function hd(canvas, context) {
        var devicePixelRatio = window.devicePixelRatio || 1;
        var backingStoreRatio = context.webkitBackingStorePixelRatio ||
            context.mozBackingStorePixelRatio ||
            context.msBackingStorePixelRatio ||
            context.oBackingStorePixelRatio ||
            context.backingStorePixelRatio || 1;

        var ratio = devicePixelRatio / backingStoreRatio;

        if (devicePixelRatio !== backingStoreRatio) {
            canvas.width = canvas.width * ratio;
            canvas.height = canvas.height * ratio;
            context.scale(ratio, ratio);
        }
        return ratio;
    }

    function createBoard() {
        var color = 'white';
        var canvas = createPlayGround();
        var context = canvas.getContext('2d');
        var cwidth = canvas.width;
        var cheight = canvas.height;
        var dot_width = 10;
        var width = cwidth / dot_width;
        var height = cheight / dot_width;

        var ratio = hd(canvas, context);

        function egg(p) {
          var yellow = "#F8E71C";
          var purple = "#BD10E0";
          context.fillStyle = yellow;
          context.fillRect(p.x * dot_width + 4, p.y * dot_width, 2, 1);
          context.fillRect(p.x * dot_width + 3, p.y * dot_width + 1, 4, 1);
          context.fillRect(p.x * dot_width + 2, p.y * dot_width + 2, 6, 1);
          context.fillRect(p.x * dot_width + 1, p.y * dot_width + 3, 8, 5);
          context.fillRect(p.x * dot_width + 2, p.y * dot_width + 8, 6, 1);
          context.fillRect(p.x * dot_width + 3, p.y * dot_width + 9, 4, 1);

          context.fillStyle = purple;
          for (var i=1; i<9; i++) {
            context.fillRect(p.x * dot_width + i, p.y * dot_width + 6 - i%2, 1, 1);
          }
        }

        function flower0(p) {
          var yellow = "#F8E71C";
          var green = "#417505";
          var purple = "#CF8DDC";

          context.fillStyle = yellow;
          context.fillRect(p.x * dot_width + 4, p.y * dot_width + 3, 1, 1);

          context.fillStyle = purple;
          context.fillRect(p.x * dot_width + 4, p.y * dot_width, 1, 1);

          context.fillRect(p.x * dot_width + 2, p.y * dot_width + 1, 1, 1);
          context.fillRect(p.x * dot_width + 6, p.y * dot_width + 1, 1, 1);

          context.fillRect(p.x * dot_width + 1, p.y * dot_width + 2, 1, 3);
          context.fillRect(p.x * dot_width + 7, p.y * dot_width + 2, 1, 3);

          context.fillRect(p.x * dot_width + 2, p.y * dot_width + 5, 1, 1);
          context.fillRect(p.x * dot_width + 6, p.y * dot_width + 5, 1, 1);

          context.fillStyle = green;
          context.fillRect(p.x * dot_width + 1, p.y * dot_width + 7, 1, 1);
          context.fillRect(p.x * dot_width + 7, p.y * dot_width + 7, 1, 1);
          context.fillRect(p.x * dot_width + 2, p.y * dot_width + 8, 1, 1);
          context.fillRect(p.x * dot_width + 6, p.y * dot_width + 8, 1, 1);

          context.fillRect(p.x * dot_width + 3, p.y * dot_width + 9, 3, 1);
          context.fillRect(p.x * dot_width + 4, p.y * dot_width + 7, 1, 2);
        }

        function flower1(p) {
          var yellow = "#F8E71C";
          var green = "#417505";
          var red = "#E56F97";
          context.fillStyle = yellow;
          context.fillRect(p.x * dot_width + 4, p.y * dot_width + 3, 1, 1);

          context.fillStyle = red;
          context.fillRect(p.x * dot_width + 3, p.y * dot_width, 3, 1);

          context.fillRect(p.x * dot_width + 0, p.y * dot_width + 3, 1, 1);
          context.fillRect(p.x * dot_width + 8, p.y * dot_width + 3, 1, 1);

          context.fillRect(p.x * dot_width + 1, p.y * dot_width + 2, 1, 3);
          context.fillRect(p.x * dot_width + 7, p.y * dot_width + 2, 1, 3);

          context.fillRect(p.x * dot_width + 3, p.y * dot_width + 6, 3, 1);

          context.fillStyle = green;
          context.fillRect(p.x * dot_width + 1, p.y * dot_width + 7, 1, 1);
          context.fillRect(p.x * dot_width + 7, p.y * dot_width + 7, 1, 1);
          context.fillRect(p.x * dot_width + 2, p.y * dot_width + 8, 1, 1);
          context.fillRect(p.x * dot_width + 6, p.y * dot_width + 8, 1, 1);

          context.fillRect(p.x * dot_width + 3, p.y * dot_width + 9, 3, 1);
          context.fillRect(p.x * dot_width + 4, p.y * dot_width + 7, 1, 2);
        }

        function holidayTheme() {
            return ($(document.body).data("show-holiday-fun") && $(document.body).data("holiday-name") == "Halloween 2016") ? new MingleUI.snake.Halloween(context, dot_width) : null;
        }

        return {
            paintFood: function(p) {
              holiday = holidayTheme();
              switch(p.type) {
              case 0:
                holiday ? holiday.icon(p) : flower0(p);
                break;
              case 1:
                holiday ? holiday.icon(p) : flower1(p);
                break;
              case 2:
                holiday ? holiday.icon(p) : egg(p);
                break;
              case 3:
              case 4:
              case 5:
              case 6:
                holiday ? holiday.icon(p) : egg(p);
                break;
              default:
                holiday ? holiday.icon(p) : egg(p);
              }
            },
            paintDot: function(p) {
                context.fillStyle = p.color;
                context.fillRect(p.x * dot_width, p.y * dot_width, dot_width, dot_width);
            },
            paint: function() {
                context.fillStyle = color;
                context.fillRect(0, 0, cwidth, cheight);
            },
            randomDot: function() {
                x = 2+Math.round(Math.random() * (width - 5));
                y = 2+Math.round(Math.random() * (height - 5));
                return {x: x, y: y};
            },
            onBorder: function(p) {
                return p.x === -1 || p.y === -1 || p.x === width || p.y === height;
            }
        };
    }

    function createFood(dot) {
        var max = $(document.body).data("show-holiday-fun") ? 8 : 3;

        return {
            type: Math.round(Math.random() * (4 * max)) % max,
            x: dot.x,
            y: dot.y
        };
    }

    function initSnakeData() {
        var o = [];
        for (var i=0; i<10; i++) {
            o.push({x: i, y: 5});
        }
        return o;
    }

    function play() {
        var directions = ['left','right','up','down'];
        var startAt = new Date();
        var board = createBoard();
        var snake = createSnake('right', initSnakeData());
        var food = createFood(board.randomDot());
        var runHandler;
        var speed = 110;
        var velocity = 1;
        var score = 0;

        var updateSpeed = function() {
            speed = speed - velocity;
            if(runHandler) {
                clearInterval(runHandler);
                runHandler = null;
            }
            runHandler = setInterval(run, speed);
        };

        var paint = function() {
            board.paint();
            board.paintFood(food);
            snake.paint(board);
        };
        var gameTime = function() {
            return Math.round((new Date() - startAt)/1000);
        };

        var run = function(){
            snake.move();
            if (snake.hitSelf() || board.onBorder(snake.head())) {
                paint();
                snake.unbindControls();
                clearInterval(runHandler);
                showGameOverPanel(score);
                trace({type: 'over', game_score: score, game_time: gameTime()});
                return;
            }

            if (snake.eat(food)) {
                score++;
                food = createFood(board.randomDot());
                updateSpeed();
            }
            snake.updateDirection();
            paint();
        };

        var gameStart = function(){
            score = 0;
            snake.bindControls();

            paint();
            countdown(updateSpeed, 3);
        };

        gameStart();
        trace({type: 'start'});
    }

    function trace(event) {
      mixpanelTrack('easter_egg_greedy_snake', event);
    }

    function countdown(f, t) {
        if (t === 0) {
            f();
        } else {
            var p = $('<div><p style="font-size: 80px">'+t+'</p></div>');
            p.addClass('classic-text');
            p.addClass('game-text');
            $('#greedy_snake').append(p);
            setTimeout(function() {
                p.remove();
                countdown(f, t - 1);
            }, 1000);
        }
    }

    $(document).ready(function() {
        var egg = $('<div></div>');
        $(document.body).append(egg);
        egg.addClass('mingle-icon-easter-egg');
        egg.addClass('fa');
        egg.on({
            mouseenter: function(e) {
                e.stopPropagation();
                var img = $(".holiday img");
                img.attr("src", img.data("hover-src"));
            },
            mouseleave: function(e) {
                e.stopPropagation();
                var img = $(".holiday img");
                img.attr("src", img.data("src"));
            }
        });
        egg.click(function() {
            if ($(document.body).data("show-holiday-fun") && $(document.body).data("hover-logo-link")) {
                window.open($(document.body).data("hover-logo-link"));
            } else {
                initFont();
                play();
            }
        });
    });
})(jQuery);
