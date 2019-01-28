;; SIMPLE SPECULATIVE MARKET SIMULATION
;;
;; This simulation explais how a market bubble can be caused by imprecise pricing models.
;; Assumption 1: Agents have accurate pricing models, which are centered around "market price".
;; Assumption 2: Agents have individual precision, so while one agent may have very precise model and asks/bids a price really close to the market price, others may substantially overbid or underbid.
;; Assumption 3: This is not a continous model, so market is cleared and adjusted at the end of an epoch. Epoch is limited by patience parameter.
;; Assumption 4: Model uses a simplistic clearence mechanism, ehich may bias results. (This is fixed in the next model.)

globals [response_time]

breed [buyers buyer] ;; buyers move randomly and make bids when they meet sellers
breed [sellers seller] ;; sellers sit and sell homes until their patience ends, then starts a new round of simulation, called an epoch

turtles-own [ epsilon ]   ;; error boundary is enique for every buyer and seller

sellers-own [ patience ;; number of ticks seller is willing to sell a home
              price    ;; sellers define price
              bid      ;; best bid received
              total_bids ;; sum of all bids received
              number_of_bids ;; amount of bids received
              avg_bid_to_value ;; avg bid divided by true value
              best_bid_to_value ;; best bid divided by current value
              best_bid_to_true_value]    ;; best bid divided by true value

buyers-own [ patience
             my_bid
             lowest_bid_to_value
             lowest_bid_to_true_value]

;; patches are homes
patches-own [ true_value ;; the intitial value which is true
              value ;; value adjusted by the avg market price change
              cycle ]  ;; remaining patience??

;; this procedures sets up the model
to setup
  clear-all
  
  ask patches [ ;; give value to the patches, color it shades of green
    set cycle init_patience - 1 ;; counter that helpes patches to update value one tick before an epoch end
    set true_value ( random-float 10.0 * 100 + 500 ) ;; true_value is initial price of patches
    set value true_value
    set pcolor green ;; change the world green
  ]

  create-sellers number-of-sellers [
    setxy random-xcor random-ycor ;; place a seller on a random patch
    set color red 
    set shape "house" 
    set size 2 ;; sellers represented by red houses of size 2
    
    set patience init_patience
    set number_of_bids 0
    set epsilon random-float init_epsilon ;; seller's maximum valuation error is a random floating point number greater than or equal to 0 but strictly less than inti_epsilon; uniform distribution
  ]

    create-buyers number-of-buyers [  ;; create the initial buyers
    setxy random-xcor random-ycor ;; place a buyer on a random patch
    set color blue
    set shape "person"
    set size 2 ;; increase their size so they are a little easier to see
    
    set patience init_patience
    set lowest_bid_to_value 2
    set epsilon random-float init_epsilon  ;; similar to sellers, set a buyer' individual errors range for home value estimation
  ]

  set response_time init_patience - 1
  reset-ticks
end

;; make the model run
to go
  if not any? turtles [  ;; if no buyers or sellers, stop
    stop
  ]
  ask turtles [
    sell           ;; sellers sell
    buy            ;; buyers bid
    wiggle         ;; buyers turn a little bit
    move           ;; buyers step forward
  ]
  balance        ;; kill/hatch: shift demand/supply
  price_level    ;; adjusting price level of patches
  tick

  my-update-plots
end

;; seller: 
;; set price, wait until patience runs out,
;; while waiting, lower price gradually if bids lower than the price

to sell
  if breed = sellers [  ;; seller?
    ifelse patience = init_patience [ ;; when patience is full
      if any? sellers-here [ ;; if a patch is occupied by another seller, jump to a different patch
        setxy random-xcor random-ycor
      ]
      set price ( value + (value * ((random-float epsilon * 2) - epsilon) / 100 )) ;; set bid price
      set patience (patience - 1) ;; drop patience
    ]
    [ifelse patience = 0 ;; if patience is over, jump to other home <<<<<<<<<<<<<<< weird
      [setxy random-xcor random-ycor
      set patience init_patience
      set bid 0
      set total_bids 0
      set number_of_bids 0
      set avg_bid_to_value 0
      set best_bid_to_value 0
      set color red
      ]
      [set patience patience - 1 ;; if patience not over, keep selling
        if bid < price [ ;; if bid price is less than listing price, lower listing price
          set price price * 0.9999
        ]
      ]
    ]
  ]
end

;; Buyers walk randomly. When a buyer meet a seller, the buyer bids on seller's house.
;; If the bid is higher than other, it becomes the winnning bid.
;; If a buyer have several winning bids, the buyer choses the one with the lowest (bid / value) ratio.   

to buy
    if breed = buyers [
        set patience patience - 1
        if patience = 0 [
          set color blue
          set patience init_patience
          set my_bid 0
          set lowest_bid_to_value 2
          set lowest_bid_to_true_value 2
        ]

        if any? sellers-here [
        ;; bid = current value +/- error
        set my_bid ( value + (value * ((random-float epsilon * 2) - epsilon) / 100 ))
           let target one-of sellers-here
           ask target [

              ;; calculating the average bid received
              set number_of_bids (number_of_bids + 1)
              set total_bids total_bids + [my_bid] of myself

              ;; dividing the average bid by the CURRENT value
              set avg_bid_to_value (total_bids / (number_of_bids * value))

              ;; if my bid is the highest, change the best bid
              if bid < [my_bid] of myself and price < [my_bid] of myself [
                 set bid [my_bid] of myself

                 ;; calculating best bid to value
                 set best_bid_to_value (bid / value)

                 ;; calculating best bid to TRUE value
                 set best_bid_to_true_value (bid / true_value)
              ]
           ;; orange = homes with bids lower than the asking price
           ;; yellow  = homes with bids higher than the asking price
           ifelse bid < price [set color orange][set color yellow]
           ]
      
           ;; compare if the new winning bid has a lower than current bid_to_value ratio.
           if my_bid = [bid] of target and my_bid / value < lowest_bid_to_value [
              set lowest_bid_to_value my_bid / value
              set lowest_bid_to_true_value my_bid / true_value
              set color yellow
           ]
        ]
  ]
end

to price_level
  ask patches [

    ;; adjust values of all patches one tick ahead of end of an epoch
    set cycle cycle - 1
    if cycle = 0 [

      ;; adjust value of ALL homes by the average bid_to_value ratio of winning buyers
      ;; note that value goes down if average bid_to_value < 1, which means that on average homes has been sold with a discount
      
      if count buyers with [color = yellow] != 0 [
        set value ( value * (sum [ lowest_bid_to_value ] of buyers with [color = yellow]) / (count buyers with [color = yellow]))
        set cycle init_patience]
      ]
    ]

end

to balance 
  
  ;; simple balancer: if price goes up, an additional seller enters the market and one of buyers leaves
  set response_time response_time - 1
  if response_time = 0 [
    set response_time init_patience
    ifelse (count buyers with [color = yellow] != 0) and ((sum [ lowest_bid_to_value ] of buyers with [color = yellow]) / (count buyers with [color = yellow])) < 1 [
      ask n-of 1 buyers [ hatch 1 [ lt 45 fd 1 ]]
      ask n-of 1 sellers [die]
     ]
    [ask n-of 1 sellers [ hatch 1 [ lt 45 fd 1 ]]
       ask n-of 1 buyers [die]
     ]
  ]
end

;; update the plots
to my-update-plots

  set-current-plot-pen "value_to_true_value"
  plot (sum [ value ] of patches) / (sum [ true_value ] of patches)  ;; scaling factor so plot looks nice

end


to wiggle
  ;; buyers changes its heading
  ;; turn right then left, so the average is straight ahead
  if breed = buyers[
    rt random 90
    lt random 90
  ]
end


to move
  ;; buyers procedure, the agent moves one step forward
  if breed = buyers[
    forward 1
  ]
end


;; Arbuzov, M. (2018). Simple Speculative Market Simulation. 
;; research/speculative_market_simulation/speculative_market_simulation.nlogo
;; Economics Department, SJSU, San Jose, CA.

; Copyright 2007 Uri Wilensky.
; See Info tab for full copyright and license.
