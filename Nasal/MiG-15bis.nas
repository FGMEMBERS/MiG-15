autotakeoff = func {

# The ato_start function is only executed once but the ato_mode and
# ato_spddep functions will re-schedule themselves until
# /autopilot/locks/auto-take-off is disabled.

#  print("autotakeoff called");
  if(getprop("/autopilot/locks/auto-take-off") == "enabled") {
    ato_start();      # Initialisation.
    ato_main();       # Main loop.
  }
}
#--------------------------------------------------------------------
ato_start = func {

  if(getprop("/autopilot/settings/target-gr-heading-deg") < -999) {

    setprop("/controls/flight/flaps", 0.0);
    setprop("/controls/flight/spoilers", 0.0);
    setprop("/controls/gear/brake-left", 0.0);
    setprop("/controls/gear/brake-right", 0.0);
    setprop("/controls/gear/brake-parking", 0.0);

    hdgdeg = getprop("/orientation/heading-deg");
    tgt_gr_pitch_deg= getprop("/autopilot/settings/target-gr-pitch-deg");
    setprop("/autopilot/settings/target-gr-heading-deg", hdgdeg);
    setprop("/autopilot/settings/true-heading-deg", hdgdeg);
    setprop("/autopilot/settings/target-speed-kt", 350);
    setprop("/autopilot/internal/target-pitch-deg-unfiltered", tgt_gr_pitch_deg);
    setprop("/autopilot/locks/speed", "speed-with-throttle");
    setprop("/autopilot/locks/rudder-control", "gr-rudder-hold");
    setprop("/autopilot/locks/altitude", "take-off");
    setprop("/autopilot/internal/target-roll-deg-unfiltered", 0);
    setprop("/autopilot/locks/auto-take-off", "engaged");
  }
}
#--------------------------------------------------------------------
ato_main = func {

  as_kt= getprop("/velocities/airspeed-kt");
  tgt_gr_rot_spd_kt= getprop("/autopilot/settings/target-gr-rot-spd-kt");
  tgt_to_p_deg= getprop("/autopilot/settings/target-to-pitch-deg");

  if(as_kt < tgt_gr_rot_spd_kt) {
    # Do nothing
  } else {
    if(as_kt < 145) {
      interpolate("/controls/flight/elevator", -1.0, 2);
      interpolate("/autopilot/internal/target-pitch-deg-unfiltered", tgt_to_p_deg, 2);
      setprop("/autopilot/locks/heading", "wing-leveler");
    } else {
      if(as_kt < 160) {
        interpolate("/controls/flight/elevator", 0.0, 15);
      } else {
        if(as_kt < 170) {
          setprop("/controls/gear/gear-down", "false");
          setprop("/autopilot/locks/rudder-control", "");
          setprop("/controls/flight/flaps", 0.0);
          interpolate("/controls/flight/rudder", 0, 10);
        } else {
          if(as_kt > 200) {
            setprop("/controls/flight/flaps", 0.0);
            setprop("/autopilot/locks/heading", "true-heading-hold");
            setprop("/autopilot/locks/speed", "mach-with-throttle");
            setprop("/autopilot/locks/altitude", "mach-climb");
            setprop("/autopilot/locks/auto-take-off", "disabled");
            setprop("/autopilot/locks/auto-landing", "enabled");
          }
        }
      }
    }
  }

  # Re-schedule the next loop
  if(getprop("/autopilot/locks/auto-take-off") == "engaged") {
    settimer(ato_main, 0.2);
  }
}
#--------------------------------------------------------------------
autoland = func {
  if(getprop("/autopilot/locks/auto-landing") == "enabled") {
    atl_start();      # Initialisation.
    atl_main();       # Main loop.
  }
}
#--------------------------------------------------------------------
atl_start = func {
  setprop("/autopilot/locks/auto-landing", "engaged");
}
#--------------------------------------------------------------------

atl_main = func {
  # Get the agl, kias, vfps & heading.
  agl = getprop("/position/altitude-agl-ft");
  hdgdeg = getprop("/orientation/heading-deg");

  if(agl > 200) {
    # Glide Slope phase.
    atl_heading();
    atl_spddep();
    atl_glideslope();
  } else {
    # Touch Down Phase
    atl_touchdown();
  }
  # Re-schedule the next loop if the Landing function is enabled.
  if(getprop("/autopilot/locks/auto-landing") == "engaged") {
    settimer(atl_main, 0.2);
  }
}
#--------------------------------------------------------------------
atl_glideslope= func {
  # This script handles the Glide Slope phase
  ap_alt_lock= getprop("/autopilot/locks/altitude");
  gsvfps = getprop("/instrumentation/nav[0]/gs-rate-of-climb");
  curr_vfps = getprop("/velocities/vertical-speed-fps");

  if(ap_alt_lock != "vfps-hold") {
    setprop("/autopilot/settings/target-climb-rate-fps", curr_vfps);
    interpolate("/autopilot/settings/target-climb-rate-fps", gsvfps, 4);
    setprop("/autopilot/locks/altitude", "vfps-hold");
  } else {
    interpolate("/autopilot/settings/target-climb-rate-fps", gsvfps, 1);
  }
}
#--------------------------------------------------------------------
atl_spddep = func {
  # This script handles the speed dependent actions.

  # Set the target speed to 200 kt.
  setprop("/autopilot/locks/speed", "speed-with-throttle");
  if(getprop("/autopilot/settings/target-speed-kt") > 150) {
    setprop("/autopilot/settings/target-speed-kt", 150);
  }

  gsvfps = getprop("/instrumentation/nav[0]/gs-rate-of-climb");
  kias = getprop("/velocities/airspeed-kt");
  if(kias < 160) {
    setprop("/controls/flight/flaps", 1.0);
    setprop("/autopilot/locks/approach-aoa-hold", "engaged");
    setprop("/controls/flight/spoilers", 0.0);
  } else {
    if(kias < 170) {
#      setprop("/controls/gear/gear-down", "true");
    } else {
      if(kias < 180) {
        setprop("/controls/flight/flaps", 0.36);
      } else {
        if(kias < 240) {
          setprop("/controls/gear/gear-down", "true");
        } else {
          if(getprop("/velocities/vertical-speed-fps") < -10) {
            if(gsvfps < 0) {
              setprop("/autopilot/settings/target-speed-kt", 150);
            }
          }
        }
      }
    }
  }
}
#--------------------------------------------------------------------
atl_touchdown = func {
  # Touch Down Phase
  agl = getprop("/position/altitude-agl-ft");

  setprop("/autopilot/locks/heading", "");

  if(agl > 80) {
    # Do nothing.
  } else {
    if(agl > 20) {
      interpolate("autopilot/settings/target-climb-rate-fps", -6, 4);
    } else {
      if(agl > 4) {
        interpolate("autopilot/settings/target-climb-rate-fps", -3, 2);
      } else {
        if(agl > 1) {
          interpolate("autopilot/settings/target-climb-rate-fps", -1, 1);
          setprop("/autopilot/locks/approach-aoa-hold", "off");
        } else {
          if(agl > 0.1) {
            setprop("/autopilot/locks/speed", "");
            setprop("/controls/engines/engine[0]/throttle", 0);
          } else {
            setprop("/controls/gear/brake-left", 0.4);
            setprop("/controls/gear/brake-right", 0.4);
            setprop("/autopilot/settings/target-gr-heading-deg", -999.9);
            setprop("/autopilot/locks/auto-landing", "disabled");
            setprop("/autopilot/locks/auto-take-off", "enabled");
            setprop("/autopilot/locks/altitude", "off");
            interpolate("/controls/flight/elevator-trim", 0, 10.0);
          }
        }
      }
    }
  }
}
#--------------------------------------------------------------------
atl_heading = func {
  # This script handles heading dependent actions.
  curr_kias = getprop("/velocities/airspeed-kt");
#  hdnddf = getprop("/autopilot/internal/heading-needle-deflection");
  hdnddf = getprop("/instrumentation/nav[0]/heading-needle-deflection");
  if(curr_kias > 200) {
    setprop("/autopilot/locks/heading", "nav1-hold");
  } else {
    if(hdnddf < 4) {
      if(hdnddf > -4) {
        setprop("/autopilot/locks/heading", "nav1-hold-fa");
      } else {
        setprop("/autopilot/locks/heading", "nav1-hold");
      }
    }
  }
}
#--------------------------------------------------------------------
toggle_canopy = func {
  if(getprop("/controls/canopy/canopy-pos-norm") > 0) {
    interpolate("/controls/canopy/canopy-pos-norm", 0, 3);
  } else {
    interpolate("/controls/canopy/canopy-pos-norm", 1, 3);
  }
}
#--------------------------------------------------------------------
toggle_traj_mkr = func {
  if(getprop("ai/submodels/trajectory-markers") < 1) {
    setprop("ai/submodels/trajectory-markers", 1);
  } else {
    setprop("ai/submodels/trajectory-markers", 0);
  }
}
#--------------------------------------------------------------------
initialise_drop_view_pos = func {
  eyelatdeg = getprop("/position/latitude-deg");
  eyelondeg = getprop("/position/longitude-deg");
  eyealtft = getprop("/position/altitude-ft") + 20;
  setprop("/sim/view[6]/latitude-deg", eyelatdeg);
  setprop("/sim/view[6]/longitude-deg", eyelondeg);
  setprop("/sim/view[6]/altitude-ft", eyealtft);
}
#--------------------------------------------------------------------
update_drop_view_pos = func {
  eyelatdeg = getprop("/position/latitude-deg");
  eyelondeg = getprop("/position/longitude-deg");
  eyealtft = getprop("/position/altitude-ft") + 20;
  interpolate("/sim/view[6]/latitude-deg", eyelatdeg, 5);
  interpolate("/sim/view[6]/longitude-deg", eyelondeg, 5);
  interpolate("/sim/view[6]/altitude-ft", eyealtft, 5);
}
#--------------------------------------------------------------------
fire_cannon = func {
  setprop("ai/submodels/N-37", 1);
  setprop("ai/submodels/NR-23-I", 1);
  setprop("ai/submodels/NR-23-O", 1);

  n37_cnt = getprop("ai/submodels/submodel[1]/count");
  nr23I_cnt = getprop("ai/submodels/submodel[2]/count");
  nr23O_cnt = getprop("ai/submodels/submodel[3]/count");
  n37_wgt = n37_cnt * 2;
  nr23I_wgt = nr23I_cnt * 0.38;
  nr23O_wgt = nr23O_cnt * 0.38;
  
  setprop("yasim/weights/N-37-ammunition-weight-lbs", n37_wgt);
  setprop("yasim/weights/NR-23-I-ammunition-weight-lbs", nr23I_wgt);
  setprop("yasim/weights/NR-23-O-ammunition-weight-lbs", nr23O_wgt);
}
#--------------------------------------------------------------------
cfire_cannon = func {
  setprop("ai/submodels/N-37", 0);
  setprop("ai/submodels/NR-23-I", 0);
  setprop("ai/submodels/NR-23-O", 0);
}
#--------------------------------------------------------------------
ap_common_elevator_monitor = func {
  curr_ah_state = getprop("/autopilot/locks/altitude");

  if(curr_ah_state == "altitude-hold") {
    setprop("/autopilot/locks/common-elevator-control", "engaged");
  } else {
    if(curr_ah_state == "agl-hold") {
      setprop("/autopilot/locks/common-elevator-control", "engaged");
    } else {
      if(curr_ah_state == "mach-climb") {
        setprop("/autopilot/locks/common-elevator-control", "engaged");
      } else {
        if(curr_ah_state == "vfps-hold") {
          setprop("/autopilot/locks/common-elevator-control", "engaged");
        } else {
          if(curr_ah_state == "take-off") {
            setprop("/autopilot/locks/common-elevator-control", "engaged");
          } else {
            setprop("/autopilot/locks/common-elevator-control", "off");
          }
        }
      }
    }
  } 
  settimer(ap_common_elevator_monitor, 0.5);
}
#--------------------------------------------------------------------
ap_common_aileron_monitor = func {
  curr_hd_state = getprop("/autopilot/locks/heading");

  if(curr_hd_state == "wing-leveler") {
    setprop("/autopilot/locks/common-aileron-control", "engaged");
    setprop("/autopilot/internal/target-roll-deg-unfiltered", 0);
  } else {
    if(curr_hd_state == "true-heading-hold") {
      setprop("/autopilot/locks/common-aileron-control", "engaged");
    } else {
      if(curr_hd_state == "dg-heading-hold") {
        setprop("/autopilot/locks/common-aileron-control", "engaged");
      } else {
        if(curr_hd_state == "nav1-hold") {
          setprop("/autopilot/locks/common-aileron-control", "engaged");
        } else {
          if(curr_hd_state == "nav1-hold-fa") {
            setprop("/autopilot/locks/common-aileron-control", "engaged");
          } else {
            setprop("/autopilot/locks/common-aileron-control", "off");
          }
        }
      }
    }
  } 
  settimer(ap_common_aileron_monitor, 0.5);
}
#--------------------------------------------------------------------
start_up = func {
  settimer(initialise_drop_view_pos, 5);
  settimer(ap_common_elevator_monitor, 0.5);
  settimer(ap_common_aileron_monitor, 0.5);
}
#--------------------------------------------------------------------
