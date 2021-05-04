extensions [ gis ]
breed [goats goat]
goats-own [ herd_size leader prob_death crossed ]
patches-own [resistance flow] ;; resistance: difficulty of terrain / probability of death, flow: likelihood of foot traffic from pinchpoint analysis
;; globals: time_of_day: day/night, deaths: death counter, N: initial population size, crosses: number of bridge crossings
globals [ time_of_day deaths N crossings left_habitat
  resistance-data flow-data
]

to setup
  clear-all
  resize-world 0 143 0 153

  ;; initialize globals
  set time_of_day "day"
  set deaths 0
  set N 0
  set crossings 0
  set left_habitat 0

  ;; gis data
  set resistance-data gis:load-dataset "NetLogoInput/pp1_resistance_noriver.asc"
  set flow-data gis:load-dataset "NetLogoInput/pp1_flow.asc"

  ;; format world
  ask patches [ load_world ]
  build_bridge
  set-default-shape goats "cow"
  init_goats
  reset-ticks
end

;; currently time_of_day not implemented
to go
  if not any? goats or ticks > 700 [ stop ]
  if land_bridge = true [
    update_flow ]
  ask goats
  [ move
    death ]
  tick ; one step = one half day
end

;; patch procedure
to load_world

  gis:set-world-envelope gis:raster-world-envelope resistance-data 0 0

  ;; load data into resistance and flow patch variables
  gis:apply-raster resistance-data resistance
  gis:apply-raster flow-data flow

  ;; color by resistance or flow
  (ifelse (color_by = 1)[
    let min-resistance gis:minimum-of resistance-data
    let max-resistance gis:maximum-of resistance-data

    if (resistance <= 0) or (resistance >= 0)
      [ set pcolor scale-color red resistance max-resistance min-resistance ]
    ] ;; else condition
    [
      let min-flow gis:minimum-of flow-data
      let max-flow gis:maximum-of flow-data

      if (flow <= 0) or (flow >= 0)
        [ set pcolor scale-color blue flow max-flow min-flow ]
  ] )
end

;; patch procedure
to build_bridge
  if land_bridge = true [
   ask (patch-set
      ;; two patch wide bridge
      patch 70 75 patch 70 76 patch 70 77 patch 70 78 patch 70 79 patch 70 80 patch 70 81 patch 70 82 patch 70 83 patch 70 84 patch 70 85 patch 70 86 patch 70 87 patch 70 88 patch 70 89 patch 70 90
      patch 71 75 patch 71 76 patch 71 77 patch 71 78 patch 71 79 patch 71 80 patch 71 81 patch 71 82 patch 71 83 patch 71 84 patch 71 85 patch 71 86 patch 71 87 patch 71 88 patch 71 89 patch 71 90
      )  [
      set pcolor 74
      set resistance 0
      ; set flow according to logistic growth with carrying capacity = .9
      set flow 100
  ]
  ask (patch-set
      ;; fence to direct goats
      patch 60 75 patch 61 75 patch 62 75 patch 63 75 patch 64 75 patch 65 75 patch 66 75 patch 67 75 patch 68 75 patch 69 75
      patch 72 75 patch 73 75 patch 74 75 patch 75 75 patch 76 75 patch 77 75 patch 78 75 patch 79 75 patch 80 75 patch 81 75
      patch 60 90 patch 61 90 patch 62 90 patch 63 90 patch 64 90 patch 65 90 patch 66 90 patch 67 90 patch 68 90 patch 69 90
      patch 72 90 patch 73 90 patch 74 90 patch 75 90 patch 76 90 patch 77 90 patch 78 90 patch 79 90 patch 80 90 patch 81 90
      patch 69 75 patch 69 76 patch 69 77 patch 69 78 patch 69 79 patch 69 80 patch 69 81 patch 69 82 patch 69 83 patch 69 84 patch 69 85 patch 69 86 patch 69 87 patch 69 88 patch 69 89 patch 69 90
      patch 72 75 patch 72 76 patch 72 77 patch 72 78 patch 72 79 patch 72 80 patch 72 81 patch 72 82 patch 72 83 patch 72 84 patch 72 85 patch 72 86 patch 72 87 patch 72 88 patch 72 89 patch 72 90
    ) [
      set pcolor 2
      set flow 0
    ]
  ]
end

to init_goats
  ; initialize leaders and give them a herd
  create-goats number [
    set color 7
    set size 1.5
    ;; initialize in random position - relocate with scaled probability based on flow
    setxy random-xcor random-ycor
    while [ [ flow ] of patch-here < random 1000 or pycor > 60 ] [ setxy random-xcor random-ycor  ]
    set leader true
    set crossed false

    ; follower goats
    hatch random 15 [
      set color 4
      set leader false
      set crossed false
    ]

    create-links-to other goats-here
    set N N + count goats-here

  ask goats-here [
    set herd_size goats-here
      set size 4 * count herd_size / 15
  ] ]
  ;; think more about this: do we want herd to be independent agents? How many from herd die? Should they be spread across multiple patches?
  ;; What happens if their leader dies?

end

;; Patch procedure - update bridge flow
to update_flow
  let max_flow 500
  ask patches [
    if pcolor = 74 [
      set flow ( flow + .01 * ((max_flow - flow) / max_flow) * flow)
  ] ]
end

to move  ;; goat procedure
  ;; leader goats - informed random walk with probability of walking on that patch scaled linearly to flow
  ; high flow = high foot traffic
  (ifelse leader = true [
    ;; prevent getting stuck on walls - bounce off side walls
    (ifelse ( abs pxcor = max-pxcor or abs pxcor = min-pxcor )
       [ set heading (- heading) ]
    ( abs pycor = min-pycor )
       [ set heading (180 - heading) ]
    ;; otherwise move according to flow
    [ let temp -1
      set heading 0
        ;; becomes false quickly when temp is large -> loop terminates and sets on that heading
        while [ random 1000 + 1 > temp ][
      rt random 50
      lt random 50
      ifelse patch-ahead 1 = nobody [ set temp -1 ]
      [ set temp [ flow ] of patch-ahead 1 ]
      ] ] )
    fd 1
    ]
    ;; followers follow their leader herd
  leader = false [
      move-to one-of link-neighbors
    ]
    )
  if ([pcolor] of patch-here = 74 and crossed = false and ticks > 10) [
    set crossings crossings + 1
    set crossed true]
  ;; turtles leave habitat to the north
  if abs pycor = max-pycor [
    leave_habitat
  ]
end

to death     ;; goat procedure
  ;; death has linear relationship with resistance -> max 95% chance of death in day, 80% at night
  (ifelse ([ resistance ] of patch-here) > 700 [
    let K 0.14
    let A (K - 0.46) / 0.46
    set prob_death ( (K / ( 1 + A * exp (- K * count goats-here ) ) ) / 10 )
  ] [
    set prob_death .0000001
    ] )

  if random-float 1 <= prob_death [
    ;; reassign leader
    if leader = true [
      if count link-neighbors > 0 [
        let temp link-neighbors
        ask one-of link-neighbors [
          let id self
          set leader true
          set color 7
          ;set size 1
          ask temp [
            if id != self [
              create-link-from id ] ]
        ]
    ] ]
    set deaths deaths + 1
    die ]
end

to leave_habitat     ;; goat procedure - does not increase death toll
  set left_habitat left_habitat + 1
  if leader = true [
      if count link-neighbors > 0 [
        let temp link-neighbors
        ask one-of link-neighbors [
          let id self
          set leader true
          set color 7
          ;set size 1
          ask temp [
            if id != self [
              create-link-from id ] ]
        ]
    ] ]
  die
end
@#$#@#$#@
GRAPHICS-WINDOW
313
13
839
576
-1
-1
3.6
1
10
1
1
1
0
0
0
1
0
143
0
153
1
1
1
ticks
30.0

BUTTON
58
83
113
116
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
123
83
178
116
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
35
42
261
75
number
number
0.0
50
50.0
1.0
1
NIL
HORIZONTAL

BUTTON
187
84
250
117
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
46
404
246
554
Mortality
time
mortality rate
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot deaths / N"

CHOOSER
26
132
164
177
color_by
color_by
1 2
0

TEXTBOX
172
142
322
170
1 = color by resistance\n2 = color by flow
11
0.0
1

SWITCH
43
192
163
225
land_bridge
land_bridge
1
1
-1000

MONITOR
188
187
252
232
NIL
crossings
0
1
11

PLOT
45
243
245
393
left habitat
time
proportion
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot left_habitat / N"

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rabbit
false
0
Circle -7500403 true true 76 150 148
Polygon -7500403 true true 176 164 222 113 238 56 230 0 193 38 176 91
Polygon -7500403 true true 124 164 78 113 62 56 70 0 107 38 124 91

sheep 2
false
0
Polygon -7500403 true true 209 183 194 198 179 198 164 183 164 174 149 183 89 183 74 168 59 198 44 198 29 185 43 151 28 121 44 91 59 80 89 80 164 95 194 80 254 65 269 80 284 125 269 140 239 125 224 153 209 168
Rectangle -7500403 true true 180 195 195 225
Rectangle -7500403 true true 45 195 60 225
Rectangle -16777216 true false 180 225 195 240
Rectangle -16777216 true false 45 225 60 240
Polygon -7500403 true true 245 60 250 72 240 78 225 63 230 51
Polygon -7500403 true true 25 72 40 80 42 98 22 91
Line -16777216 false 270 137 251 122
Line -16777216 false 266 90 254 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="land_bridge" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>ticks</metric>
    <metric>crossings</metric>
    <metric>N</metric>
    <metric>deaths</metric>
    <metric>left_habitat</metric>
    <enumeratedValueSet variable="number">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="land_bridge">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color_by">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
