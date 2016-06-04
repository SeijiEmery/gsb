


// What is a button?
// – Rectangle (usually) with visual appearance that changes with state
//   States: default, mouseover, pressed (breaking down further, mouseover_begin / end, pressed begin/end)
// - Events fired in response to other events
//   (onclick, ontooltip)

// Sliders, otoh, are:
// - Rectangle + slider representation that moves in response to user input, AND model changes
// - Really, it should be a VIEW / adapter to some MODEL / data, plus some minor independent ui state (maybe)

// Labels are usually static, but are really VIEWs and so should be capable of changing as well

// Though with labels we have
// Label => Button (static, mostly ui state); label is a simplified text button w/ only one state
// Label => TextField (VIEW / data adaptor);  label is a simplified text field that's non-interactive
//
// So... yeah, that's interesting. Though we probably won't ever need a combination of both features
// (ie. Button + TextField)

// List view?
// - Just a more complicated view that adapts lists of model data.
// – Definitely MORE complicated, since we need more state (I think...?), like hiding / collapsing
//   items, extending to a tree view, etc., though we could maybe focus on the simpler problem first.

// Taking things further:
// – UI elements with arbitrary shapes (not just rects); user defined intersection algorithms, etc
// - UI elements with arbitrary visual content. It should be possible to embed a gl frame, 2d canvas
//   with arbitrary content, etc., inside ui elements
// - Animation system + state transitions!


//
// Animation system + state transitions
//

// The best way to implement fully featured buttons + clickable things is to represent the button
// / whatever as a state machine, with multiple transitioning states + a time element.
//
// For example, the humble button might have 5 states:
//  – default  (=> start_press, start_mouseover)
//  - pressed:   start_press <--> end_press
//  - mouseover: start_mouse <--> end_mouse 
//
// As a minimum, we should be capable of:
// - textbutton rendered as rounded border + background + text w/ 3 colors
// - start_press: colors w/ +%saturation, +%brightness
// - end_press:   colors w/ lower +%saturation
// - pressed: transition from start_press to end_press using cos interpolation over x interval
// - repeat for mouseover, etc

