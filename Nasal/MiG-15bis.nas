autotakeoff = func {

# The ato_start function is only executed once but the ato_mode and
# ato_spddep functions will re-schedule themselves until
# /autopilot/locks/auto-take-off is disabled.

#  print("autotakeoff called");
  if(getprop("autopilot/locks/auto-take-off") == "enabled") {
    ato_start();      # Initialisation.
    ato_main();       # Main loop.
  }
}
#--------------------------------------------------------------------
ato_start = func {

  if(getprop("autopilot/settings/target-gr-heading-deg") < -999) {

    setprop("controls/flight/flaps", 0.0);
    setprop("controls/flight/spoilers", 0.0);
    setprop("controls/gear/brake-left", 0.0);
    setprop("controls/gear/brake-right", 0.0);
    setprop("controls/gear/brake-parking", 0.0);

    hdgdeg = getprop("orientation/heading-deg");
    tgt_gr_pitch_deg= getprop("autopilot/settings/target-gr-pitch-deg");
    setprop("autopilot/settings/target-gr-heading-deg", hdgdeg);
    setprop("autopilot/settings/true-heading-deg", hdgdeg);
    setprop("autopilot/settings/target-speed-kt", 350);
    setprop("autopilot/internal/target-pitch-deg-unfiltered", tgt_gr_pitch_deg);
    setprop("autopilot/locks/speed", "speed-with-throttle");
    setprop("autopilot/locks/rudder-control", "gr-rudder-hold");
    setprop("autopilot/locks/altitude", "take-off");
    setprop("autopilot/internal/target-roll-deg-unfiltered", 0);
    setprop("autopilot/locks/auto-take-off", "engaged");
  }
}
#--------------------------------------------------------------------
ato_main = func {

  as_kt= getprop("velocities/airspeed-kt");
  tgt_gr_rot_spd_kt= getprop("autopilot/settings/target-gr-rot-spd-kt");
  tgt_to_p_deg= getprop("autopilot/settings/target-to-pitch-deg");

  if(as_kt < tgt_gr_rot_spd_kt) {
    # Do nothing
  } else {
    if(as_kt < 145) {
      interpolate("controls/flight/elevator", -1.0, 2);
      interpolate("autopilot/internal/target-pitch-deg-unfiltered", tgt_to_p_deg, 2);
      setprop("autopilot/locks/heading", "wing-leveler");
    } else {
      if(as_kt < 160) {
        interpolate("controls/flight/elevator", 0.0, 15);
      } else {
        if(as_kt < 170) {
          setprop("controls/gear/gear-down", "false");
          setprop("autopilot/locks/rudder-control", "");
          setprop("controls/flight/flaps", 0.0);
          interpolate("controls/flight/rudder", 0, 10);
        } else {
          if(as_kt > 200) {
            setprop("controls/flight/flaps", 0.0);
            setprop("autopilot/locks/heading", "true-heading-hold");
            setprop("autopilot/locks/speed", "mach-with-throttle");
            setprop("autopilot/locks/altitude", "mach-climb");
            setprop("autopilot/locks/auto-take-off", "disabled");
            setprop("autopilot/locks/auto-landing", "enabled");
          }
        }
      }
    }
  }

  # Re-schedule the next loop
  if(getprop("autopilot/locks/auto-take-off") == "engaged") {
    settimer(ato_main, 0.2);
  }
}
#--------------------------------------------------------------------
autoland = func {
  if(getprop("autopilot/locks/auto-landing") == "enabled") {
    atl_start();      # Initialisation.
    atl_main();       # Main loop.
  }
}
#--------------------------------------------------------------------
atl_start = func {
  setprop("autopilot/locks/auto-landing", "engaged");
}
#--------------------------------------------------------------------

atl_main = func {
  # Get the agl, kias, vfps & heading.
  agl = getprop("position/altitude-agl-ft");
  hdgdeg = getprop("orientation/heading-deg");

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
  if(getprop("autopilot/locks/auto-landing") == "engaged") {
    settimer(atl_main, 0.2);
  }
}
#--------------------------------------------------------------------
atl_glideslope= func {
  # This script handles the Glide Slope phase
  ap_alt_lock= getprop("autopilot/locks/altitude");
  gsvfps = getprop("instrumentation/nav[0]/gs-rate-of-climb");
  curr_vfps = getprop("velocities/vertical-speed-fps");

  if(ap_alt_lock != "vfps-hold") {
    setprop("autopilot/settings/target-climb-rate-fps", curr_vfps);
    interpolate("autopilot/settings/target-climb-rate-fps", gsvfps, 4);
    setprop("autopilot/locks/altitude", "vfps-hold");
  } else {
    interpolate("autopilot/settings/target-climb-rate-fps", gsvfps, 1);
  }
}
#--------------------------------------------------------------------
atl_spddep = func {
  # This script handles the speed dependent actions.

  # Set the target speed to 200 kt.
  setprop("autopilot/locks/speed", "speed-with-throttle");
  if(getprop("autopilot/settings/target-speed-kt") > 150) {
    setprop("autopilot/settings/target-speed-kt", 150);
  }

  gsvfps = getprop("instrumentation/nav[0]/gs-rate-of-climb");
  kias = getprop("velocities/airspeed-kt");
  if(kias < 160) {
    setprop("controls/flight/flaps", 1.0);
    setprop("autopilot/locks/approach-aoa-hold", "engaged");
    setprop("controls/flight/spoilers", 0.0);
  } else {
    if(kias < 170) {
      setprop("controls/gear/gear-down", "true");
    } else {
      if(kias < 180) {
        setprop("controls/flight/flaps", 0.36);
      } else {
        if(kias < 240) {
#          setprop("controls/gear/gear-down", "true");
        } else {
          if(getprop("velocities/vertical-speed-fps") < -10) {
            if(gsvfps < 0) {
              setprop("autopilot/settings/target-speed-kt", 150);
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
  agl = getprop("position/altitude-agl-ft");

  setprop("autopilot/locks/heading", "");

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
          setprop("autopilot/locks/approach-aoa-hold", "off");
        } else {
          if(agl > 0.1) {
            setprop("autopilot/locks/speed", "");
            setprop("controls/engines/engine[0]/throttle", 0);
          } else {
            setprop("controls/gear/brake-left", 0.4);
            setprop("controls/gear/brake-right", 0.4);
            setprop("autopilot/settings/target-gr-heading-deg", -999.9);
            setprop("autopilot/locks/auto-landing", "disabled");
            setprop("autopilot/locks/auto-take-off", "enabled");
            setprop("autopilot/locks/altitude", "off");
            interpolate("controls/flight/elevator-trim", 0, 10.0);
          }
        }
      }
    }
  }
}
#--------------------------------------------------------------------
atl_heading = func {
  # This script handles heading dependent actions.
  curr_kias = getprop("velocities/airspeed-kt");
#  hdnddf = getprop("autopilot/internal/heading-needle-deflection");
  hdnddf = getprop("instrumentation/nav[0]/heading-needle-deflection");
  if(curr_kias > 200) {
    setprop("autopilot/locks/heading", "nav1-hold");
  } else {
    if(hdnddf < 4) {
      if(hdnddf > -4) {
        setprop("autopilot/locks/heading", "nav1-hold-fa");
      } else {
        setprop("autopilot/locks/heading", "nav1-hold");
      }
    }
  }
}
#--------------------------------------------------------------------
toggle_traj_mkr = func {
  if(getprop("ai/submodels/trajectory-markers") == nil) {
    setprop("ai/submodels/trajectory-markers", 0);
  }
  if(getprop("ai/submodels/trajectory-markers") < 1) {
    setprop("ai/submodels/trajectory-markers", 1);
  } else {
    setprop("ai/submodels/trajectory-markers", 0);
  }
}
#--------------------------------------------------------------------
initialise_drop_view_pos = func {
  eyelatdeg = getprop("position/latitude-deg");
  eyelondeg = getprop("position/longitude-deg");
  eyealtft = getprop("position/altitude-ft") + 20;
  setprop("sim/view[100]/latitude-deg", eyelatdeg);
  setprop("sim/view[100]/longitude-deg", eyelondeg);
  setprop("sim/view[100]/altitude-ft", eyealtft);
}
#--------------------------------------------------------------------
update_drop_view_pos = func {
  eyelatdeg = getprop("position/latitude-deg");
  eyelondeg = getprop("position/longitude-deg");
  eyealtft = getprop("position/altitude-ft") + 20;
  interpolate("sim/view[100]/latitude-deg", eyelatdeg, 5);
  interpolate("sim/view[100]/longitude-deg", eyelondeg, 5);
  interpolate("sim/view[100]/altitude-ft", eyealtft, 5);
}
#--------------------------------------------------------------------
fire_cannon = func 
{
	n37_count = getprop("ai/submodels/submodel[1]/count");
	ns23_inner_count = getprop("ai/submodels/submodel[3]/count");
	ns23_outer_count = getprop("ai/submodels/submodel[5]/count");
	if (
		(n37_count==nil) 
		or (ns23_inner_count==nil)
		or (ns23_outer_count==nil)
	)
	{
		return (0);
	}
	setprop("fdm/jsbsim/weights/shells/n37", n37_count);
	setprop("fdm/jsbsim/weights/shells/n23-inner", ns23_inner_count);
	setprop("fdm/jsbsim/weights/shells/n23-outer", ns23_outer_count);
	if (n37_count>0) 
	{
		setprop("sounds/cannon/big-on", 1);
	}
	if (
		(ns23_inner_count>0) 
		or (ns23_outer_count>0)
	)
	{
		setprop("sounds/cannon/small-on", 1);
	}
	if (n37_count>0) 
	{
		n37_count=n37_count-1;
		setprop("ai/submodels/N-37", 1);
		n37_weight = n37_count*2;
	}
	else
	{
		n37_weight = 0;
	}
	if (ns23_inner_count>0) 
	{
		ns23_inner_count=ns23_inner_count-1;
		setprop("ai/submodels/NS-23-I", 1);
		ns23_inner_weight = ns23_inner_count*2;
	}
	else
	{
		ns23_inner_weight = 0;
	}
	if (ns23_outer_count>0) 
	{
		ns23_outer_count=ns23_outer_count-1;
		setprop("ai/submodels/NS-23-O", 1);
		ns23_outer_weight = ns23_outer_count*2;
	}
	else
	{
		ns23_outer_weight = 0;
	}
	return (1);
}

cfire_cannon = func {
	setprop("ai/submodels/N-37", 0);
	setprop("ai/submodels/NS-23-I", 0);
	setprop("ai/submodels/NS-23-O", 0);
	setprop("sounds/cannon/big-on", 0);
	setprop("sounds/cannon/small-on", 0);
}

#--------------------------------------------------------------------
controls.trigger = func(b) { b ? fire_cannon() : cfire_cannon() }
#--------------------------------------------------------------------
ap_common_elevator_monitor = func {
  curr_ah_state = getprop("autopilot/locks/altitude");

  if(curr_ah_state == "altitude-hold") {
    setprop("autopilot/locks/common-elevator-control", "engaged");
  } else {
    if(curr_ah_state == "agl-hold") {
      setprop("autopilot/locks/common-elevator-conctrol", "engaged");
    } else {
      if(curr_ah_state == "mach-climb") {
        setprop("autopilot/locks/common-elevator-control", "engaged");
      } else {
        if(curr_ah_state == "vfps-hold") {
          setprop("autopilot/locks/common-elevator-control", "engaged");
        } else {
          if(curr_ah_state == "take-off") {
            setprop("autopilot/locks/common-elevator-control", "engaged");
          } else {
            setprop("autopilot/locks/common-elevator-control", "off");
          }
        }
      }
    }
  } 
  settimer(ap_common_elevator_monitor, 0.5);
}
#--------------------------------------------------------------------
ap_common_aileron_monitor = func {
  curr_hd_state = getprop("autopilot/locks/heading");

  if(curr_hd_state == "wing-leveler") {
    setprop("autopilot/locks/common-aileron-control", "engaged");
    setprop("autopilot/internal/target-roll-deg-unfiltered", 0);
  } else {
    if(curr_hd_state == "true-heading-hold") {
      setprop("autopilot/locks/common-aileron-control", "engaged");
    } else {
      if(curr_hd_state == "dg-heading-hold") {
        setprop("autopilot/locks/common-aileron-control", "engaged");
      } else {
        if(curr_hd_state == "nav1-hold") {
          setprop("autopilot/locks/common-aileron-control", "engaged");
        } else {
          if(curr_hd_state == "nav1-hold-fa") {
            setprop("autopilot/locks/common-aileron-control", "engaged");
          } else {
            setprop("autopilot/locks/common-aileron-control", "off");
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

#---------------------------------------------------------------------------
#Common switch functions

#Common click sound to responce
clicksound = func
	{
		setprop("sounds/click/on", 1);
		settimer(clickoff, 0.1);
	}

clickoff = func
	{
		setprop("sounds/click/on", 0);
	}

setprop("sounds/click/on", 0);

#Common switch move function
switchmove = func (switch_name, property_name)
	{
		switch_pos=getprop(switch_name~"/switch-pos-norm");
		interpolated_pos=getprop(switch_name~"/switch-pos-inter");
		set_pos=getprop(switch_name~"/set-pos");
		swap_pos=getprop(switch_name~"/swap-pos");
		move_count=getprop(switch_name~"/move-count");
		if (
			(switch_pos == nil)
			or (interpolated_pos == nil)
			or (set_pos == nil)
			or (swap_pos == nil)
			or (move_count==nil)
		)
		{
	 		return (0); 
		}
		if (set_pos==swap_pos)
		{
			swap_pos=abs(1-set_pos);
			setprop(switch_name~"/swap-pos", swap_pos);
		}
		if (switch_pos!=set_pos)
		{
			way_to=abs(set_pos-switch_pos)/(set_pos-switch_pos);
			switch_pos=switch_pos+0.3*way_to;
			if (((way_to>0) and (switch_pos>set_pos)) or ((way_to<0) and (switch_pos<set_pos)))
			{
				setprop(switch_name~"/switch-pos-norm", set_pos);
				interpolate(switch_name~"/switch-pos-inter", set_pos, 0);
			}
			else
			{
				setprop(switch_name~"/switch-pos-norm", switch_pos);
				interpolate(switch_name~"/switch-pos-inter", switch_pos, 0.09);
			}
			move_count=move_count+1;
			setprop(switch_name~"/move-count", move_count);
		}
		else
		{
			if (move_count>0)
			{
				setprop(switch_name~"/move-count", 0);
				clicksound();
				if (switch_pos==0)
				{
					setprop(property_name, 0);
				}
				if (switch_pos==1)
				{
					setprop(property_name, 1);
				}
				if (interpolated_pos!=switch_pos)
				{
					interpolate(switch_name~"/switch-pos-inter", switch_pos, 0);
				}				
			}
		}
 		return (1); 
	}

#Timed switch move to move switch in time, call timer time must be 0.1
#Sound property to click or not to click
timedswitchmove = func (switch_name, switch_time, property_name, sound_on)
	{
		switch_pos=getprop(switch_name~"/switch-pos-norm");
		prev_pos=getprop(switch_name~"/switch-pos-prev");
		set_pos=getprop(switch_name~"/set-pos");
		swap_pos=getprop(switch_name~"/swap-pos");
		move_count=getprop(switch_name~"/move-count");
		if (
			(switch_pos == nil)
			or (set_pos == nil)
			or (prev_pos == nil)
			or (swap_pos == nil)
			or (move_count==nil)
		)
		{
	 		return (0); 
		}
		if (set_pos==swap_pos)
		{
			swap_pos=abs(1-set_pos);
			setprop(switch_name~"/swap-pos", swap_pos);
		}
		if (switch_pos!=set_pos)
		{
			way_to=abs(set_pos-switch_pos)/(set_pos-switch_pos);
			switch_pos=switch_pos+0.1/switch_time*way_to;
			if (((way_to>0) and (switch_pos>set_pos)) or ((way_to<0) and (switch_pos<set_pos)))
			{
				switch_pos=set_pos;
				setprop(switch_name~"/switch-pos-norm", set_pos);
				interpolate(switch_name~"/switch-pos-inter", set_pos, 0);
			}
			else
			{
				setprop(switch_name~"/switch-pos-norm", switch_pos);
				interpolate(switch_name~"/switch-pos-inter", switch_pos, 0.09);
			}
			move_count=move_count+1;
			setprop(switch_name~"/move-count", move_count);
		}
		if (switch_pos==set_pos)
		{
			if (move_count>0)
			{
				setprop(switch_name~"/move-count", 0);
				if (sound_on==1)
				{
					clicksound();
				}
				if (switch_pos==0)
				{
					setprop(property_name, 0);
				}
				if (switch_pos==1)
				{
					setprop(property_name, 1);
				}
			}
		}
 		return (1); 
	}

#Common switch initialisation function
switchinit = func (switch_name, init_state, property_name)
	{
		setprop(switch_name~"/switch-pos-prev", init_state);
		setprop(switch_name~"/switch-pos-norm", init_state);
		setprop(switch_name~"/switch-pos-inter", init_state);
		setprop(switch_name~"/set-pos", init_state);
		setprop(switch_name~"/swap-pos", abs(1-init_state));
		setprop(switch_name~"/move-count", 0);
		setprop(property_name, init_state);
	}

#Common switch swap function
switchswap = func (switch_name)
	{
		set_pos=getprop(switch_name~"/set-pos");
		swap_pos=getprop(switch_name~"/swap-pos");
		switch_pos=getprop(switch_name~"/switch-pos-norm");
		if ((set_pos == nil) or (swap_pos == nil) or (switch_pos==nil))
		{
	 		return (0); 
		}
		setprop(switch_name~"/switch-pos-norm", switch_pos);
		interpolate(switch_name~"/switch-pos-inter", switch_pos, 0);
		tempint=set_pos;
		set_pos=swap_pos;
		swap_pos=tempint;
		setprop(switch_name~"/set-pos", set_pos);
		setprop(switch_name~"/swap-pos", swap_pos);
		setprop(switch_name~"/move-count", 0);
 		return (1); 
	}

#Common switch back function
switchback = func (switch_name)
	{
		set_pos=getprop(switch_name~"/set-pos");
		swap_pos=getprop(switch_name~"/swap-pos");
		switch_pos=getprop(switch_name~"/switch-pos-norm");
		if ((set_pos == nil) or (swap_pos == nil) or (switch_pos==nil))
		{
	 		return (0); 
		}
		if (abs(switch_pos-set_pos)>abs(switch_pos-swap_pos))
			switchswap(switch_name);
 		return (1); 
	}

#Common switch from propery dependance function
#needed then  property controlled elsethere
switchfeedback = func (switch_name, property_name)
	{
		switch_pos=getprop(switch_name~"/switch-pos-norm");
		set_pos=getprop(switch_name~"/set-pos");
		swap_pos=getprop(switch_name~"/swap-pos");
		property=getprop(property_name);
		if ((switch_pos == nil) or (set_pos == nil) or (swap_pos == nil) or (property==nil))
		{
	 		return (0); 
		}
		if ((switch_pos==set_pos) and (swap_pos==(1-abs(set_pos))) and  (property==swap_pos))
		{
			switchswap(switch_name);
		}
 		return (1); 
	}

#smart interpolation, garantee property get to value in time
smartinterpolation = func (property_name, value, time, counts)
	{
		current_counts=getprop(property_name~"/counts");
		if ((current_counts==0) or (current_counts==nil))
		{
			interpolate(property_name~"/value", value, time);
			setprop(property_name~"/counts", 1);
		}
		else
		{
			if (current_counts==counts)
			{
				interpolate(property_name, value, 0);
				setprop(property_name~"/counts", 0);
			}
			else
			{
				setprop(property_name~"/counts", current_counts+1);
			}
		}
 		return (1); 
	}

#Common bit swap function
bitswap = func (bit_name)
	{
		set_pos=getprop(bit_name);
		if (!((set_pos==1) or (set_pos==0)))
		{
			return (0); 
		}
		else
		{
			swap_pos=1-abs(set_pos);
			setprop(bit_name, swap_pos);
			return (1); 
		}
	}

#--------------------------------------------------------------------
#Init Controls
init_controls  = func
{
	setprop("controls/gear/brake-parking", 1);
	setprop("controls/gear/gear-down", 1);
	setprop("controls/flight/aileron", 0);
	setprop("controls/flight/elevator", 0);
	setprop("controls/flight/rudder", 0);
	setprop("controls/flight/flaps", 0);
	setprop("controls/flight/speedbrake", 0);
}

init_controls();

#--------------------------------------------------------------------
#Init FDM
init_fdm  = func
{
	setprop("fdm/jsbsim/fcs/throttle-cmd-norm", 0);
	setprop("fdm/jsbsim/fcs/throttle-cmd-norm-real", 0.3);
	setprop("fdm/jsbsim/fcs/throttle-pos-norm", 0.3);

	setprop("fdm/jsbsim/fcs/pitch-trim-norm-real", 0);
	setprop("fdm/jsbsim/fcs/elevator-trim-norm-real", 0);
	setprop("fdm/jsbsim/fcs/elevator-cmd-norm", 0);
	setprop("fdm/jsbsim/fcs/elevator-cmd-norm-real", 0);
	setprop("fdm/jsbsim/fcs/elevator-pos-norm", 0);

	setprop("fdm/jsbsim/fcs/aileron-boost", 0);
	setprop("fdm/jsbsim/fcs/roll-trim-norm-real", 0);
	setprop("fdm/jsbsim/fcs/roll-pos-norm", 0);

	setprop("fdm/jsbsim/fcs/aileron-cmd-norm", 0);
	setprop("fdm/jsbsim/fcs/aileron-cmd-norm-real", 0);
	setprop("fdm/jsbsim/fcs/aileron-pos-norm", 0);

	setprop("fdm/jsbsim/fcs/rudder-cmd-norm", 0);
	setprop("fdm/jsbsim/fcs/rudder-cmd-norm-real", 0);
	setprop("fdm/jsbsim/fcs/rudder-pos-norm", 0);

	setprop("fdm/jsbsim/fcs/flap-cmd-norm", 0);
	setprop("fdm/jsbsim/fcs/flap-cmd-norm-real", 0);
	setprop("fdm/jsbsim/fcs/flap-pos-norm", 0);

	setprop("fdm/jsbsim/gear/gear-cmd-norm", 0);
	setprop("fdm/jsbsim/gear/gear-cmd-norm-real", 1);

	setprop("fdm/jsbsim/gear/unit[0]/pos-norm", 1);
	setprop("fdm/jsbsim/gear/unit[1]/pos-norm", 1);
	setprop("fdm/jsbsim/gear/unit[2]/pos-norm", 1);

	setprop("fdm/jsbsim/gear/unit[0]/tored", 0);
	setprop("fdm/jsbsim/gear/unit[1]/tored", 0);
	setprop("fdm/jsbsim/gear/unit[2]/tored", 0);

	setprop("fdm/jsbsim/gear/unit[0]/stuck", 0);
	setprop("fdm/jsbsim/gear/unit[1]/stuck", 0);
	setprop("fdm/jsbsim/gear/unit[2]/stuck", 0);

	setprop("fdm/jsbsim/gear/unit[0]/break-type", "");
	setprop("fdm/jsbsim/gear/unit[1]/break-type", "");
	setprop("fdm/jsbsim/gear/unit[2]/break-type", "");

#	setprop("ai/submodels/gear-middle-drop", 0);
#	setprop("ai/submodels/gear-left-drop", 0);
#	setprop("ai/submodels/gear-right-drop", 0);

	setprop("fdm/jsbsim/fcs/speedbrake-cmd-norm", 0);
	setprop("fdm/jsbsim/fcs/speedbrake-cmd-norm-real", 0);
	setprop("fdm/jsbsim/fcs/speedbrake-pos-norm", 0);
	setprop("fdm/jsbsim/tanks/fastened", 0);
}

init_fdm();

#Init positions
#--------------------------------------------------------------------
init_positions  = func
{
	setprop("surface-positions/elevator-pos-norm", 0);
	setprop("surface-positions/left-aileron-pos-norm", 0);
	setprop("surface-positions/right-aileron-pos-norm", 0);
	setprop("surface-positions/rudder-pos-norm", 0);
	setprop("surface-positions/flap-pos-norm", 0);
	setprop("surface-positions/speedbrake-pos-norm", 0);

	setprop("gear/gear[0]/wow", 0);
	setprop("gear/gear[1]/wow", 0);
	setprop("gear/gear[2]/wow", 0);
	setprop("gear/gear[3]/wow", 0);
	setprop("gear/gear[4]/wow", 0);
	setprop("gear/gear[5]/wow", 0);
	setprop("gear/gear[6]/wow", 0);
	setprop("gear/gear[7]/wow", 0);
	setprop("gear/gear[8]/wow", 0);
	setprop("gear/gear[9]/wow", 0);
	setprop("gear/gear[10]/wow", 0);
}

init_positions();

#Init aircraft
#--------------------------------------------------------------------
start_init=func
	{
		setprop("fdm/jsbsim/init/on", 1);
		setprop("fdm/jsbsim/init/finally-initialized", 0);
		final_init();
	}

final_init=func
	{
		initialization=getprop("fdm/jsbsim/init/on");
		time_elapsed=getprop("fdm/jsbsim/simulation/sim-time-sec");
		if (
			(initialization!=nil)
			and
			(time_elapsed!=nil)
		)
		{
			if (time_elapsed>0)
			{
				setprop("consumables/fuel/tank[2]/level-gal_us", 30);
				setprop("fdm/jsbsim/init/on", 0);
				setprop("fdm/jsbsim/init/finally-initialized", 1);
			}
			else
			{
		 		return ( settimer(final_init, 0.1) ); 
			}
		}
	}

start_init();

#--------------------------------------------------------------------
# Radio Altimeter rv-two

# helper 
stop_radioaltimeter = func 
	{
		setprop("instrumentation/radioaltimeter/lamp", 0);
	}

radioaltimeter = func 
	{
		#check serviceabless
		in_service = getprop("instrumentation/radioaltimeter/serviceable");
		if (in_service == nil)
		{
			stop_radioaltimeter();
	 		return ( settimer(radioaltimeter, 0.1) ); 
		}
		if( in_service != 1 )
		{
			stop_radioaltimeter();
		 	return ( settimer(radioaltimeter, 0.1) ); 
		}
		#check power
		power=getprop("systems/electrical-real/outputs/radioaltimeter/volts-norm");
		# check state
		state_on=getprop("instrumentation/radioaltimeter/switch-pos-norm");
		# check selector position
		diapazone = getprop("instrumentation/radioaltimeter/diapazone/switch-pos-norm");
		#check altitude positions
		altitude=getprop("position/altitude-ft");
		elevation=getprop("position/ground-elev-ft");
		# get orientation values
		roll_deg = getprop("orientation/roll-deg");
		pitch_deg = getprop("orientation/pitch-deg");
		if ((power==nil) or (state_on==nil) or (diapazone== nil) or (altitude==nil) or (elevation== nil) or (roll_deg==nil) or (pitch_deg==nil))
		{
			stop_radioaltimeter();
	 		return ( settimer(radioaltimeter, 0.1) ); 
		}
		switchmove("instrumentation/radioaltimeter", "dummy/dummy");
		switchmove("instrumentation/radioaltimeter/diapazone", "dummy/dummy");
		if ((power==0) or (state_on==0))
		{
			setprop("instrumentation/radioaltimeter/value", -100);
			stop_radioaltimeter();
		 	return ( settimer(radioaltimeter, 0.1) ); 
		}
		setprop("instrumentation/radioaltimeter/lamp", power);
		# convert from position to meters
		if (diapazone==1)
		{ 
			#diapazone 0-1200m
			value = (0.3048*(altitude-elevation)) / 10;
		}
		else
		{
			#diapazone 0-120m
			value = 0.3048*(altitude-elevation);
		}
		#add maneur distortion
		if (abs(pitch_deg)<90)
		{
			pitch_distort=0.5*(math.sin(abs(pitch_deg)/180*math.pi));
		}
		else
		{
			pitch_distort=0.5*(1+math.sin((abs(pitch_deg)-90)/180*math.pi));
		}
		setprop("instrumentation/radioaltimeter/pitch-deg", pitch_deg);
		setprop("instrumentation/radioaltimeter/pitch-distort", pitch_distort);
		if (abs(roll_deg)<90)
		{
			roll_distort=0.5*(math.sin(abs(roll_deg)/180*math.pi));
		}
		else
		{
			roll_distort=0.5*(1+math.sin((abs(pitch_deg)-90)/180*math.pi));
		}
		setprop("instrumentation/radioaltimeter/roll-deg", roll_deg);
		setprop("instrumentation/radioaltimeter/roll-distort", roll_distort);
		if (roll_distort>pitch_distort)
		{
			distort=roll_distort;
		}
		else
		{
			distort=pitch_distort;
		}
		value_distorted=value*(1+distort*0.2);
	 	setprop("instrumentation/radioaltimeter/alt-real", value);
	 	setprop("instrumentation/radioaltimeter/value", value_distorted);
		settimer(radioaltimeter, 0.1);
	}

# set startup configuration
init_radioaltimeter = func
{
	switchinit("instrumentation/radioaltimeter", 1, "dummy/dummy");
	switchinit("instrumentation/radioaltimeter/diapazone", 0, "dummy/dummy");
	setprop("instrumentation/radioaltimeter/serviceable", 1);
	setprop("instrumentation/radioaltimeter/lamp", 0);
	setprop("instrumentation/radioaltimeter/value", -100);
}

init_radioaltimeter();

# start radio altimeter process first time
radioaltimeter ();

#--------------------------------------------------------------------
# Chronometer

# helper 
stop_chron = func {
}

chron = func 
	{
		# check power
		in_service = getprop("instrumentation/clock/serviceable" );
		if (in_service == nil)
		{
			stop_chron();
	 		return ( settimer(chron, 0.1) ); 
		}
		if( in_service != 1 )
		{
			stop_chron();
		 	return ( settimer(chron, 0.1) ); 
		}		
		# set secondomer
		sec_on = getprop("instrumentation/clock/sec_on");
		sec_set = getprop("instrumentation/clock/sec_set");
		sec_now=getprop("instrumentation/clock/indicated-sec");
		if ((sec_on == nil) or (sec_set == nil) or (sec_now == nil))
		{
			stop_chron();
	 		return ( settimer(chron, 0.1) ); 
		}
		if (sec_set>=1 )
		{
			setprop("instrumentation/clock/sec_set", 0);
			if (sec_on==0)
			{
				sec_on=1;
				setprop("instrumentation/clock/sec_on", sec_on);
				sec_start=getprop("instrumentation/clock/indicated-sec");
				setprop("instrumentation/clock/sec_start", sec_start);
			}
			else
			{
				sec_on=0;
				setprop("instrumentation/clock/sec_on", sec_on);
			}
		}
		if (sec_on==1)
		{
			sec_start=getprop("instrumentation/clock/sec_start");
			sec_show=sec_now-sec_start;
			setprop("instrumentation/clock/sec_show", sec_show);
		}

		# set inflight time
		inf_on = getprop("instrumentation/clock/inf_on");
		inf_set = getprop("instrumentation/clock/inf_set");
		inf_sec = getprop("instrumentation/clock/inf_sec");
		if ((inf_on == nil) or (inf_set == nil) or (inf_sec == nil))
		{
			stop_chron();
	 		return ( settimer(chron, 0.1) ); 
		}
		if (inf_set>=1 )
		{
			setprop("instrumentation/clock/inf_set", 0);
			if (inf_on==0)
			{
				inf_on=1;
				setprop("instrumentation/clock/inf_on", inf_on);
			}
			else
			{
				inf_on=0;
				setprop("instrumentation/clock/inf_on", inf_on);
			}
		}
		if (inf_on==1)
		{
			inf_sec=inf_sec+0.1;
			inf_days=int(inf_sec/(60*60*24));
			if (inf_sec<0)
			{
				inf_sec=60*60*24*10+inf_sec;
				inf_days=int(inf_sec/(60*60*24));
			}
			if (inf_sec>(60*60*24*10))
			{
				inf_sec=inf_sec-60*60*24*10;
				inf_days=int(inf_sec/(60*60*24));
			}
			setprop("instrumentation/clock/inf_sec", inf_sec);
			setprop("instrumentation/clock/inf_days", inf_days);
		}
		settimer(chron, 0.1);
	}

# set startup configuration
init_chron = func
{
	setprop("instrumentation/clock/serviceable", 1);
	setprop("instrumentation/clock/sec_on", 0);
	setprop("instrumentation/clock/sec_set", 0);
	setprop("instrumentation/clock/sec_start", 0);
	setprop("instrumentation/clock/inf_on", 1);
	setprop("instrumentation/clock/inf_set", 0);
	setprop("instrumentation/clock/inf_sec", 0);
	setprop("instrumentation/clock/inf_days", 0);
}

init_chron();

# start cronometer process first time
chron ();

#--------------------------------------------------------------------
# Cabin manometer

# helper 
stop_manometer = func 
	{
		setprop("instrumentation/manometer/lamp", 0);
	}

manometer = func 
	{
		# check power
		in_service = getprop("instrumentation/manometer/serviceable" );
		if (in_service == nil)
		{
			stop_manometer();
	 		return ( settimer(manometer, 5) ); 
		}
		if( in_service != 1 )
		{
			stop_manometer();
		 	return ( settimer(manometer, 5) ); 
		}
		# get pressure values
		pressure = getprop("environment/pressure-inhg");
		sea_pressure = getprop("environment/pressure-sea-level-inhg");
		cabin_pressure = getprop("instrumentation/manometer/cabin-pressure");
		# get canopy value, 0 is closed
		canopy = getprop("instrumentation/canopy/switch-pos-norm");
		if ((pressure == nil) or (sea_pressure == nil) or (cabin_pressure == nil) or (canopy == nil))
		{
			stop_manometer();
	 		return ( settimer(manometer, 5) ); 
		}
		#There is two processes to cabin pressure
		#first is pressure system that try to make it higher 
		cabin_pressure=cabin_pressure+(((sea_pressure*9+pressure)/10)-cabin_pressure)*(0.05);
		#second depends on canopy and try to make it on flight level with lesser speed
		#but it really fast then canopy is open 
		cabin_pressure=cabin_pressure+(pressure-cabin_pressure)*(canopy+0.005);
		setprop("instrumentation/manometer/cabin-pressure", cabin_pressure);
		cabin_delta=pressure/cabin_pressure;
		setprop("instrumentation/manometer/cabin-delta", cabin_delta);
	  	settimer(manometer, 5);
	}

# set startup configuration
init_manometer = func
{
	setprop("instrumentation/manometer/serviceable", 1);
	pressure = getprop("environment/pressure-inhg");
	setprop("instrumentation/manometer/cabin-pressure", pressure);
}

init_manometer();

# start manometer process first time
manometer ();

#--------------------------------------------------------------------
# Magnetic compass

init_magnetic_compass = func
{
	setprop("instrumentation/magnetic-compass/offset", 0);
}

init_magnetic_compass();

#--------------------------------------------------------------------
#Gear friction

terrain_under = func
	{
		lat = getprop ("position/latitude-deg");
		lon = getprop ("position/longitude-deg");
		info = geodinfo (lat,lon);

		if (info != nil) 
		{
			if (info[1] != nil)
			{
				if (info[1].solid != nil) 
				{
					setprop ("environment/terrain", info[1].solid);
				}
				if (info[1].load_resistance != nil)
				{
					setprop ("environment/terrain-load-resistance", info[1].load_resistance);
				}
				if (info[1].bumpiness != nil)
				{
					setprop ("environment/terrain-bumpiness", info[1].bumpiness);
				}
				if (info[1].friction_factor != nil)
				{
					setprop ("environment/terrain-friction-factor", info[1].friction_factor);
				}
				if (info[1].rolling_friction != nil)
				{
					setprop ("environment/terrain-rolling-friction", info[1].rolling_friction);
				}
			}
		}
		else
		{
			setprop ("environment/terrain", 1);
		}

		settimer (terrain_under, 0.1);
	}

terrain_under();

set_friction = func
	{
		friction = getprop ("environment/terrain-friction-factor");
		rain = getprop ("environment/metar/rain-norm");
		if (rain != nil)
		{
			friction_water = 0.4 * rain;
		}
		else
		{
			friction_water = 0;
		}
		if (friction != nil)
		{
			if (friction = 1)
			{
				friction = 0.8-friction_water;
			}
			setprop("fdm/jsbsim/gear/unit[0]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[1]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[2]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[3]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[4]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[5]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[6]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[7]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[8]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[9]/static_friction_coeff", friction);
			setprop("fdm/jsbsim/gear/unit[10]/static_friction_coeff", friction);
		}
		settimer (set_friction, 0.1);
	}

set_friction();

#--------------------------------------------------------------------
# Gear breaks listener

teargear = func (gear_number, breaktype)
	{
		gear_tored=getprop("fdm/jsbsim/gear/unit["~gear_number~"]/tored");
		if (gear_tored==nil)
		{
			return (0);
		}
		if (gear_tored==1)
		{
			return (0);
		}
		wow=getprop("gear/gear["~gear_number~"]/wow");
		setprop("fdm/jsbsim/gear/unit["~gear_number~"]/break-type", breaktype);
		setprop("fdm/jsbsim/gear/unit["~gear_number~"]/tored", 1);
		setprop("fdm/jsbsim/gear/unit["~gear_number~"]/pos-norm", 0);
		setprop("gear/gear["~gear_number~"]/position-norm", 0);
		gears_tored_sound=getprop("sounds/gears-tored/on");
		if (gears_tored_sound!=nil)
		{
			if (gears_tored_sound==0)
			{
				geartoredsound();
			}
		}
		if (wow!=nil)
		{
			if (wow==0)
			{
				if (gear_number==0)
				{
					setprop("ai/submodels/gear-middle-drop", 1);
				}
				if (gear_number==1)
				{
					setprop("ai/submodels/gear-left-drop", 1);
				}
				if (gear_number==2)
				{
					setprop("ai/submodels/gear-right-drop", 1);
				}
			}
		}
		return (1);
	}

# helper 
stop_gearbreakslistener = func 
	{
	}

gearbreakslistener = func 
	{
		# check state
		in_service = getprop("listneners/gear-break/enabled" );
		if (in_service == nil)
		{
			return ( stop_gearbreakslistener );
		}
		if ( in_service != 1 )
		{
			return ( stop_gearbreakslistener );
		}
		# get gear values
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		maximum_g=getprop("fdm/jsbsim/accelerations/Nz-max");
		speed=getprop("velocities/airspeed-kt");
		pitch_degps=getprop("orientation/pitch-rate-degps");
		roll_speed_one=getprop("gear/gear/rollspeed-ms");
		roll_speed_two=getprop("gear/gear[1]/rollspeed-ms");
		roll_speed_three=getprop("gear/gear[2]/rollspeed-ms");
		compression_one=getprop("gear/gear/compression-ft");
		compression_two=getprop("gear/gear[1]/compression-ft");
		compression_three=getprop("gear/gear[2]/compression-ft");
		wow_one=getprop("gear/gear/wow");
		wow_two=getprop("gear/gear[1]/wow");
		wow_three=getprop("gear/gear[2]/wow");
		gear_started=getprop("fdm/jsbsim/init/finally-initialized");
		if (
			(gear_one_tored==nil)
			or (gear_two_tored==nil)
			or (gear_three_tored==nil)
			or (pilot_g==nil)
			or (maximum_g==nil)
			or (speed==nil)
			or (pitch_degps==nil)
			or (roll_speed_one==nil)
			or (roll_speed_two==nil)
			or (roll_speed_three==nil)
			or (compression_one==nil)
			or (compression_two==nil)
			or (compression_three==nil)
			or (wow_one==nil)
			or (wow_two==nil)
			or (wow_three==nil)
			or (gear_started==nil)
		)
		{
			return ( stop_gearbreakslistener ); 
		}
		if (gear_started==0)
		{
			return ( stop_gearbreakslistener ); 
		}
		#Hit breaks and ground type breaks checks here, speed breaks checks in process
		if (
			(wow_one>0)
			and (abs(pilot_g)>2)
			and (abs(pilot_g)>(maximum_g-(maximum_g*0.25)))
		)
		{
			gear_one_tored=teargear(0, "hit overload "~pilot_g);
		}
		if (
			(wow_two>0)
			and (abs(pilot_g)>2)
			and (abs(pilot_g)>(maximum_g-(maximum_g*0.25)))
		)
		{
			gear_two_tored=teargear(1, "hit overload "~pilot_g);
		}
		if (
			(wow_three>0)
			and (abs(pilot_g)>2)
			and (abs(pilot_g)>(maximum_g-(maximum_g*0.25)))
		)
		{
			gear_three_tored=teargear(2, "hit overload "~pilot_g);
		}
		if (
			(wow_one>0) 
			and (
				(wow_two==0)
				and (wow_three==0)
			)
		)
		{
			gear_one_tored=teargear(0, "dig "~pilot_g);
		}
		if (
			(wow_one>0)
			and (pitch_degps<-10)
		)
		{
			gear_one_tored=teargear(0, "peck "~pitch_degps);
		}
	}

init_gearbreakslistener = func 
{
	setprop("sounds/gears-tored/on", 0);
	setprop("listneners/gear-break/enabled", 1);
}

init_gearbreakslistener();

setlistener("gear/gear/wow", gearbreakslistener);
setlistener("gear/gear[1]/wow", gearbreakslistener);
setlistener("gear/gear[2]/wow", gearbreakslistener);


#--------------------------------------------------------------------
# Gear breaks

# helper 
stop_gearbreaksprocess = func 
	{
	}

gearbreaksprocess = func 
	{
		# check state
		in_service = getprop("processes/gear-break/enabled" );
		if (in_service == nil)
		{
			stop_gearbreaksprocess();
	 		return ( settimer(gearbreaksprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearbreaksprocess();
	 		return ( settimer(gearbreaksprocess, 0.1) ); 
		}
		# get gear values
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		maximum_g=getprop("fdm/jsbsim/accelerations/Nz-max");
		maximum_g_tenth=getprop("fdm/jsbsim/accelerations/Nz-max-tenth");
		speed=getprop("velocities/airspeed-kt");
		pitch_degps=getprop("orientation/pitch-rate-degps");
		roll_speed_one=getprop("gear/gear/rollspeed-ms");
		roll_speed_two=getprop("gear/gear[1]/rollspeed-ms");
		roll_speed_three=getprop("gear/gear[2]/rollspeed-ms");
		wow_one=getprop("gear/gear/wow");
		wow_two=getprop("gear/gear[1]/wow");
		wow_three=getprop("gear/gear[2]/wow");
		if (
			(gear_one_pos == nil)
			or (gear_two_pos == nil)
			or (gear_three_pos == nil)
			or (gear_one_tored==nil)
			or (gear_two_tored==nil)
			or (gear_three_tored==nil)
			or (pilot_g==nil)
			or (maximum_g==nil)
			or (maximum_g_tenth=nil)
			or (speed==nil)
			or (pitch_degps==nil)
			or (roll_speed_one==nil)
			or (roll_speed_two==nil)
			or (roll_speed_three==nil)
			or (wow_one==nil)
			or (wow_two==nil)
			or (wow_three==nil)
		)
		{
			stop_gearbreaksprocess();
	 		return ( settimer(gearbreaksprocess, 0.1) ); 
		}
		lat = getprop("position/latitude-deg");
		lon = getprop("position/longitude-deg");
		if (
			(lat == nil)
			or (lon==nil)
		)
		{
			stop_gearbreaksprocess();
	 		return ( settimer(gearbreaksprocess, 0.1) ); 
		}
		info = geodinfo(lat, lon);
		if (info == nil)
		{
			stop_gearbreaksprocess();
	 		return ( settimer(gearbreaksprocess, 0.1) ); 
		}
		if (
			(info[0] == nil)
			or (info[1] == nil)
		)
		{
			stop_gearbreaksprocess();
	 		return ( settimer(gearbreaksprocess, 0.1) ); 
		}
		setprop("gear/info/height", info[0]);
		setprop("gear/info/light_coverage", info[1].light_coverage);
		setprop("gear/info/bumpiness", info[1].bumpiness);
		setprop("gear/info/load_resistance", info[1].load_resistance);
		setprop("gear/info/solid", info[1].solid);
		i=0;
		foreach(terrain_name; info[1].names)
		{
			setprop("gear/info/names["~i~"]", terrain_name);
			i=i+1;
		}
		setprop("gear/info/friction_factor", info[1].friction_factor);
		setprop("gear/info/rolling_friction", info[1].rolling_friction);
		if (
			((gear_one_pos>0) and (gear_one_tored==0))
			or ((gear_two_pos>0) and (gear_two_tored==0))
			or ((gear_three_pos>0) and (gear_three_tored==0))
		)
		{
			speed_km=speed*1.852;
			#Middle gear speed limit max 550 km\h on 0.5 of extraction, 520 on 1
			speed_limit_middle=500-((gear_one_pos-0.5)/(1-0.5))*(550-525);
			setprop("fdm/jsbsim/gear/unit[0]/speed-limit", speed_limit_middle);
			if ((speed_km>speed_limit_middle) and (speed_limit_middle>0))
			{
				if ((gear_one_tored==0) and (gear_one_pos>0))
				{
					gear_one_tored=teargear(0, "overspeeed "~speed_km);
				}
			}
			speed_limit_left=525-((gear_two_pos-0.5)/(1-0.5))*(525-505);
			setprop("fdm/jsbsim/gear/unit[1]/speed-limit", speed_limit_left);
			if ((speed_km>speed_limit_left) and (speed_limit_left>0))
			{
				if ((gear_two_tored==0) and (gear_two_pos>0))
				{
					gear_two_tored=teargear(1, "overspeeed "~speed_km);
				}
			}
			speed_limit_right=610-((gear_three_pos-0.5)/(1-0.5))*(610-515);
			setprop("fdm/jsbsim/gear/unit[2]/speed-limit", speed_limit_right);
			if ((speed_km>speed_limit_right) and (speed_limit_right>0))
			{
				if ((gear_three_tored==0) and (gear_three_pos>0))
				{
					gear_three_tored=teargear(2, "overspeeed "~speed_km);
				}
			}
			roll_speed_km_one=(roll_speed_one*(60*60)/1000);
			roll_speed_km_two=(roll_speed_two*(60*60)/1000);
			roll_speed_km_three=(roll_speed_three*(60*60)/1000);
			if ((gear_one_tored==0) and (wow_one==1) and (roll_speed_km_one>300))
			{
				gear_one_tored=teargear(0, "overroll "~speed_km);
			}
			if ((gear_two_tored==0) and (wow_two==1) and (roll_speed_km_two>325))
			{
				gear_two_tored=teargear(1, "overroll "~speed_km);
			}
			if ((gear_three_tored==0) and (wow_three==1) and (roll_speed_km_three>320))
			{
				gear_three_tored=teargear(2, "overroll "~speed_km);
			}

			if (
				(gear_one_tored==0) 
				and (wow_one==0) 
				and (abs(pilot_g)>3)
			)
			{
				gear_one_tored=teargear(0, "flight overload "~pilot_g);
			}
			if (
				(gear_two_tored==0) 
				and (wow_two==0) 
				and (abs(pilot_g)>3)
			)
			{
				gear_two_tored=teargear(1, "flight overload "~pilot_g);
			}
			if (
				(gear_three_tored==0) 
				and (wow_three==0) 
				and (abs(pilot_g)>3)
			)
			{
				gear_three_tored=teargear(2, "flight overload "~pilot_g);
			}

			if (info[1].solid!=1)
			{
				if ((gear_one_tored==0) and (wow_one>0))
				{
					gear_one_tored=teargear(0, "water ");
				}
				if ((gear_two_tored==0) and (wow_two>0))
				{
					gear_two_tored=teargear(1, "water ");
				}
				if ((gear_three_tored==0) and (wow_three>0))
				{
					gear_three_tored=teargear(2, "water ");
				}
			}
			if (
				(info[1].bumpiness>0.1)
				or (info[1].rolling_friction>0.05)
				or (info[1].friction_factor<0.7)
			)
			{
				if ((gear_one_tored==0) and (wow_one==1) and (roll_speed_km_one>75))
				{
					gear_one_tored=teargear(0, "ground overroll "~speed_km);
				}
				if ((gear_two_tored==0) and (wow_two==1) and (roll_speed_km_two>80))
				{
					gear_two_tored=teargear(1, "ground overroll "~speed_km);
				}
				if ((gear_three_tored==0) and (wow_three==1) and (roll_speed_km_three>82))
				{
					gear_three_tored=teargear(2, "ground overroll "~speed_km);
				}
			}
			if (
				(info[1].bumpiness==1)
				or (info[1].rolling_friction==1)
			)
			{
				if ((gear_one_tored==0) and (wow_one==1))
				{
					gear_one_tored=teargear(0, "wrongground");
				}
				if ((gear_two_tored==0) and (wow_two==1))
				{
					gear_two_tored=teargear(1, "wrongground");
				}
				if ((gear_three_tored==0) and (wow_three==1))
				{
					gear_three_tored=teargear(2, "wrongground");
				}
			}

		}
		gear_impact=getprop("ai/submodels/gear-middle-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-middle-impact", "");
				gear_touch_down();
			}
		}
		gear_impact=getprop("ai/submodels/gear-middle-left-door-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-middle-left-door-impact", "");
			}
		}
		gear_impact=getprop("ai/submodels/gear-middle-right-door-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-middle-right-door-impact", "");
			}
		}
		gear_impact=getprop("ai/submodels/gear-left-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-left-impact", "");
				gear_touch_down();
			}
		}
		gear_impact=getprop("ai/submodels/gear-left-stow-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-left-stow-impact", "");
			}
		}
		gear_impact=getprop("ai/submodels/gear-left-door-inner-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-left-door-inner-impact", "");
			}
		}
		gear_impact=getprop("ai/submodels/gear-left-door-middle-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-left-door-middle-impact", "");
			}
		}
		gear_impact=getprop("ai/submodels/gear-left-door-outer-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-left-door-outer-impact", "");
			}
		}
		gear_impact=getprop("ai/submodels/gear-right-impact");
		if (gear_impact!=nil)
		{
			if (gear_impact!="")
			{
				setprop("ai/submodels/gear-right-impact", "");
				gear_touch_down();
			}
		}
		gear_middle_drop=getprop("ai/submodels/gear-middle-drop");
		if (gear_middle_drop!=nil)
		{
			if ((gear_one_tored==0) and (gear_middle_drop==1))
			{
				setprop("ai/submodels/gear-middle-drop", 0);
			}
		}
		gear_left_drop=getprop("ai/submodels/gear-left-drop");
		if (gear_left_drop!=nil)
		{
			if ((gear_two_tored==0) and (gear_left_drop==1))
			{
				setprop("ai/submodels/gear-left-drop", 0);
			}
		}
		gear_right_drop=getprop("ai/submodels/gear-right-drop");
		if (gear_right_drop!=nil)
		{
			if ((gear_three_tored==0) and (gear_right_drop==1))
			{
				setprop("ai/submodels/gear-right-drop", 0);
			}
		}
		settimer(gearbreaksprocess, 0.1)
	}

# set startup configuration
init_gearbreaksprocess = func
{
	setprop("processes/gear-break/enabled", 1);
}

init_gearbreaksprocess();

geartoredsound = func
	{
		setprop("sounds/gears-tored/on", 1);
		settimer(geartoredsoundoff, 0.3);
	}

geartoredsoundoff = func
	{
		setprop("sounds/gears-tored/on", 0);
	}

gear_touch_down = func
	{
		setprop("sounds/gears-down/on", 1);
		settimer(end_gear_touch_down, 3);
	}

end_gear_touch_down = func
	{
		setprop("sounds/gears-down/on", 0);
	}

# start gear break process first time, give time to proper initialization
gearbreaksprocess();

#--------------------------------------------------------------------
# Gear control

# helper 
stop_gearcontrol = func 
	{
	}

gearcontrol = func 
	{
		# check state
		in_service = getprop("instrumentation/gear-control/serviceable" );
		if (in_service == nil)
		{
			stop_gearcontrol();
	 		return ( settimer(gearcontrol, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearcontrol();
		 	return ( settimer(gearcontrol, 0.1) ); 
		}
		# get gear values
		gear_down = getprop("controls/gear/gear-down");
		gear_down_real = getprop("fdm/jsbsim/gear/gear-cmd-norm-real");
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		gear_one_stuck=getprop("fdm/jsbsim/gear/unit[0]/stuck");
		gear_two_stuck=getprop("fdm/jsbsim/gear/unit[1]/stuck");
		gear_three_stuck=getprop("fdm/jsbsim/gear/unit[2]/stuck");
		# get instrumentation values	
		switch_pos=getprop("instrumentation/gear-control/switch-pos-norm");
		fix_pos=getprop("instrumentation/gear-control/fix-pos-norm");
		#get gear valve and handles values
		valve_press=getprop("instrumentation/gear-valve/pressure-norm");
		left_handle_pos=getprop("instrumentation/gear-handles/left/switch-pos-norm");
		right_handle_pos=getprop("instrumentation/gear-handles/right/switch-pos-norm");
		#get power values
		pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		engine_running=getprop("engines/engine/running");
		set_generator=getprop("controls/switches/generator");
		speed=getprop("velocities/airspeed-kt");
		if (
			(gear_down == nil)
			or (gear_down_real == nil)
			or (gear_one_pos == nil)
			or (gear_two_pos == nil)
			or (gear_three_pos == nil)
			or (gear_one_stuck == nil)
			or (gear_two_stuck == nil)
			or (gear_three_stuck == nil)
			or (switch_pos == nil)
			or (fix_pos == nil)
			or (valve_press==nil)
			or (left_handle_pos==nil)
			or (right_handle_pos==nil)
			or (pump==nil)
			or (engine_running==nil)
			or (set_generator==nil)
			or (speed==nil)
		)
		{
			stop_gearcontrol();
	 		return ( settimer(gearcontrol, 0.1) ); 
		}
		if (gear_down!=gear_down_real)
		{
			if (
				(
					(pump==1) 
					and (valve_press==0.8)
				)
				and
				(
					(engine_running!=1)
					or (set_generator!=1)
				)
			)
			{
				pump=0;
				setprop("instrumentation/switches/pump/set-pos", 0);
			}
			if (fix_pos!=1)
			{
				fix_pos=fix_pos+0.3;
				if (fix_pos>=1)
				{
					setprop("instrumentation/gear-control/fix-pos-norm", 1);
					clicksound();
				}
				else
				{
					setprop("instrumentation/gear-control/fix-pos-norm", fix_pos);
				}
			}
			else
			{
				if (gear_down_real>gear_down)
				{
					#gear goes up
					if (switch_pos!=1)
					{
						switch_pos=switch_pos+0.3;
						if (switch_pos>=1)
						{
							setprop("instrumentation/gear-control/switch-pos-norm", 1);
							gear_down_real=gear_down;
						}
						else
						{
							setprop("instrumentation/gear-control/switch-pos-norm", switch_pos);
						}
					}
					else
					{
						gear_down_real=gear_down;
					}
				}		
				else
				{
					#gear goes down
					if (switch_pos!=-1)
					{
						switch_pos=switch_pos-0.3;
						if (switch_pos<=-1)
						{
							setprop("instrumentation/gear-control/switch-pos-norm", -1);
							gear_down_real=gear_down;
						}
						else
						{
							setprop("instrumentation/gear-control/switch-pos-norm", switch_pos);
						}
					}
					else
					{
						gear_down_real=gear_down;
					}
				}		
			}
		}
		else
		{
			if (
				(
					(gear_down_real==1) 
					and (
						(gear_one_pos==1)
						or (gear_one_stuck==1)
					)
					and
					(
						(gear_two_pos==1)
						or (gear_two_stuck==1)
					)
					and
					(
						(gear_three_pos==1)
						or (gear_three_stuck==1)
					)
				)
				or
				(
					(gear_down_real==0) 
					and (
						(gear_one_pos==0)
						or (gear_one_stuck==1)
					)
					and
					(
						(gear_two_pos==0)
						or (gear_two_stuck==1)
					)
					and
					(
						(gear_three_pos==0)
						or (gear_three_stuck==1)
					)
				)
			)
			{
				#gear stay on place
				if (abs(switch_pos)>0)
				{
					way_to=(-switch_pos)/abs(switch_pos);
					switch_pos=switch_pos+0.3*way_to;
					if (((way_to>0) and (switch_pos>0)) or ((way_to<0) and (switch_pos<0)))
					{
						setprop("instrumentation/gear-control/switch-pos-norm", 0);
					}
					else
					{
						setprop("instrumentation/gear-control/switch-pos-norm", switch_pos);
					}
				}
				else
				{
					if (fix_pos>0)
					{
						fix_pos=fix_pos-0.3;
						if (fix_pos<=0)
						{
							setprop("instrumentation/gear-control/fix-pos-norm", 0);
							clicksound();
						}
						else
						{
							setprop("instrumentation/gear-control/fix-pos-norm", fix_pos);
						}
					}
				}
			}
		}
		if (
			(pump==1)
			and (valve_press==0.8)
			and (left_handle_pos==0)
			and (right_handle_pos==0)
		)
		{
			setprop("fdm/jsbsim/gear/gear-cmd-norm-real", gear_down_real);
		}
		settimer(gearcontrol, 0.1);
	}

# set startup configuration
init_gear_control = func
{
	setprop("instrumentation/gear-control/serviceable", 1);
	setprop("instrumentation/gear-control/switch-pos-norm", 0);
	setprop("instrumentation/gear-control/fix-pos-norm", 0);
}

init_gear_control();

geartoredsound = func
	{
		setprop("sounds/gears-tored/on", 1);
		settimer(geartoredsoundoff, 0.3);
	}

geartoredsoundoff = func
	{
		setprop("sounds/gears-tored/on", 0);
	}

gear_touch_down = func
	{
		setprop("sounds/gears-down/on", 1);
		settimer(end_gear_touch_down, 3);
	}

end_gear_touch_down = func
	{
		setprop("sounds/gears-down/on", 0);
	}

# start gear control process first time
gearcontrol ();

#Gear move process
#--------------------------------------------------------------------

timedhmove = func (property_name, control_name, move_time)
	{
		pos=getprop(property_name);
		set_pos=getprop(control_name);
		if (
			(pos == nil)
			or (set_pos == nil)
		)
		{
	 		return (0); 
		}
		if (pos!=set_pos)
		{
			way_to=abs(set_pos-pos)/(set_pos-pos);
			pos=pos+0.1/move_time*way_to;
			if (((way_to>0) and (pos>set_pos)) or ((way_to<0) and (pos<set_pos)))
			{
				pos=set_pos;
				setprop(property_name, set_pos);
				interpolate(property_name~"-inter", set_pos, 0);
			}
			else
			{
				setprop(property_name, pos);
				interpolate(property_name~"-inter", pos, 0.1);
			}
		}
 		return (1); 
	}


# helper 
stop_gearmove = func 
	{
	}

gearmove = func 
	{
		# check state
		in_service = getprop("processes/gear-move/enabled" );
		if (in_service == nil)
		{
			stop_gearmove();
	 		return ( settimer(gearmove, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearmove();
			return ( settimer(gearmove, 0.1) ); 
		}
		# get gear values
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		gear_one_stuck=getprop("fdm/jsbsim/gear/unit[0]/stuck");
		gear_two_stuck=getprop("fdm/jsbsim/gear/unit[1]/stuck");
		gear_three_stuck=getprop("fdm/jsbsim/gear/unit[2]/stuck");
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		gear_command_real=getprop("fdm/jsbsim/gear/gear-cmd-norm-real");
		gear_common_pos=getprop("fdm/jsbsim/gear/gear-pos-norm");
		speed=getprop("velocities/airspeed-kt");
		if (
			(gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
			or (gear_one_tored==nil)
			or (gear_two_tored==nil)
			or (gear_three_tored==nil)
			or (gear_one_stuck==nil)
			or (gear_two_stuck==nil)
			or (gear_three_stuck==nil)
			or (gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
			or (gear_command_real==nil)
			or (gear_common_pos==nil)
			or (speed==nil)
		)
		{
			stop_gearmove();
			return ( settimer(gearmove, 0.1) ); 
		}
		if (
			((gear_one_tored==0) and (gear_one_stuck==0))
			or ((gear_two_tored==0) and (gear_two_stuck==0))
			or ((gear_three_tored==0) and (gear_three_stuck==0))
		)
		{
			setprop("processes/gear-move/sound-enabled", 1);
		}
		else
		{
			setprop("processes/gear-move/sound-enabled", 0);
		}
		speed_km=speed*1.852;
		timedhmove("fdm/jsbsim/gear/gear-pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
		if (gear_one_tored==0)
		{
			if (gear_one_stuck==0)
			{
				timedhmove("fdm/jsbsim/gear/unit[0]/pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 4.2);
				timedhmove("gear/gear[0]/position-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 4.2);
				if (
					(speed_km>375) 
					and (gear_one_pos>0)
					and (gear_command_real<gear_one_pos)
				)
				{
					if (gear_command_real<gear_one_pos)
					{
						gearstuck(0, 1);
					}
					else
					{
						gearstuck(0, 0);
					}
				}
			}
			else
			{
				if (gear_command_real>gear_one_pos)
				{
					timedhmove("fdm/jsbsim/gear/unit[0]/pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5.2);
					timedhmove("gear/gear[0]/position-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5.2);
				}
				if (gear_one_pos==1)
				{
					setprop("fdm/jsbsim/gear/unit[0]/stuck", 0);
				}
			}
		}
		if (gear_two_tored==0)
		{
			if (gear_two_stuck==0)
			{
				timedhmove("fdm/jsbsim/gear/unit[1]/pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 4.8);
				timedhmove("gear/gear[1]/position-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 4.8);
				if (
					(speed_km>355) 
					and (gear_two_pos>0)
					and (gear_command_real<gear_two_pos)
				)
				{
					if (gear_command_real<gear_two_pos)
					{
						gearstuck(1, 1);
					}
					else
					{
						gearstuck(2, 0);
					}
				}
			}
			else
			{
				if (gear_command_real>gear_two_pos)
				{
					timedhmove("fdm/jsbsim/gear/unit[1]/pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
					timedhmove("gear/gear[1]/position-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
				}
				if (gear_two_pos==1)
				{
					setprop("fdm/jsbsim/gear/unit[1]/stuck", 0);
				}
			}
		}
		if (gear_three_tored==0)
		{
			if (gear_three_stuck==0)
			{
				timedhmove("fdm/jsbsim/gear/unit[2]/pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
				timedhmove("gear/gear[2]/position-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
				if (
					(speed_km>350) 
					and (gear_three_pos>0)
					and (gear_command_real<gear_three_pos)
				)
				{
					if (gear_command_real<gear_three_pos)
					{
						gearstuck(2, 1);
					}
					else
					{
						gearstuck(2, 0);
					}
				}
			}
			else
			{
				if (gear_command_real>gear_three_pos)
				{
					timedhmove("fdm/jsbsim/gear/unit[2]/pos-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
					timedhmove("gear/gear[2]/position-norm", "fdm/jsbsim/gear/gear-cmd-norm-real", 5);
				}
				if (gear_three_pos==1)
				{
					setprop("fdm/jsbsim/gear/unit[2]/stuck", 0);
				}
			}
		}
		settimer(gearmove, 0.1);
	}

gearstuck = func (gear_num, sounded)
	{
		setprop("fdm/jsbsim/gear/unit["~gear_num~"]/stuck", 1);
		if (sounded==1)
		{
			setprop("sounds/gears-stuck/on", 1);
		}
		settimer(gearstucksoundoff, 1);
	}

gearstucksoundoff = func
	{
		setprop("sounds/gears-stuck/on", 0);
	}

# set startup configuration
init_gearmove = func
{
	setprop("processes/gear-move/enabled", 1);
	setprop("processes/gear-move/sound-enabled", 1);
	setprop("sounds/gears-stuck/on", 0);
}

init_gearmove();

gearmove();

#--------------------------------------------------------------------
# Gear indicator

# helper 
stop_gearindicator = func 
	{
		setprop("instrumentation/gear-indicator/green-light-norm", 0);
		setprop("instrumentation/gear-indicator/red-light-norm", 0);
	}

gearindicator = func 
	{
		# check state
		in_service = getprop("instrumentation/gear-indicator/serviceable" );
		if (in_service == nil)
		{
			stop_gearindicator();
	 		return ( settimer(gearindicator, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearindicator();
		 	return ( settimer(gearindicator, 0.1) ); 
		}
		#get gear value
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		# get instrumentation values	
		red_pos=getprop("instrumentation/gear-indicator/red-pos-norm");
		green_pos=getprop("instrumentation/gear-indicator/green-pos-norm");
		button_check_pos=getprop("instrumentation/gear-indicator/button-check/switch-pos-norm");
		#get bus value
		bus=getprop("systems/electrical-real/bus");
		if (
			(gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
			or (gear_one_tored==nil)
			or (gear_two_tored==nil)
			or (gear_three_tored==nil)
			or (red_pos==nil)
			or (green_pos==nil)
			or (button_check_pos==nil)
			or (bus==nil)
		)
		{
			stop_gearindicator();
			return ( settimer(gearindicator, 0.1) ); 
		}
		switchmove("instrumentation/gear-indicator", "dummy/dummy");
		switchmove("instrumentation/gear-indicator/button-check", "dummy/dummy");
		if (bus==0)
		{
			setprop("instrumentation/gear-indicator/middle-up", 0);
			setprop("instrumentation/gear-indicator/left-up", 0);
			setprop("instrumentation/gear-indicator/right-up", 0);
			setprop("instrumentation/gear-indicator/middle-down", 0);
			setprop("instrumentation/gear-indicator/left-down", 0);
			setprop("instrumentation/gear-indicator/right-down", 0);
		}
		else
		{
			setprop("instrumentation/gear-indicator/middle-up", (((gear_one_pos==0) or (button_check_pos==1))) and (gear_one_tored==0));
			setprop("instrumentation/gear-indicator/left-up", (((gear_two_pos==0) or (button_check_pos==1))) and (gear_two_tored==0));
			setprop("instrumentation/gear-indicator/right-up", (((gear_three_pos==0) or (button_check_pos==1))) and (gear_three_tored==0));
			setprop("instrumentation/gear-indicator/middle-down", (((gear_one_pos==1) or (button_check_pos==1))) and (gear_one_tored==0));
			setprop("instrumentation/gear-indicator/left-down", (((gear_two_pos==1) or (button_check_pos==1))) and (gear_two_tored==0));
			setprop("instrumentation/gear-indicator/right-down", (((gear_three_pos==1) or (button_check_pos==1))) and (gear_three_tored==0));
		}
		settimer(gearindicator, 0.1);
	}

# set startup configuration
init_gearindicator = func
{
	setprop("instrumentation/gear-indicator/serviceable", 1);
	switchinit("instrumentation/gear-indicator", 1, "dummy/dummy");
	switchinit("instrumentation/gear-indicator/button-check", 0, "dummy/dummy");
	setprop("instrumentation/gear-indicator/red-pos-norm", 0.5);
	setprop("instrumentation/gear-indicator/green-pos-norm", 0.5);
	setprop("instrumentation/gear-indicator/middle-up", 0);
	setprop("instrumentation/gear-indicator/left-up", 0);
	setprop("instrumentation/gear-indicator/right-up", 0);
	setprop("instrumentation/gear-indicator/middle-down", 0);
	setprop("instrumentation/gear-indicator/left-down", 0);
	setprop("instrumentation/gear-indicator/right-down", 0);
}

init_gearindicator();

# start gear indicator process first time
gearindicator ();

#--------------------------------------------------------------------
# Flaps lamp

# helper 
stop_flapslamp = func 
	{
		setprop("instrumentation/flaps-lamp/lamp-ligth-norm", 0);
	}

flapslamp = func 
	{
		# check power
		in_service = getprop("instrumentation/flaps-lamp/serviceable" );
		if (in_service == nil)
		{
			stop_flapslamp();
	 		return ( settimer(flapslamp, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_flapslamp();
		 	return ( settimer(flapslamp, 0.1) ); 
		}
		# get flaps value
		flaps_pos = getprop("surface-positions/flap-pos-norm");
		# get bus value
		bus=getprop("systems/electrical-real/bus");
		tored = getprop("fdm/jsbsim/fcs/flap-tored");
		if ((flaps_pos == nil) or (bus==nil) or (tored==nil))
		{
			stop_flapslamp();
	 		return ( settimer(flapslamp, 0.1) ); 
		}
		if ((bus==0) or (tored==1))
		{
			stop_flapslamp();
	 		return ( settimer(flapslamp, 0.1) ); 
		}
		lamp_light=0;
		if (flaps_pos>0) 
		{
			lamp_light=0.5;
		}
		if (flaps_pos==1) 
		{
			lamp_light=1;
		}
		setprop("instrumentation/flaps-lamp/lamp-ligth-norm", lamp_light);
		settimer(flapslamp, 0.1);
  }

# set startup configuration
init_flapslamp = func
{
	setprop("instrumentation/flaps-lamp/serviceable", 1);
	setprop("instrumentation/flaps-lamp/lamp-ligth-norm", 0);
}

init_flapslamp();

# start flaps lamp process first time
flapslamp ();

#--------------------------------------------------------------------
# Fuelometer and fuelometer lamp

# helper 
stop_fuelometer = func 
	{
		setprop("instrumentation/fuelometer/lamp-ligth-norm", 0);
	}

fuelometer = func 
	{
		# check power
		in_service = getprop("instrumentation/fuelometer/serviceable" );
		if (in_service == nil)
		{
			stop_fuelometer();
	 		return ( settimer(fuelometer, 10) ); 
		}
		if ( in_service != 1 )
		{
			stop_fuelometer();
		 	return ( settimer(fuelometer, 10) ); 
		}
		# get fuel values
		fuel_pos_zero = getprop("consumables/fuel/tank[0]/level-lbs");
		fuel_pos_one = getprop("consumables/fuel/tank[1]/level-lbs");
		fuel_pos_two = getprop("consumables/fuel/tank[2]/level-lbs");
		fuel_pos_three = getprop("consumables/fuel/tank[3]/level-lbs");
		fuel_pos_four = getprop("consumables/fuel/tank[4]/level-lbs");
		fuel_control_pos=getprop("instrumentation/switches/fuel-control/switch-pos-norm");
		fuel_control_set_pos=getprop("instrumentation/switches/fuel-control/set-pos");
		third_tank_pump=getprop("systems/electrical-real/outputs/third-tank-pump/volts-norm");
		# get bus value
		bus=getprop("systems/electrical-real/bus");
		if (
			(fuel_pos_zero == nil)
			or (fuel_pos_one == nil)  
			or (fuel_pos_two == nil)
			or (fuel_pos_three == nil)
			or (fuel_pos_four == nil)
			or (fuel_control_pos == nil)
			or (fuel_control_set_pos == nil)      
			or (third_tank_pump == nil)  
			or (bus==nil)
		)
		{
			stop_fuelometer();
	 		return ( settimer(fuelometer, 10) ); 
		}
		if (bus==0)
		{
			setprop("instrumentation/fuelometer/fuel-level-lbs", 0);
			stop_fuelometer();
	 		return ( settimer(fuelometer, 10) ); 
		}
		if (fuel_control_pos==fuel_control_set_pos)
		{
			if (fuel_control_pos==0)
			{
				if (third_tank_pump==0)
				{
					fuel_result=fuel_pos_one*0.453;
				}
				else
				{
					fuel_result=(fuel_pos_three+fuel_pos_four)*0.453;
				}
			}
			else
			{
				fuel_result=fuel_pos_two*0.453;
			}
			setprop("instrumentation/fuelometer/fuel-level-litres", fuel_result);
		}
		lamp_light=0;
		if (fuel_pos_one<300) 
		{
			lamp_light=1;
		}
		setprop("instrumentation/fuelometer/lamp-ligth-norm", lamp_light);
		settimer(fuelometer, 10);
  }

# set startup configuration

init_fuelometer = func 
{
	setprop("instrumentation/fuelometer/serviceable", 1);
	setprop("instrumentation/fuelometer/lamp-ligth-norm", 0);
	setprop("instrumentation/fuelometer/fuel-level-lbs", 0);
}

init_fuelometer();

# start fuel lamp process first time
fuelometer ();

#--------------------------------------------------------------------
# Altimeter lamp

# helper 
stop_altlamp = func 
	{
		setprop("instrumentation/altimeter-lamp/lamp-ligth-norm", 0);
	}

altlamp = func 
	{
		# check power
		in_service = getprop("instrumentation/altimeter-lamp/serviceable" );
		if (in_service == nil)
		{
			stop_altlamp();
	 		return ( settimer(altlamp, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_altlamp();
		 	return ( settimer(altlamp, 0.1) ); 
		}
		# get altitude and electrical bus values
		alt_pos = getprop("fdm/jsbsim/position/h-sl-meters");		
		bus=getprop("systems/electrical-real/bus");
		if ((alt_pos == nil) or (bus==nil))
		{
			stop_altlamp();
	 		return ( settimer(altlamp, 0.1) ); 
		}
		lamp_light=0;
		if ((alt_pos<250) and (bus==1))
		{
			lamp_light=1;
		}
		setprop("instrumentation/altimeter-lamp/lamp-ligth-norm", lamp_light);
		settimer(altlamp, 0.1);
	}

# set startup configuration
init_altlamp = func 
{
	setprop("instrumentation/altimeter-lamp/serviceable", 1);
	setprop("instrumentation/altimeter-lamp/lamp-ligth-norm", 0);
}

init_altlamp();

# start altimeter lamp process first time
altlamp ();

#--------------------------------------------------------------------
# Gear caution lamp

# helper 
stop_gearlamp = func 
	{
		setprop("instrumentation/gear-lamp/lamp-ligth-norm", 0);
	}

gearlamp = func 
	{
		# check power
		in_service = getprop("instrumentation/gear-lamp/serviceable" );
		if (in_service == nil)
		{
			stop_gearlamp();
	 		return ( settimer(gearlamp, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearlamp();
		 	return ( settimer(gearlamp, 0.1) ); 
		}
		# get altitude values
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		flaps_pos=getprop("fdm/jsbsim/fcs/flap-pos-norm");
		#get bus value
		bus=getprop("systems/electrical-real/bus");
		if (
			(gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
			or (flaps_pos==nil)
			or (bus==nil)
		)
		{
			stop_gearlamp();
	 		return ( settimer(gearlamp, 0.1) ); 
		}
		if (bus==0)
		{
			stop_gearlamp();
	 		return ( settimer(gearlamp, 0.1) ); 
		}
		lamp_light=0;
		if (
			(flaps_pos>0) 
			and 
			(
				(gear_one_pos!=1)
				or (gear_two_pos!=1)
				or (gear_three_pos!=1)
			)
		)
		{
			lamp_light=1;
		}
		setprop("instrumentation/gear-lamp/lamp-ligth-norm", lamp_light);
	  	settimer(gearlamp, 0.1);
	}

# set startup configuration
init_gearlamp = func 
{
	setprop("instrumentation/gear-lamp/serviceable", 1);
	setprop("instrumentation/gear-lamp/lamp-ligth-norm", 0);
};

init_gearlamp();

# start gear lamp process first time
gearlamp ();

#--------------------------------------------------------------------
# Cabin manometer

# helper 
stop_oxypressmeter = func 
	{
		setprop("instrumentation/oxygen-pressure-meter/lamp", 0);
	}

oxypressmeter = func 
	{
		# check power
		in_service = getprop("instrumentation/oxygen-pressure-meter/serviceable" );
		if (in_service == nil)
		{
			stop_oxypressmeter();
	 		return ( settimer(oxypressmeter, 6) ); 
		}
		if( in_service != 1 )
		{
			stop_oxypressmeter();
		 	return ( settimer(oxypressmeter, 6) ); 
		}
		# get cabin pressure
		pressure = getprop("instrumentation/manometer/cabin-pressure");
		# get oxygen value
		oxy_pos = getprop("consumables/oxygen/pressure-norm");
		if ((pressure == nil) or (oxy_pos == nil))
		{
			stop_oxypressmeter();
	 		return ( settimer(oxypressmeter, 6) ); 
		}
		oxy_on=0;
		#If cabin altitude is highter than 1km automatically put oxy mask on
		#and consume oxygen with speed ~1% per min
		if (pressure<26.4)
		{
			if (oxy_pos>0)
			{
				oxy_on=1;
				oxy_pos=oxy_pos-0.00033;
			}
		}
		setprop("instrumentation/oxygen-pressure-meter/oxygen-on", oxy_on);
		setprop("consumables/oxygen/pressure-norm", oxy_pos);
	  	settimer(oxypressmeter, 6);
	}

# set startup configuration
init_oxypressmeter = func 
{
	setprop("instrumentation/oxygen-pressure-meter/serviceable", 1);
	setprop("instrumentation/oxygen-pressure-meter/oxygen-on", 0);
	setprop("consumables/oxygen/pressure-norm", 0.75);
}

init_oxypressmeter();

# start oxygen pressure meter process first time
oxypressmeter ();

#--------------------------------------------------------------------
# Artifical horizon 

# helper 
stop_arthorizon = func 
	{
	}

arthorizon = func 
	{
		# check state
		in_service = getprop("instrumentation/artifical-horizon/serviceable" );
		if (in_service == nil)
		{
			stop_arthorizon();
			setprop("instrumentation/artifical-horizon/running", 0);
	 		return ( settimer(arthorizon, 0.1) ); 
		}
		if( in_service != 1 )
		{
			stop_arthorizon();
		 	return ( settimer(arthorizon, 0.1) ); 
		}
		# get orientation values
		roll_deg = getprop("orientation/roll-deg");
		pitch_deg = getprop("orientation/pitch-deg");
		#get pitch and roll change speed
		roll_speed = getprop("orientation/roll-rate-degps");
		pitch_speed = getprop("orientation/pitch-rate-degps");
		# get shown orientation values
		ind_roll_deg = getprop("instrumentation/artifical-horizon/indicated-roll-deg");
		ind_pitch_deg = getprop("instrumentation/artifical-horizon/indicated-pitch-deg");
		# get zero orientation values
		zero_roll_deg = getprop("instrumentation/artifical-horizon/zero-roll-deg");
		zero_pitch_deg = getprop("instrumentation/artifical-horizon/zero-pitch-deg");
		# get switch value
		switch_pos = getprop("instrumentation/artifical-horizon/switch-pos-norm");
		com_status = getprop("instrumentation/artifical-horizon/status-command");
		#get electrical power
		power=getprop("systems/electrical-real/outputs/horizon/on");
		if ((roll_deg == nil) or (pitch_deg == nil) or (roll_speed == nil) or (pitch_speed == nil) or (ind_roll_deg == nil) or (ind_pitch_deg == nil) or (zero_roll_deg == nil) or (zero_pitch_deg == nil) or (switch_pos == nil) or (power==nil))
		{
			stop_arthorizon();
	 		return ( settimer(arthorizon, 0.1) ); 
		}
		switchmove("instrumentation/artifical-horizon", "dummy/dummy");
		if (power==1)
		{
			if (switch_pos==1)
			{
				#If button pressed device move zero to current degrees in ~5 second
				zero_roll_deg=(zero_roll_deg*4+roll_deg)/5;
				zero_pitch_deg=(zero_pitch_deg*4+pitch_deg)/5;
			}
			else
			{
				#If maneur is too fast it slightly distort degree values
				if (abs(roll_speed)>10.0)
				{
					zero_roll_deg=zero_roll_deg+0.001*roll_speed;
				}
				if (abs(pitch_speed)>10)
				{
					zero_pitch_deg=zero_pitch_deg+0.001*pitch_speed;
				}
			}
			ind_roll_deg=-zero_roll_deg+roll_deg;
			ind_pitch_deg=-zero_pitch_deg+pitch_deg;
			setprop("instrumentation/artifical-horizon/indicated-roll-deg", ind_roll_deg);
			setprop("instrumentation/artifical-horizon/indicated-pitch-deg", ind_pitch_deg);
			setprop("instrumentation/artifical-horizon/zero-roll-deg", zero_roll_deg);
			setprop("instrumentation/artifical-horizon/zero-pitch-deg", zero_pitch_deg);
		}
	  	settimer(arthorizon, 0.1);
	}

# set startup configuration
init_arthorizon = func 
{
	setprop("instrumentation/artifical-horizon/indicated-roll-deg", 0);
	setprop("instrumentation/artifical-horizon/indicated-pitch-deg", 0);
	setprop("instrumentation/artifical-horizon/zero-roll-deg", 0);
	setprop("instrumentation/artifical-horizon/zero-pitch-deg", 0);
	switchinit("instrumentation/artifical-horizon", 0, "dummy/dummy");
	setprop("instrumentation/artifical-horizon/offset", 0);
	setprop("instrumentation/artifical-horizon/serviceable", 1);
}

init_arthorizon();

# start artifical horizon process first time
arthorizon ();

#----------------------------------------------------------------------
#Gyrocompass

# helper 
stop_gyrocompass = func 
	{
	}

gyrocompass = func 
	{
		# check state
		in_service = getprop("instrumentation/gyrocompass/serviceable" );
		if (in_service == nil)
		{
			stop_gyrocompass();
	 		return ( settimer(gyrocompass, 0.1) ); 
		}
		if( in_service != 1 )
		{
			stop_gyrocompass();
		 	return ( settimer(gyrocompass, 0.1) ); 
		}
		#get gyrocompass values
		gyrocomp_status = getprop("instrumentation/gyrocompass/status");
		gyrocomp_com_status = getprop("instrumentation/gyrocompass/status-command");
		head_deg=getprop("orientation/heading-deg");
		head_magnetic=getprop("orientation/heading-magnetic-deg");
		ind_head_deg = getprop("instrumentation/gyrocompass/indicated-heading-deg");
		zero_head_deg = getprop("instrumentation/gyrocompass/zero-heading-deg");
		offset=getprop("instrumentation/gyrocompass/offset");
		switch_pos = getprop("instrumentation/gyrocompass/switch-pos-norm");
		#get electrical power
		power=getprop("systems/electrical-real/outputs/horizon/on");
		if ((switch_pos==nil) or (head_deg==nil) or (head_magnetic==nil) or (ind_head_deg==nil) or (zero_head_deg==nil) or (offset==nil) or  (power==nil))
		{
			stop_gyrocompass();
			setprop("instrumentation/gyrocompass/error", 1);
	 		return ( settimer(gyrocompass, 0.1) ); 
		}
		switchmove("instrumentation/gyrocompass", "dummy/dummy");
		if (power==1)
		{
			if (switch_pos==1)
			{
				#If button pressed device move zero to real zero in ~5 second
				zero_head_deg=(zero_head_deg*4)/5;
			}
			else
			{
				#If maneur is too fast it slightly distort degree values
				#But int not include degree flip from -180 to +180
				if ((abs(head_deg-head_magnetic)>20.0) and (abs(head_deg-head_magnetic)<150))
				{
					zero_head_deg=zero_head_deg+0.00005*(head_deg-head_magnetic);
				}
			}
			ind_head_deg=-zero_head_deg+head_deg+offset;
			setprop("instrumentation/gyrocompass/indicated-heading-deg", ind_head_deg);
			setprop("instrumentation/gyrocompass/zero-heading-deg", zero_head_deg);
		}
	  	settimer(gyrocompass, 0.1);
	}

init_gyrocompass = func 
{
	setprop("instrumentation/gyrocompass/indicated-heading-deg", 0);
	setprop("instrumentation/gyrocompass/zero-heading-deg", 0);
	switchinit("instrumentation/gyrocompass", 0, "dummy/dummy");
	setprop("instrumentation/gyrocompass/offset", 0);
	setprop("instrumentation/gyrocompass/serviceable", 1);
}

init_gyrocompass();

gyrocompass();
#--------------------------------------------------------------------
# Flaps breaks process

# helper 
stop_flapsbreaksprocess = func 
	{
	}

flapsbreaksprocess = func 
	{
		# get flaps values
		flaps_pos_deg = getprop("fdm/jsbsim/fcs/flap-pos-deg");
		tored = getprop("fdm/jsbsim/fcs/flap-tored");
		#get speed value
		speed=getprop("velocities/airspeed-kt");
		if (
			(flaps_pos_deg == nil)
			or (tored==nil)
			or (speed==nil)
		)
		{
			stop_flapsbreaksprocess();
			return ( settimer(flapsbreaksprocess, 0.1) ); 
		}
		if ((tored==0) and (flaps_pos_deg>5))
		{
			speed_km=speed*1.852;
			#max 450 km\h on 20 deg, 350 on 55 deg
			speed_limit=450-((flaps_pos_deg-20)/(55-20))*(450-350);
			setprop("fdm/jsbsim/fcs/flap-speed-limit", speed_limit);
			if ((speed_km>speed_limit) and (speed_limit>0))
			{
				tored=1;
				setprop("fdm/jsbsim/fcs/flap-tored", 1);
				setprop("fdm/jsbsim/fcs/flap-cmd-norm-real", 0);
				setprop("fdm/jsbsim/fcs/flap-pos-deg", 0);
				setprop("fdm/jsbsim/fcs/flap-pos-norm", 0);
				setprop("ai/submodels/left-flap-drop", 1);
				setprop("ai/submodels/right-flap-drop", 1);
				flapstoredsound();
			}
		}
		flaps_impact=getprop("ai/submodels/left-flap-impact");
		if (flaps_impact!=nil)
		{
			if (flaps_impact!="")
			{
				setprop("ai/submodels/left-flap-impact", "");
				flaps_touch_down();
			}
		}
		flaps_impact=getprop("ai/submodels/right-flap-impact");
		if (flaps_impact!=nil)
		{
			if (flaps_impact!="")
			{
				setprop("ai/submodels/right-flap-impact", "");
				flaps_touch_down();
			}
		}
		left_flap_drop=getprop("ai/submodels/left-flap-drop");
		right_flap_drop=getprop("ai/submodels/right-flap-drop");
		if ((left_flap_drop!=nil) and (right_flap_drop!=nil))
		{
			if ((tored==0) and ((left_flap_drop==1) or (right_flap_drop==1)))
			{
				setprop("ai/submodels/left-flap-drop", 0);
				setprop("ai/submodels/right-flap-drop", 0);
			}
		}
		settimer(flapsbreaksprocess, 0.1);
	}

# set startup configuration
init_flapsbreaksprocess = func 
{
	setprop("fdm/jsbsim/fcs/flap-tored", 0);
}

init_flapsbreaksprocess();


flapstoredsound = func
	{
		setprop("sounds/flaps-tored/on", 1);
		settimer(flapstoredsoundoff, 0.3);
	}

flapstoredsoundoff = func
	{
		setprop("sounds/flaps-tored/on", 0);
	}

flaps_touch_down = func
	{
		setprop("sounds/flaps-down/on", 1);
		settimer(end_flaps_touch_down, 3);
	}

end_flaps_touch_down = func
	{
		setprop("sounds/flaps-down/on", 0);
	}

flapsbreaksprocess();

#--------------------------------------------------------------------
# Flaps control

# helper 
stop_flapscontrol = func 
	{
	}

flapscontrol = func 
	{
		# check power
		in_service = getprop("instrumentation/flaps-control/serviceable" );
		if (in_service == nil)
		{
			stop_flapscontrol();
	 		return ( settimer(flapscontrol, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_flapscontrol();
		 	return ( settimer(flapscontrol, 0.1) ); 
		}
		# get flaps values
		flaps_pos = getprop("fdm/jsbsim/fcs/flap-pos-norm");
		tored = getprop("fdm/jsbsim/fcs/flap-tored");
		flaps_control_pos = getprop("controls/flight/flaps");
		# get instrumentation values	
		switch_pos=getprop("instrumentation/flaps-control/switch-pos-norm");
		fix_pos=getprop("instrumentation/flaps-control/fix-pos-norm");
		valve_press=getprop("instrumentation/flaps-valve/pressure-norm");
		#get pump value
		pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		engine_running=getprop("engines/engine/running");
		set_generator=getprop("controls/switches/generator");
		if (
			(flaps_pos == nil)
			or (tored==nil)
			or (flaps_control_pos == nil)
			or (switch_pos == nil)
			or (fix_pos == nil)
			or (valve_press==nil)
			or (pump==nil)
			or (engine_running==nil)
			or (set_generator==nil)
		)
		{
			stop_flapscontrol();
	 		return ( settimer(flapscontrol, 0.1) ); 
		}
		if ((abs(flaps_pos-flaps_control_pos))>0.0001)
		{
			if (flaps_control_pos<flaps_pos)
			{
				set_switch_pos=-1;
			}
			else
			{
				set_switch_pos=flaps_control_pos;
			}
			if (!(switch_pos==set_switch_pos))
			{
				way_to=abs(set_switch_pos-switch_pos)/(set_switch_pos-switch_pos);
				switch_pos=switch_pos+0.05*way_to;
				if (
					((way_to>0) and (switch_pos>set_switch_pos)) 
					or ((way_to<0) and (switch_pos<set_switch_pos))
				)
				{
					switch_pos=set_switch_pos;
					setprop("instrumentation/flaps-control/switch-pos-norm", set_switch_pos);
				}
				else
				{
					setprop("instrumentation/flaps-control/switch-pos-norm", switch_pos);
				}
			}
			else
			{
				if ((pump==1) and (valve_press==0.8) and (tored==0))
				{
					if ((engine_running==1) and (set_generator==1))
					{
						setprop("fdm/jsbsim/fcs/flap-cmd-norm-real", switch_pos);
					}
					else
					{
						setprop("instrumentation/switches/pump/set-pos", 0);
					}
				}
			}
		}
		else
		{
			if ((abs(switch_pos))>0)
			{
				set_switch_pos=0;
				way_to=abs(set_switch_pos-switch_pos)/(set_switch_pos-switch_pos);
				switch_pos=switch_pos+0.075*way_to;
				if (((way_to>0) and (switch_pos>set_switch_pos)) or ((way_to<0) and (switch_pos<set_switch_pos)))
				{
					switch_pos=set_switch_pos;
					setprop("instrumentation/flaps-control/switch-pos-norm", set_switch_pos);
				}
				else
				{
					setprop("instrumentation/flaps-control/switch-pos-norm", switch_pos);
				}
			}
		}
		if (((abs(switch_pos+1))<0.02) or ((abs(switch_pos))<0.02) or ((abs(switch_pos-0.36))<0.02) or ((abs(switch_pos-1))<0.02))
		{
			if (fix_pos==0)
			{
				setprop("instrumentation/flaps-control/fix-pos-norm", 1);
				clicksound();
			}
		}
		else
		{
			if (fix_pos==1)
			{
				setprop("instrumentation/flaps-control/fix-pos-norm", 0);
			}
		}
		settimer(flapscontrol, 0.1);
	}

# set startup configuration
init_flapscontrol = func 
{
	setprop("instrumentation/flaps-control/serviceable", 1);
	setprop("instrumentation/flaps-control/switch-pos-norm", 0);
	setprop("instrumentation/flaps-control/fix-pos-norm", 1);
	setprop("instrumentation/flaps-control/one", 1);
}

init_flapscontrol();

# start flaps control process first time
flapscontrol ();

#--------------------------------------------------------------------
# Stop engine control

# helper 
stop_stopcontrol = func 
	{
	}

stopcontrol = func 
	{
		# check power
		in_service = getprop("instrumentation/stop-control/serviceable" );
		if (in_service == nil)
		{
			stop_stopcontrol();
	 		return ( settimer(stopcontrol, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_stopcontrol();
		 	return ( settimer(stopcontrol, 0.1) ); 
		}
		switchmove("instrumentation/stop-control", "dummy/dummy");
  		settimer(stopcontrol, 0.1);
	}

# set startup configuration
init_stopcontrol = func 
{
	setprop("instrumentation/stop-control/serviceable", 1);
	switchinit("instrumentation/stop-control", 1, "dummy/dummy");
}

init_stopcontrol();

# start stop control process first time
stopcontrol ();

#--------------------------------------------------------------------
# Speed brake control

# helper 
stop_speedbrakecontrol = func 
	{
		setprop("instrumentation/speed-brake-control/light-pos-norm", 0);
	}

speedbrakecontrol = func 
	{
		switchfeedback("instrumentation/speed-brake-control", "controls/flight/speedbrake");
		switchmove("instrumentation/speed-brake-control", "controls/flight/speedbrake");
		# check power
		in_service = getprop("instrumentation/speed-brake-control/serviceable" );
		if (in_service == nil)
		{
			stop_speedbrakecontrol();
	 		return ( settimer(speedbrakecontrol, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_speedbrakecontrol();
		 	return ( settimer(speedbrakecontrol, 0.1) ); 
		}
		# get speed brake values
		brake_control_pos = getprop("instrumentation/speed-brake-control/switch-pos-norm");
		brake_pos = getprop("surface-positions/speedbrake-pos-norm");
		#get bus value
		bus=getprop("systems/electrical-real/bus");
		if ((brake_control_pos == nil) or (brake_pos == nil) or (bus == nil))
		{
			stop_speedbrakecontrol();
	 		return ( settimer(speedbrakecontrol, 0.1) );
		}
		if (bus==0)
		{
			stop_speedbrakecontrol();
		 	return ( settimer(speedbrakecontrol, 0.1) );
		}
		if  ((brake_control_pos==1) or (brake_control_pos==0))
		{
			setprop("fdm/jsbsim/fcs/speedbrake-cmd-norm-real", brake_control_pos);
		}
		setprop("instrumentation/speed-brake-control/light-pos-norm", brake_pos);
  		settimer(speedbrakecontrol, 0.1);
  }

# set startup configuration
init_speedbrakecontrol = func 
{
	setprop("instrumentation/speed-brake-control/serviceable", 1);
	switchinit("instrumentation/speed-brake-control", 0, "controls/flight/speedbrake");
	setprop("instrumentation/speed-brake-control/light-pos-norm", 0);
}

init_speedbrakecontrol();

# start speed brake control process first time
speedbrakecontrol ();

#--------------------------------------------------------------------
# Gas control

# helper 
stop_gascontrol = func 
	{
	}

gascontrol = func 
	{
		in_service = getprop("instrumentation/gas-control/serviceable");
		if (in_service == nil)
		{
			stop_gascontrol();
	 		return ( settimer(gascontrol, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gascontrol();
		 	return ( settimer(gascontrol, 0.1) ); 
		}
		switchmove("instrumentation/gas-control/brakes-button", "dummy/dummy");
		lock_pos=getprop("instrumentation/gas-control/lock/switch-pos-norm");
		fix_pos=getprop("instrumentation/gas-control/fix/switch-pos-norm");
		set_pos=getprop("controls/engines/engine/throttle");
		switch_pos=getprop("instrumentation/gas-control/switch-pos-norm");
		safer_pos=getprop("instrumentation/ignition-button/safer/switch-pos-norm");
		if ((lock_pos==nil) or (fix_pos==nil) or (set_pos==nil) or (switch_pos==nil) or (safer_pos==nil))
		{
			stop_gascontrol();
	 		return ( settimer(gascontrol, 0.1) ); 
		}
		if (safer_pos==1)
		{
			switchmove("instrumentation/gas-control/lock", "dummy/dummy");
		}
		else
		{
			switchback("instrumentation/gas-control/lock");
		}
		if ((switch_pos>0.1) and (safer_pos==1))
		{
			switchmove("instrumentation/gas-control/fix", "dummy/dummy");
		}
		else
		{
			switchback("instrumentation/gas-control/fix");
		}
		if (lock_pos==0)
		{
			if ((set_pos==switch_pos) or (safer_pos==0))
			{
				#get pitch orientation change speed value
				pitch_change_speed = getprop("orientation/pitch-rate-degps");
				if ((pitch_change_speed==nil)) 
				{
					stop_gascontrol();
					setprop("instrumentation/gas-control/error", 1);
			 		return ( settimer(gascontrol, 0.1) ); 
				}
				#if maneur is too fast it slightly distort gas switch position
				if (abs(pitch_change_speed)>5)
				{
					switch_pos=switch_pos+0.001*pitch_change_speed;
					set_pos=set_pos+0.001*pitch_change_speed;
				}
			}
			else
			{
				switch_pos=set_pos;
			}
			if ((fix_pos==1) and (switch_pos<0.04))
			{
				switch_pos=0.04;
			}				
			if ((fix_pos==1) and (set_pos<0.04))
			{
				set_pos=0.04;
			}				
		}
		else
		{
			set_pos=switch_pos;
		}
		#Joystick fix
		if (
			(switch_pos>0)
			and (switch_pos<0.01)
		)
		{
			switch_pos=0;
		}
		if (
			(set_pos>0)
			and (set_pos<0.01)
		)
		{
			set_pos=0;
		}
		setprop("instrumentation/gas-control/switch-pos-norm", switch_pos);
		setprop("controls/engines/engine/throttle", set_pos);
		settimer(gascontrol, 0.1);
	  }

# set startup configuration
init_gascontrol = func 
{
	setprop("instrumentation/gas-control/serviceable", 1);
	setprop("instrumentation/gas-control/switch-pos-norm", 0);
	switchinit("instrumentation/gas-control/lock", 1, "dummy/dummy");
	switchinit("instrumentation/gas-control/fix", 0, "dummy/dummy");
	switchinit("instrumentation/gas-control/brakes-button", 0, "dummy/dummy");
	setprop("controls/engines/engine/starter-command", 0);
}

init_gascontrol();

# start gas control process first time
gascontrol ();

#--------------------------------------------------------------------
# Ignition button

# helper 
stop_ignitionbutton = func 
	{
	}

ignitionbutton = func 
	{
		in_service = getprop("instrumentation/ignition-button/serviceable");
		if (in_service == nil)
		{
			stop_ignitionbutton();
	 		return ( settimer(ignitionbutton, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_ignitionbutton();
		 	return ( settimer(ignitionbutton, 0.1) ); 
		}
		safer_set_pos=getprop("instrumentation/ignition-button/safer/set-pos");
		safer_pos=getprop("instrumentation/ignition-button/safer/switch-pos-norm");
		button_pos=getprop("instrumentation/ignition-button/switch-pos-norm");
		starter_key=getprop("controls/engines/engine/starter-key");
		starter_command=getprop("controls/engines/engine/starter-command");
		if (
			(safer_set_pos==nil) 
			or (safer_pos==nil)
			or (button_pos==nil)
			or (starter_key==nil)
			or (starter_command==nil)
		)
		{
			stop_ignitionbutton();
	 		return ( settimer(ignitionbutton, 0.1) ); 
		}
		if (
			(starter_key==1) 
			or (starter_command==1)
		)
		{
			if (safer_pos==0)
			{
				starter_press=1;
			}
			else
			{
				starter_press=0;
				setprop("instrumentation/ignition-button/safer/set-pos", 0);
			}
		}
		else
		{
			starter_press=0;
			setprop("instrumentation/ignition-button/safer/set-pos", 1);
		}
		switchmove("instrumentation/ignition-button/safer", "dummy/dummy");
		setprop("instrumentation/ignition-button/set-pos", starter_press);
		switchmove("instrumentation/ignition-button", "controls/engines/engine/starter-pressed");
		settimer(ignitionbutton, 0.1);
	  }

# set startup configuration
init_ignitionbutton = func 
{
	setprop("instrumentation/ignition-button/serviceable", 1);
	switchinit("instrumentation/ignition-button", 0, "dummy/dummy");
	switchinit("instrumentation/ignition-button/safer", 1, "dummy/dummy");
	setprop("controls/engines/engine/starter-command", 0);
	setprop("controls/engines/engine/starter-key", 0);
	setprop("controls/engines/engine/starter-pressed", 0);
}

init_ignitionbutton();

# start gas control process first time
ignitionbutton ();

#--------------------------------------------------------------------
#Engine process

# helper 
stop_engineprocess = func 
	{
	}

engineprocess=func
	{
		in_service = getprop("processes/engine/on");
		if (in_service == nil)
		{
			stop_engineprocess();
	 		return ( settimer(engineprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_engineprocess();
		 	return ( settimer(engineprocess, 0.1) ); 
		}
		var tank=[0,0,0,0,0];
		var tank_selected=[0,0,0,0,0];
		switchmove("instrumentation/switches/fuel-control", "dummy/dummy");
		starter=getprop("controls/engines/engine/starter");
		starter_pressed=getprop("controls/engines/engine/starter-pressed");
		starter_time=getprop("engines/engine/starter-time");
		running=getprop("engines/engine/running");
		out_of_fuel=getprop("engines/engine/out-of-fuel");
		low_throttle_time=getprop("engines/engine/low-throttle-time");
		high_temperature_time=getprop("engines/engine/high-temperature-time");
		engine_n2=getprop("engines/engine/n2");
		engine_thrust=getprop("engines/engine/thrust_lb");
		engine_temperature=getprop("engines/engine/egt-degf");
		#To compaility wth FG previous versions
		if (engine_temperature==nil)
		{
			engine_temperature=getprop("engines/engine/egt_degf");
		}
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		gen_on=getprop("controls/switches/generator");
		pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		third_tank_pump=getprop("systems/electrical-real/outputs/third-tank-pump/volts-norm");
		fuel_control_pos=getprop("instrumentation/switches/fuel-control/switch-pos-norm");
		fuel_control_set_pos=getprop("instrumentation/switches/fuel-control/set-pos");
		tank[0]=getprop("consumables/fuel/tank[0]/level-gal_us");
		tank[1]=getprop("consumables/fuel/tank[1]/level-gal_us");
		tank[2]=getprop("consumables/fuel/tank[2]/level-gal_us");
		tank[3]=getprop("consumables/fuel/tank[3]/level-gal_us");
		tank[4]=getprop("consumables/fuel/tank[4]/level-gal_us");
		ignition_power=getprop("systems/electrical-real/outputs/ignition/on");
		ignition_power_time=getprop("engines/engine/ignition-power-time");
		if (
			(starter==nil)
			or (starter_pressed==nil)
			or (starter_time==nil)
			or (running==nil)
			or (out_of_fuel==nil)
			or (low_throttle_time==nil)
			or (high_temperature_time==nil)
			or (engine_n2==nil)
			or (engine_thrust==nil)
			or (engine_temperature==nil)
			or (pilot_g==nil)
			or (gen_on==nil)
			or (pump==nil)
			or (third_tank_pump==nil)
			or (fuel_control_pos==nil)
			or (fuel_control_set_pos==nil)
			or (tank[0]==nil)
			or (tank[1]==nil)
			or (tank[2]==nil)
			or (tank[3]==nil)
			or (tank[4]==nil)
			or (ignition_power==nil)
			or (ignition_power_time==nil)
		)
		{
			stop_engineprocess();
			setprop("engines/engine/error", 1);
	 		return ( settimer(engineprocess, 0.1) ); 
		}
		setprop("engines/engine/error", 0);
		if (fuel_control_pos==fuel_control_set_pos)
		{
			if (fuel_control_pos==1)
			{
				if ((tank[2]>0) and (pump>0))
				{
					setprop("consumables/fuel/tank[2]/selected", 1);
					tank_selected[2]=1;
					setprop("consumables/fuel/tank[1]/selected", 0);
					setprop("consumables/fuel/tank[3]/selected", 0);
					setprop("consumables/fuel/tank[4]/selected", 0);
					tank_selected[1]=0;
					tank_selected[3]=0;
					tank_selected[4]=0;
				}
				else
				{
					setprop("consumables/fuel/tank[2]/selected", 0);
					tank_selected[2]=0;
				}
			}
			if ((fuel_control_pos==0) or (tank[2]<=0))
			{
				if (third_tank_pump!=0)
				{
					if (tank[3]>0)
					{
						setprop("consumables/fuel/tank[3]/selected", 1);
						tank_selected[3]=1;
						setprop("consumables/fuel/tank[1]/selected", 0);
						setprop("consumables/fuel/tank[2]/selected", 0);
						tank_selected[1]=0;
						tank_selected[2]=0;
					}
					else
					{
						setprop("consumables/fuel/tank[3]/selected", 0);
						tank_selected[3]=0;
					}
					if (tank[4]>0)
					{
						setprop("consumables/fuel/tank[4]/selected", 1);
						tank_selected[4]=1;
						setprop("consumables/fuel/tank[1]/selected", 0);
						setprop("consumables/fuel/tank[2]/selected", 0);
						tank_selected[1]=0;
						tank_selected[2]=0;
					}
					else
					{
						setprop("consumables/fuel/tank[4]/selected", 0);
						tank_selected[4]=0;
					}
				}
				if ((third_tank_pump==0) or ((tank[3]<=0) and (tank[4]<=0)))
				{
					if ((tank[1]>0) and (pump>0))
					{
						setprop("consumables/fuel/tank[1]/selected", 1);
						tank_selected[1]=1;
					}
					else
					{
						setprop("consumables/fuel/tank[0]/selected", 0);
						tank_selected[1]=0;
					}
					setprop("consumables/fuel/tank[2]/selected", 0);
					setprop("consumables/fuel/tank[3]/selected", 0);
					setprop("consumables/fuel/tank[4]/selected", 0);
					tank_selected[2]=0;
					tank_selected[3]=0;
					tank_selected[4]=0;
				}
			}
		}
		if (tank[0]<1)
		{
			active_tanks=0;
			for (i=0; i<5; i+=1)
			{
				if (tank_selected[i]>0)
				{
					active_tanks=active_tanks+1;
				}
			}
			if (active_tanks>0)
			{
				for (i=0; i<5; i+=1)
				{
					if (tank_selected[i]>0)
					{
						tank[i]=tank[i]-(1-tank[0])/active_tanks;
						if (tank[i]<0)
						{
							tank[i]==0;
						}
						setprop("consumables/fuel/tank["~i~"]/level-gal_us", tank[i]);
					}
				}
				setprop("consumables/fuel/tank[0]/level-gal_us", 1);
			}
		}
		engine_temperature_degc=((engine_temperature-32)*5/9)/740*850;
		setprop("engines/engine/egt-degc", engine_temperature_degc);
		#get speed, ignition type, engine emergency brake, control switch and isolation valve values
		speed=getprop("velocities/airspeed-kt");
		ignition_type=getprop("controls/switches/ignition-type");
		brake_pos=getprop("instrumentation/stop-control/switch-pos-norm");
		switch_pos=getprop("instrumentation/gas-control/switch-pos-norm");
		valve_pos=getprop("engines/engine/isolation-valve");
		rpm=getprop("engines/engine/rpm");
		if (
			(speed==nil) 
			or (ignition_type==nil)
			or (brake_pos==nil)
			or (switch_pos==nil)
			or (valve_pos==nil)
			or (rpm==nil)
		)
		{
			stop_engineprocess();
			setprop("engines/engine/error", 2);
	 		return ( settimer(engineprocess, 0.1) ); 
		}
		setprop("engines/engine/error", 0);
		#On Earth ignition
		if (starter_pressed==1) 
		{
			if (
				(running==0) 
				and (switch_pos==0)
				and (brake_pos==0)
				and (valve_pos==0)
				and (gen_on==0)
			)
			{
				if (starter_time<10)
				{
					#one type of ingnition on earth and another in flight
					if ((speed<108) and (ignition_type==0) and (ignition_power==1))
					{
						setprop("controls/engines/engine/cutoff", 1);
						setprop("controls/engines/engine/cutoff-reason", "on Earth time<10 starter");
						setprop("controls/engines/engine/starter", 1);
						setprop("engines/engine/spoolup", 1);
						setprop("engines/engine/combustion", 0);
						starter_time=starter_time+0.1;
						setprop("engines/engine/starter-time", starter_time);
						rpm=(starter_time/10)*1000;
						setprop("engines/engine/rpm", rpm);
					}
					else
					{
						setprop("controls/engines/engine/cutoff", 1);
						setprop("controls/engines/engine/cutoff-reason", "on Earth time<10 no start");
						setprop("controls/engines/engine/starter", 0);
						setprop("controls/engines/engine/starter-command", 0);
						setprop("controls/engines/engine/starter-indicate", 0);
						setprop("engines/engine/starter-time", 0);
					}
				}
				else
				{
					if (starter_time<30)
					{
						if ((out_of_fuel==1) or (ignition_power==0))
						{
							setprop("controls/engines/engine/cutoff", 1);
							setprop("controls/engines/engine/cutoff-reason", "on Earth, time<30 out_of_fuel=1 or ignition_power=0");
							setprop("controls/engines/engine/starter", 0);
							setprop("controls/engines/engine/starter-command", 0);
							setprop("controls/engines/engine/starter-indicate", 0);
							setprop("engines/engine/starter-time", 0);
						}
						else
						{
							setprop("controls/engines/engine/cutoff", 0);
							setprop("controls/engines/engine/starter", 1);
							setprop("engines/engine/spoolup", 0);
							setprop("engines/engine/combustion", 1);
							starter_time=starter_time+0.1;
							setprop("engines/engine/starter-time", starter_time);
							rpm=1000;
							setprop("engines/engine/rpm", rpm);
						}
					}
					else
					{
						setprop("engines/engine/starter-time", 0);
						setprop("controls/engines/engine/starter-command", 0);
					}
				}
			}
			else
			{
				setprop("engines/engine/starter-time", 0);
				setprop("controls/engines/engine/starter-command", 0);
			}	
		}
		else
		{
			setprop("engines/engine/starter-time", 0);
		}
		#In flight ignition
		if (
			(running==0)
			and (brake_pos==0)
			and (valve_pos==0)
			and (ignition_type==1)
			and (out_of_fuel==0)
			and (ignition_power==1)
			and (speed>100)
			and (speed<300)
			and (gen_on==0)
		)
		{	
			if (abs(switch_pos*500-speed)<20)
			{
				if (starter_time<10)
				{
					#one type of ingnition on earth and another in flight
					setprop("controls/engines/engine/cutoff", 1);
					setprop("controls/engines/engine/cutoff-reason", "in flight starter_time<10");
					setprop("controls/engines/engine/starter", 1);
					setprop("engines/engine/combustion", 1);
					starter_time=starter_time+0.1;
					setprop("engines/engine/starter-time", starter_time);
					rpm=(1+starter_time/20)*1000;
					setprop("engines/engine/rpm", rpm);
				}
				else
				{
					if (starter_time<30)
					{
						setprop("controls/engines/engine/cutoff", 0);
						setprop("controls/engines/engine/starter", 1);
						setprop("engines/engine/combustion", 1);
						starter_time=starter_time+0.1;
						setprop("engines/engine/starter-time", starter_time);
						rpm=(1+starter_time/20)*1000;
						setprop("engines/engine/rpm", rpm);
					}
					else
					{
						setprop("controls/engines/engine/starter", 0);
						setprop("engines/engine/starter-time", 0);
						setprop("controls/engines/engine/starter-command", 0);
					}
				}
			}
			else
			{
				setprop("controls/engines/engine/cutoff", 1);
				setprop("controls/engines/engine/cutoff-reason", "in flight throttle shift");
				setprop("controls/engines/engine/starter", 0);
				setprop("engines/engine/starter-time", 0);
				setprop("controls/engines/engine/starter-command", 0);
			}
		}
		if (starter_time==0)
		{
			setprop("engines/engine/spoolup", 0);
			setprop("engines/engine/combustion", 0);
		}
		if (running==1) 
		{		
			if (out_of_fuel==1)
			{
				running=engine_stop("out of fuel");
			}
		}
		if (running==1) 
		{		
			if (brake_pos==1)
			{
				running=engine_stop("braked");
			}
		}
		if (running==1) 
		{		
			if (switch_pos==0)
			{
				#On fast fight low throttle fix must be switched on, otherwise engine switch off
				low_throttle_time=low_throttle_time+0.1+1*(speed/100);
				setprop("engines/engine/low-throttle-time", low_throttle_time);
				if (low_throttle_time>60)
				{
					running=engine_stop("low throttle");
				}
			}
			else
			{
				low_throttle_time=0;
				setprop("engines/engine/low-throttle-time", low_throttle_time);
			}
			if (engine_temperature_degc>825)
			{
				#Engine switch off if it goes on high temperature too long
				high_temperature_time=high_temperature_time+0.1;
				setprop("engines/engine/high-temperature-time", high_temperature_time);
				if (high_temperature_time>30)
				{
					running=engine_stop("high temperature "~engine_temperature_degc);
				}
			}
			else
			{
				setprop("engines/engine/high-temperature-time", 0);
			}
			if (ignition_power==1)
			{
				ignition_power_time=ignition_power_time+0.1;
				setprop("engines/engine/ignition-power-time", ignition_power_time);
			}
			else
			{
				setprop("engines/engine/ignition-power-time", 0);
			}
			if (ignition_power_time>60)
			{
				setprop("engines/engine/ignition-power-time", 0);
				setprop("instrumentation/switches/battery/set-pos", 0);
				setprop("instrumentation/switches/generator/set-pos", 0);
			}
			if (brake_pos>0)
			{
				set_throttle=switch_pos;
			}
			else
			{
				set_throttle=switch_pos*(1-brake_pos);
			}
			if (valve_pos==0)
			{
				set_throttle=0.3+(set_throttle*0.7);
				setprop("fdm/jsbsim/fcs/throttle-cmd-norm-real", set_throttle);
			}
			else
			{
				set_throttle=0.3+set_throttle*0.01;
				setprop("fdm/jsbsim/fcs/throttle-cmd-norm-real", set_throttle);
			}
			sound=((engine_n2-70)/30)*1.1;
			setprop("engines/engine/sound", sound);
			rpm=((engine_n2-70)/35)*15000;
			setprop("engines/engine/rpm", rpm);
		}
		else
		{
			setprop("fdm/jsbsim/fcs/throttle-cmd-norm-real", 0.3);
			setprop("engines/engine/sound", 0);
			if (starter_time==0)
			{
	 			rpm=rpm+(speed*2-rpm)/10;
				setprop("engines/engine/rpm", rpm);
			}
		}
		settimer(engineprocess, 0.1); 
	}


init_engineprocess = func 
{
	setprop("processes/engine/on", 1);
	setprop("engines/engine/stop", 0);
	setprop("engines/engine/starter-time", 0);
	setprop("engines/engine/low-throttle-time", 0);
	setprop("engines/engine/egt-degc", 0);
	setprop("engines/engine/high-temperature-time", 0);
	setprop("engines/engine/sound", 0);
	setprop("engines/engine/rpm", 0);
	setprop("engines/engine/ignition-power-time", 0);
	setprop("engines/engine/spoolup", 0);
	setprop("engines/engine/combustion", 0);
	switchinit("instrumentation/switches/fuel-control/", 0, "dummy/dummy");
}

init_engineprocess();

engine_stop = func(stop_reason)
	{
		setprop("engines/engine/stop-reason", stop_reason);
		setprop("engines/engine/high-temperature-time", 0);
		setprop("engines/engine/low-throttle-time", 0);
		setprop("controls/engines/engine/cutoff", 1);
		setprop("controls/engines/engine/cutoff-reason", "engine stop");
		setprop("engines/engine/stop", 1);
		settimer(end_engine_stop, 5);
		return (0);
	}

end_engine_stop = func
	{
		setprop("engines/engine/stop", 0);
	}

# start engine process first time
engineprocess ();

#--------------------------------------------------------------------

# Buster control and indicator

# helper 
stop_bustercontrol = func 
	{
		setprop("instrumentation/buster-indicator/indicated-pressure-norm", 0);
	}

bustercontrol = func 
	{
		# check power
		in_service = getprop("instrumentation/buster-control/serviceable" );
		if (in_service == nil)
		{
			stop_bustercontrol();
	 		return ( settimer(bustercontrol, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_bustercontrol();
		 	return ( settimer(bustercontrol, 0.1) ); 
		}
		# get aileron value
		set_aileron_pos=getprop("fdm/jsbsim/fcs/roll-trim-sum-echoed");
		aileron_pos=getprop("fdm/jsbsim/fcs/roll-trim-sum-timed");
		# get buster values	
		set_pos=getprop("instrumentation/buster-control/set-pos-norm");
		switch_pos=getprop("instrumentation/buster-control/switch-pos-norm");
		fix_pos=getprop("instrumentation/buster-control/fix-pos-norm");
		indicated_error=getprop("instrumentation/buster-indicator/indicated-pressure-error");	
		#get pump value
		pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		if (
			(set_aileron_pos==nil)
			or (aileron_pos==nil)
			or (set_pos==nil)
			or (switch_pos==nil)
			or (fix_pos==nil)
			or (indicated_error==nil)
			or (pump==nil)
		)
		{
			stop_bustercontrol();
			setprop("instrumentation/buster-control/error", 1);
	 		return ( settimer(bustercontrol, 0.1) ); 
		}
		setprop("instrumentation/buster-control/error", 0);
		if (!(set_pos==switch_pos))
		{
			way_to=abs(set_pos-switch_pos)/(set_pos-switch_pos);
			switch_pos=switch_pos+0.3*way_to;
			if (((way_to>0) and (switch_pos>set_pos)) or ((way_to<0) and (switch_pos<set_pos)))
			{
				switch_pos=set_pos;
				setprop("instrumentation/buster-control/switch-pos-norm", switch_pos);
				setprop("instrumentation/buster-control/fix-pos-norm", 1);
				clicksound();
			}
			else
			{
				setprop("instrumentation/buster-control/switch-pos-norm", switch_pos);
				setprop("instrumentation/buster-control/fix-pos-norm", 0);
			}
		}
		if ((switch_pos==0) or (pump==0))
		{
			aileron_boost=0.2;
		}
		else
		{
			aileron_boost=switch_pos/2;
		}
		setprop("fdm/jsbsim/fcs/aileron-boost", aileron_boost);
		if (pump==0)
		{
			stop_bustercontrol();
	 		return ( settimer(bustercontrol, 0.1) ); 
		}
		indicated_error=indicated_error+(1-2*rand(123))*0.01;
		if (indicated_error>0.03)
		{
			indicated_error=0.03;
		}
		if (indicated_error<-0.03)
		{
			indicated_error=-0.03;
		}
		setprop("instrumentation/buster-indicator/indicated-pressure-error", indicated_error);
		if (switch_pos==0) 
		{
			indicated_pressure=0;
		}
		else
		{
			indicated_pressure=0.2+switch_pos*0.2+abs(set_aileron_pos-aileron_pos)*0.1+indicated_error;
		}
		setprop("instrumentation/buster-indicator/indicated-pressure-norm", indicated_pressure);
		settimer(bustercontrol, 0.1);
	  }

# set startup configuration
init_bustercontrol = func 
{
	setprop("instrumentation/buster-control/serviceable", 1);
	setprop("instrumentation/buster-control/fix-pos-norm", 1);
	setprop("instrumentation/buster-control/switch-pos-norm", 1);
	setprop("instrumentation/buster-control/set-pos-norm", 1);
	setprop("instrumentation/buster-indicator/indicated-pressure-norm", 0);
	setprop("instrumentation/buster-indicator/indicated-pressure-error", 0);
}

init_bustercontrol();

#keyboard functions

more_booster = func 
	{
		set_pos=getprop("instrumentation/buster-control/set-pos-norm");
		if (!(set_pos==nil))
		{
			if (set_pos<2)
			{
				set_pos=set_pos+1;
				setprop("instrumentation/buster-control/set-pos-norm", set_pos);
			}
		}
	}

less_booster = func 
	{
		set_pos=getprop("instrumentation/buster-control/set-pos-norm");
		if (!(set_pos==nil))
		{
			if (set_pos>0)
			{
				set_pos=set_pos-1;
				setprop("instrumentation/buster-control/set-pos-norm", set_pos);
			}
		}
	}

# start buster control process first time
bustercontrol ();

#--------------------------------------------------------------------

# Brake presure meter

# helper 
stop_brakepressmeter = func 
	{
	}

brakepressmeter = func 
	{
		# check power
		in_service = getprop("instrumentation/brake-pressure-meter/serviceable" );
		if (in_service == nil)
		{
			stop_brakepressmeter();
	 		return ( settimer(brakepressmeter, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_brakepressmeter();
		 	return ( settimer(brakepressmeter, 0.1) ); 
		}
		# get brakes values
		set_left_brake_pos=getprop("controls/gear/brake-left");
		set_right_brake_pos=getprop("controls/gear/brake-right");
		set_brake_parking=getprop("controls/gear/brake-parking");
		# get error values	
		left_indicated_error=getprop("instrumentation/brake-pressure-meter/left-indicated-pressure-error");
		right_indicated_error=getprop("instrumentation/brake-pressure-meter/right-indicated-pressure-error");
		#get bus value
		bus=getprop("systems/electrical-real/bus");
		if ((set_left_brake_pos==nil) or (set_right_brake_pos==nil) or (set_brake_parking==nil) or (left_indicated_error==nil) or (right_indicated_error==nil) or (bus==nil))
		{
			stop_brakepressmeter();
			#setprop("instrumentation/brake-pressure-meter/error", 1);
	 		return ( settimer(brakepressmeter, 0.1) ); 
		}
		#setprop("instrumentation/brake-pressure-meter/error", 0);
		if (bus==0)
		{
			setprop("instrumentation/brake-pressure-meter/left-indicated-pressure", 0);
			setprop("instrumentation/brake-pressure-meter/right-indicated-pressure", 0);
			setprop("controls/gear/brake-left-real", 0);
			setprop("controls/gear/brake-right-real", 0);
			stop_brakepressmeter();
		 	return ( settimer(brakepressmeter, 0.1) ); 
		}
		left_indicated_error=left_indicated_error+(1-2*rand(123))*0.005;
		if (left_indicated_error>0.048)
		{
			left_indicated_error=0.048;
		}
		if (left_indicated_error<-0.048)
		{
			left_indicated_error=-0.048;
		}
		setprop("instrumentation/brake-pressure-meter/left-indicated-pressure-error", left_indicated_error);
		right_indicated_error=right_indicated_error+(1-2*rand(123))*0.005;
		if (right_indicated_error>0.048)
		{
			right_indicated_error=0.048;
		}
		if (right_indicated_error<-0.048)
		{
			right_indicated_error=-0.048;
		}
		setprop("instrumentation/brake-pressure-meter/right-indicated-pressure-error", right_indicated_error);
		if ((set_brake_parking>set_left_brake_pos) and (set_brake_parking>set_right_brake_pos))
		{
			left_indicated_pressure=0.3+set_brake_parking*0.5+left_indicated_error;
			right_indicated_pressure=0.3+set_brake_parking*0.5+right_indicated_error;
		}
		else
		{
			left_indicated_pressure=0.3+set_left_brake_pos*0.5+left_indicated_error;
			right_indicated_pressure=0.3+set_right_brake_pos*0.5+right_indicated_error;
		}
		setprop("controls/gear/brake-left-real", set_left_brake_pos);
		setprop("controls/gear/brake-right-real", set_right_brake_pos);
		setprop("instrumentation/brake-pressure-meter/left-indicated-pressure", left_indicated_pressure);
		setprop("instrumentation/brake-pressure-meter/right-indicated-pressure", right_indicated_pressure);
		settimer(brakepressmeter, 0.1);
	  }

# set startup configuration
init_brakepressmeter = func 
{
	setprop("instrumentation/brake-pressure-meter/serviceable", 1);
	setprop("instrumentation/brake-pressure-meter/left-indicated-pressure-error", 0);
	setprop("instrumentation/brake-pressure-meter/right-indicated-pressure-error", 0);
	setprop("instrumentation/brake-pressure-meter/left-indicated-pressure", 0);
	setprop("instrumentation/brake-pressure-meter/right-indicated-pressure", 0);
}

init_brakepressmeter();

# start brakes pressure meter process first time
brakepressmeter ();

#--------------------------------------------------------------------
# Ignition lamp

# helper 
stop_ignitionlamp = func 
	{
		setprop("instrumentation/ignition-lamp/light-norm", 0);
	}

ignitionlamp = func 
	{
		# check power
		in_service = getprop("instrumentation/ignition-lamp/serviceable" );
		if (in_service == nil)
		{
			stop_ignitionlamp();
	 		return ( settimer(ignitionlamp, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_ignitionlamp();
		 	return ( settimer(ignitionlamp, 0.1) ); 
		}
		# get instrumentation values	
		igntition_type=getprop("controls/switches/ignition-type");
		#get electricity values
		power=getprop("systems/electrical-real/outputs/ignition/on");
		if  ((igntition_type == nil) or (power==nil))
		{
			stop_ignitionlamp();
			setprop("instrumentation/ignition-lamp/error", 1);
	 		return ( settimer(ignitionlamp, 0.1) ); 
		}
		setprop("instrumentation/ignition-lamp/error", 0);
		if ((igntition_type==1) and (power==1))
		{
			setprop("instrumentation/ignition-lamp/light-norm", 1);
		}
		else
		{
			setprop("instrumentation/ignition-lamp/light-norm", 0);
		}
		settimer(ignitionlamp, 0.1);
	}

init_ignitionlamp = func 
{
	setprop("instrumentation/ignition-lamp/serviceable", 1);
	setprop("instrumentation/ignition-lamp/light-norm", 0);
}

init_ignitionlamp();

# start ignition lamp process first time
ignitionlamp ();

#--------------------------------------------------------------------
# Left panel

# helper 
stop_leftpanel = func 
	{
	}

leftpanel = func 
	{
		in_service = getprop("instrumentation/panels/left/serviceable");
		if (in_service == nil)
		{
			stop_leftpanel();
	 		return ( settimer(leftpanel, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_leftpanel();
		 	return ( settimer(leftpanel, 0.1) ); 
		}
		error=0;
		error=error+switchmove("instrumentation/switches/pump", "controls/switches/pump");
		error=error+switchmove("instrumentation/switches/isolation-valve", "controls/switches/isolation-valve");
		error=error+switchmove("instrumentation/switches/ignition-type", "controls/switches/ignition-type");
		error=error+switchmove("instrumentation/switches/ignition", "controls/switches/ignition");
		error=error+switchmove("instrumentation/switches/engine-control", "controls/switches/engine-control");
		error=error+switchmove("instrumentation/switches/third-tank-pump", "controls/switches/third-tank-pump");
		setprop("instrumentation/panels/left/error", error);
  		settimer(leftpanel, 0.1);
  }

# set startup configuration
init_leftpanel = func 
{
	setprop("instrumentation/panels/left/serviceable", 1);
	switchinit("instrumentation/switches/pump", 0, "controls/switches/pump");
	switchinit("instrumentation/switches/isolation-valve", 0, "controls/switches/isolation-valve");
	switchinit("instrumentation/switches/ignition-type", 0, "controls/switches/ignition-type");
	switchinit("instrumentation/switches/ignition", 0, "controls/switches/ignition");
	switchinit("instrumentation/switches/engine-control", 0, "controls/switches/engine-control");
	switchinit("instrumentation/switches/third-tank-pump", 0, "controls/switches/third-tank-pump");
}

init_leftpanel();

# start ignition lamp process first time
leftpanel ();

#--------------------------------------------------------------------
# Right panel

# helper 
stop_rightpanel = func 
	{
	}

rightpanel = func 
	{
		# check power
		in_service = getprop("instrumentation/panels/right/serviceable");
		if (in_service == nil)
		{
			stop_rightpanel();
	 		return ( settimer(rightpanel, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_rightpanel();
		 	return ( settimer(rightpanel, 0.1) ); 
		}
		error=0;
		error=error+switchmove("instrumentation/switches/battery", "controls/switches/battery");
		error=error+switchmove("instrumentation/switches/generator", "controls/switches/generator");
		error=error+switchmove("instrumentation/switches/headlight", "dummy/dummy");
		error=error+switchmove("instrumentation/switches/trimmer", "controls/switches/trimmer");
		error=error+switchmove("instrumentation/switches/horizon", "controls/switches/horizon");
		error=error+switchmove("instrumentation/switches/radio", "dummy/dummy");
		error=error+switchmove("instrumentation/switches/radioaltimeter", "controls/switches/radioaltimeter");
		error=error+switchmove("instrumentation/switches/radiocompass", "controls/switches/radiocompass");
		error=error+switchmove("instrumentation/switches/drop-tank", "controls/switches/drop-tank");
		error=error+switchmove("instrumentation/switches/bomb", "controls/switches/bomb");
		error=error+switchmove("instrumentation/switches/photo", "controls/switches/photo");
		error=error+switchmove("instrumentation/switches/photo-machinegun", "controls/switches/photo-machinegun");
		error=error+switchmove("instrumentation/switches/headsight", "controls/switches/headsight");
		error=error+switchmove("instrumentation/switches/machinegun", "controls/switches/machinegun");
		setprop("instrumentation/panels/right/error", error);
  		settimer(rightpanel, 0.1);
  }

# set startup configuration
init_rightpanel = func 
{
	setprop("instrumentation/panels/right/serviceable", 1);
	switchinit("instrumentation/switches/battery", 0, "controls/switches/battery");
	switchinit("instrumentation/switches/generator", 0, "controls/switches/generator");
	switchinit("instrumentation/switches/headlight", 0, "dummy/dummy");
	switchinit("instrumentation/switches/trimmer", 0, "controls/switches/trimmer");
	switchinit("instrumentation/switches/horizon", 0, "controls/switches/horizon");
	switchinit("instrumentation/switches/radio", 0, "dummy/dummy");
	switchinit("instrumentation/switches/radioaltimeter", 0, "controls/switches/radioaltimeter");
	switchinit("instrumentation/switches/radiocompass", 0, "controls/switches/radiocompass");
	switchinit("instrumentation/switches/drop-tank", 0, "controls/switches/drop-tank");
	switchinit("instrumentation/switches/bomb", 0, "controls/switches/bomb");
	switchinit("instrumentation/switches/photo", 0, "controls/switches/photo");
	switchinit("instrumentation/switches/photo-machinegun", 0, "controls/switches/photo-machinegun");
	switchinit("instrumentation/switches/headsight", 0, "controls/switches/headsight");
	switchinit("instrumentation/switches/machinegun", 0, "controls/switches/machinegun");
}

init_rightpanel();

# start ignition lamp process first time
rightpanel ();

#------------------------------------------------------------
#So, electrical system seems works strange in Flight Gear too
#There's pretty simple "on/off" electrical system for aircraft

stop_realelectric=func
	{
	}

realelectric=func
	{
		# check power
		in_service = getprop("systems/electrical-real/serviceable");
		if (in_service == nil)
		{
			stop_realelectric();
	 		return ( settimer(realelectric, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_realelectric();
		 	return ( settimer(realelectric, 0.1) ); 
		}
		#Get switches values
		set_battery=getprop("controls/switches/battery");
		set_generator=getprop("controls/switches/generator");

		starter_pressed=getprop("controls/engines/engine/starter-pressed");
		ignition_type=getprop("controls/switches/ignition-type");

		set_engine_control=getprop("controls/switches/engine-control");
		set_pump=getprop("controls/switches/pump");
		set_third_tank_pump=getprop("controls/switches/third-tank-pump");
		set_ignition=getprop("controls/switches/ignition");
		set_isolation=getprop("controls/switches/isolation-valve");

		set_headlight=getprop("instrumentation/switches/headlight/switch-pos-norm");
		set_trimmer=getprop("controls/switches/trimmer");
		set_horizon=getprop("controls/switches/horizon");
		set_radio=getprop("instrumentation/switches/radio/switch-pos-norm");
		set_radioaltimeter=getprop("controls/switches/radioaltimeter");
		set_radiocompass=getprop("controls/switches/radiocompass");
		set_drop_tank=getprop("controls/switches/drop-tank");
		set_bomb=getprop("controls/switches/bomb");
		set_photo=getprop("controls/switches/photo");
		set_photo_machinegun=getprop("controls/switches/photo-machinegun");
		set_headsight=getprop("controls/switches/headsight");
		set_machinegun=getprop("controls/switches/machinegun");

		battery_time=getprop("systems/electrical-real/battery-time");
		battery_load_time=getprop("systems/electrical-real/battery-load-time");
		battery_max_load_time=getprop("systems/electrical-real/battery-maximum-load-time");

		engine_running=getprop("engines/engine/running");
		if (
			(set_battery==nil)
			or (set_generator==nil)

			or (starter_pressed==nil)
			or (ignition_type==nil)

			or (set_engine_control==nil)
			or (set_pump==nil)
			or (set_third_tank_pump==nil)
			or (set_ignition==nil)
			or ( set_isolation==nil)

			or (set_headlight==nil)
			or (set_trimmer==nil)
			or (set_horizon==nil)
			or (set_radio==nil)
			or (set_radioaltimeter==nil)
			or (set_radiocompass==nil)
			or (set_drop_tank==nil)
			or (set_bomb==nil)
			or (set_photo==nil)
			or (set_photo_machinegun==nil)
			or (set_headsight==nil)
			or (set_machinegun==nil)

			or (battery_time==nil)
			or (battery_load_time==nil)
			or (battery_max_load_time==nil)
			or (engine_running==nil)

		)
		{
			stop_realelectric();
			return ( settimer(realelectric, 0.1) ); 
		}

		if (battery_load_time>battery_max_load_time)
		{
			setprop("systems/electrical-real/battery-time", 0);
			setprop("systems/electrical-real/battery-load-time", 0);
			setprop("controls/switches/battery", 0);
			switchfeedback("instrumentation/switches/battery", "controls/switches/battery");
			set_battery=0;
		}

		setprop("systems/electrical-real/inputs/battery", set_battery);
		if ((set_generator==1) and (engine_running==1))
		{
			generator_on=1;
		}
		else
		{
			generator_on=0;
		}
		setprop("systems/electrical-real/inputs/generator", generator_on);

		if (			
			(set_battery==1) 
			and  (generator_on!=1) 
		)
		{
			battery_time=battery_time+0.1;

			battery_load_time=battery_load_time+0.1*(

				1
				+set_engine_control
				+set_pump
				+set_third_tank_pump
				+set_ignition
				+set_isolation

				+starter_pressed
				+ignition_type

				+set_headlight
				+set_trimmer
				+set_horizon
				+set_radio
				+set_radioaltimeter
				+set_radiocompass
				+set_drop_tank
				+set_bomb
				+set_photo
				+set_photo_machinegun
				+set_headsight
				+set_machinegun);
		}
		else
		{
			battery_time=0;
			battery_load_time=0;
		}

		setprop("systems/electrical-real/battery-time", battery_time);
		setprop("systems/electrical-real/battery-load-time", battery_load_time);
		
		if ((set_battery==1) or (generator_on==1))
		{
			bus_on=1;
		}
		else
		{
			bus_on=0;
		}
		if (generator_on==1)
		{
			setprop("systems/electrical-real/amper-norm", 1);
		}
		else
		{
			if (set_battery==1) 
			{
				setprop("systems/electrical-real/amper-norm", 0.5);
			}
			else
			{
				setprop("systems/electrical-real/amper-norm", 0);
			}
		}
		setprop("systems/electrical-real/bus", bus_on);
		if (bus_on==1)
		{
			setprop("systems/electrical-real/volts-norm", 1);
			setprop("systems/electrical-real/outputs/pump/on", set_pump);
			setprop("systems/electrical-real/outputs/pump/volts-norm", set_pump);
			setprop("systems/electrical-real/outputs/third-tank-pump/on", set_third_tank_pump);
			setprop("systems/electrical-real/outputs/third-tank-pump/volts-norm", set_third_tank_pump);
			setprop("systems/electrical-real/outputs/ignition/on", set_ignition);
			setprop("systems/electrical-real/outputs/ignition/volts-norm", set_ignition);
			setprop("systems/electrical-real/outputs/engine_control/on", set_engine_control);
			setprop("systems/electrical-real/outputs/engine_control/volts-norm", set_engine_control);
			setprop("systems/electrical-real/outputs/horizon/on", set_horizon);
			setprop("systems/electrical-real/outputs/horizon/volts-norm", set_horizon);
			setprop("systems/electrical-real/outputs/radioaltimeter/on", set_radioaltimeter);
			setprop("systems/electrical-real/outputs/radioaltimeter/volts-norm", set_radioaltimeter);
			setprop("systems/electrical-real/outputs/radiocompass/on", set_radiocompass);
			setprop("systems/electrical-real/outputs/radiocompass/volts-norm", set_radiocompass);
			setprop("systems/electrical-real/outputs/isolation-lamp/on", set_isolation);
			setprop("systems/electrical-real/outputs/isolation-lamp/volts-norm", set_isolation);
			setprop("engines/engine/isolation-valve", set_isolation);
			setprop("systems/electrical-real/outputs/headsight/on", set_headsight);
			setprop("systems/electrical-real/outputs/headsight/volts-norm", set_headsight);
			setprop("systems/electrical-real/outputs/generatorlamp/on", (abs(1-set_generator)));
			setprop("systems/electrical-real/outputs/generatorlamp/volts-norm", (abs(1-set_generator)));
			setprop("systems/electrical-real/outputs/ignition-panel-lamp/on", set_ignition);
			setprop("systems/electrical-real/outputs/ignition-panel-lamp/volts-norm", set_ignition);
			setprop("systems/electrical-real/outputs/machinegun/on", set_machinegun);
			setprop("systems/electrical-real/outputs/machinegun/volts-norm", set_machinegun);
			setprop("systems/electrical-real/outputs/trimmer/on", set_trimmer);
			setprop("systems/electrical-real/outputs/trimmer/volts-norm", set_trimmer);
			setprop("systems/electrical-real/outputs/photo/on", set_photo);
			setprop("systems/electrical-real/outputs/photo/volts-norm", set_photo);
			setprop("systems/electrical-real/outputs/photo-machinegun/on", set_photo_machinegun);
			setprop("systems/electrical-real/outputs/photo-machinegun/volts-norm", set_photo_machinegun);
			setprop("systems/electrical-real/outputs/drop-tank/on", set_drop_tank);
			setprop("systems/electrical-real/outputs/drop-tank/volts-norm", set_drop_tank);
			setprop("systems/electrical-real/outputs/bomb/on", set_bomb);
			setprop("systems/electrical-real/outputs/bomb/volts-norm", set_bomb);
		}
		else
		{
			setprop("systems/electrical-real/volts-norm", 0);
			setprop("systems/electrical-real/outputs/pump/on", 0);
			setprop("systems/electrical-real/outputs/pump/volts-norm", 0);
			setprop("systems/electrical-real/outputs/third-tank-pump/on", 0);
			setprop("systems/electrical-real/outputs/third-tank-pump/volts-norm", 0);
			setprop("systems/electrical-real/outputs/ignition/on", 0);
			setprop("systems/electrical-real/outputs/ignition/volts-norm", 0);
			setprop("systems/electrical-real/outputs/engine_control/on", 0);
			setprop("systems/electrical-real/outputs/engine_control/volts-norm", 0);
			setprop("systems/electrical-real/outputs/horizon/on", 0);
			setprop("systems/electrical-real/outputs/horizon/volts-norm", 0);
			setprop("systems/electrical-real/outputs/radioaltimeter/on", 0);
			setprop("systems/electrical-real/outputs/radioaltimeter/volts-norm", 0);
			setprop("systems/electrical-real/outputs/radiocompass/on", 0);
			setprop("systems/electrical-real/outputs/radiocompass/volts-norm", 0);
			setprop("systems/electrical-real/outputs/isolation-lamp/on", 0);
			setprop("systems/electrical-real/outputs/isolation-lamp/volts-norm", 0);
			setprop("engines/engine/isolation-valve", 0);
			setprop("systems/electrical-real/outputs/headsight/on", 0);
			setprop("systems/electrical-real/outputs/headsight/volts-norm", 0);
			setprop("systems/electrical-real/outputs/generatorlamp/on", 0);
			setprop("systems/electrical-real/outputs/generatorlamp/volts-norm", 0);
			setprop("systems/electrical-real/outputs/ignition-panel-lamp/on", 0);
			setprop("systems/electrical-real/outputs/ignition-panel-lamp/volts-norm", 0);
			setprop("systems/electrical-real/outputs/machinegun/on", 0);
			setprop("systems/electrical-real/outputs/machinegun/volts-norm", 0);
			setprop("systems/electrical-real/outputs/trimmer/on", 0);
			setprop("systems/electrical-real/outputs/trimmer/volts-norm", 0);
			setprop("systems/electrical-real/outputs/photo/on", 0);
			setprop("systems/electrical-real/outputs/photo/volts-norm", 0);
			setprop("systems/electrical-real/outputs/photo-machinegun/on", 0);
			setprop("systems/electrical-real/outputs/photo-machinegun/volts-norm", 0);
			setprop("systems/electrical-real/outputs/drop-tank/on", 0);
			setprop("systems/electrical-real/outputs/drop-tank/volts-norm", 0);
			setprop("systems/electrical-real/outputs/bomb/on", 0);
			setprop("systems/electrical-real/outputs/bomb/volts-norm", 0);

		}
		settimer(realelectric, 0.1);
	}

init_realelectric = func 
{
	setprop("systems/electrical-real/serviceable", 1);

	setprop("systems/electrical-real/battery-time", 0);
	setprop("systems/electrical-real/battery-load-time", 0);
	setprop("systems/electrical-real/battery-maximum-load-time", 360);

	setprop("systems/electrical-real/ultraviolet", 0);
	setprop("systems/electrical-real/amper-norm", 0);
	setprop("systems/electrical-real/volts-norm", 0);
	setprop("systems/electrical-real/outputs/pump/on", 0);
	setprop("systems/electrical-real/outputs/pump/volts-norm", 0);
	setprop("systems/electrical-real/outputs/third-tank-pump/on", 0);
	setprop("systems/electrical-real/outputs/third-tank-pump/volts-norm", 0);
	setprop("systems/electrical-real/outputs/ignition/on", 0);
	setprop("systems/electrical-real/outputs/ignition/volts-norm", 0);
	setprop("systems/electrical-real/outputs/engine_control/on", 0);
	setprop("systems/electrical-real/outputs/engine_control/volts-norm", 0);
	setprop("systems/electrical-real/outputs/horizon/on", 0);
	setprop("systems/electrical-real/outputs/horizon/volts-norm", 0);
	setprop("systems/electrical-real/outputs/radioaltimeter/on", 0);
	setprop("systems/electrical-real/outputs/radioaltimeter/volts-norm", 0);
	setprop("systems/electrical-real/outputs/radiocompass/on", 0);
	setprop("systems/electrical-real/outputs/radiocompass/volts-norm", 0);
	setprop("systems/electrical-real/outputs/isolation-lamp/on", 0);
	setprop("systems/electrical-real/outputs/isolation-lamp/volts-norm", 0);
	setprop("engines/engine/isolation-valve", 0);
	setprop("systems/electrical-real/outputs/headsight/on", 0);
	setprop("systems/electrical-real/outputs/headsight/volts-norm", 0);
	setprop("systems/electrical-real/outputs/generatorlamp/on", 0);
	setprop("systems/electrical-real/outputs/generatorlamp/volts-norm", 0);
	setprop("systems/electrical-real/outputs/ignition-panel-lamp/on", 0);
	setprop("systems/electrical-real/outputs/ignition-panel-lamp/volts-norm", 0);
	setprop("systems/electrical-real/outputs/machinegun/on", 0);
	setprop("systems/electrical-real/outputs/machinegun/volts-norm", 0);
	setprop("systems/electrical-real/outputs/trimmer/on", 0);
	setprop("systems/electrical-real/outputs/trimmer/volts-norm", 0);
	setprop("systems/electrical-real/outputs/photo/on", 0);
	setprop("systems/electrical-real/outputs/photo/volts-norm", 0);
	setprop("systems/electrical-real/outputs/photo-machinegun/on", 0);
	setprop("systems/electrical-real/outputs/photo-machinegun/volts-norm", 0);
	setprop("systems/electrical-real/outputs/drop-tank/on", 0);
	setprop("systems/electrical-real/outputs/drop-tank/volts-norm", 0);
	setprop("systems/electrical-real/outputs/bomb/on", 0);
	setprop("systems/electrical-real/outputs/bomb/volts-norm", 0);
}

init_realelectric();

realelectric();

#-----------------------------------------------------------------------
#Lightning system

init_lightning=func
{
	setprop("systems/light/use-ultraviolet", 0);
	setprop("systems/light/ultraviolet-norm", 0);
	setprop("systems/light/use-canopy-lamps", 0);
	setprop("systems/light/canopy-lamps-norm", 0);
}

init_lightning();

#-----------------------------------------------------------------------
#Airspeedometer
stop_airspeedometer=func
	{
	}

airspeedometer=func
	{
		# check power
		in_service = getprop("instrumentation/airspeedometer/serviceable");
		if (in_service == nil)
		{
			stop_airspeedometer();
	 		return ( settimer(airspeedometer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_airspeedometer();
		 	return ( settimer(airspeedometer, 0.1) ); 
		}
		#Get values
		speed=getprop("velocities/airspeed-kt");
		bus=getprop("systems/electrical-real/bus");
		if ((speed==nil) or (bus==nil))
		{
			stop_airspeedometer();
	 		return ( settimer(airspeedometer, 0.1) ); 
		}
		if (bus==1)
		{
			setprop("instrumentation/airspeedometer/indicated-speed-kt", speed);
		}
		settimer(airspeedometer, 0.1);
	}

init_airspeedometer=func
{
	setprop("instrumentation/airspeedometer/serviceable", 1);
	setprop("instrumentation/airspeedometer/indicated-speed-kt", 0);
}

init_airspeedometer();

airspeedometer();

#-----------------------------------------------------------------------
#Gas termometer
stop_gastermometer=func
	{
	}

gastermometer=func
	{
		# check power
		in_service = getprop("instrumentation/gastermometer/serviceable");
		if (in_service == nil)
		{
			stop_gastermometer();
	 		return ( settimer(gastermometer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gastermometer();
		 	return ( settimer(gastermometer, 0.1) ); 
		}
		#Get engine temperature value
		egt=getprop("engines/engine/egt-degc");
		#get engine control value
		engine_control=getprop("systems/electrical-real/outputs/engine_control/on");
		if ((egt==nil) or (engine_control==nil))
		{
			stop_gastermometer();
	 		return ( settimer(gastermometer, 0.1) ); 
		}
		if (engine_control==0)
		{
			setprop("instrumentation/gastermometer/egt-degf-indicated", 0);
			stop_gastermometer();
		 	return ( settimer(gastermometer, 0.1) ); 
		}
		setprop("instrumentation/gastermometer/egt-degc-indicated", egt);
		settimer(gastermometer, 0.1);
	}

init_gastermometer=func
{
	setprop("instrumentation/gastermometer/serviceable", 1);
	setprop("instrumentation/gastermometer/egt-degf-indicated", 0);
}

init_gastermometer();

gastermometer();

#-----------------------------------------------------------------------
#Motormeter
stop_motormeter=func
	{
	}

motormeter=func
	{
		# check power
		in_service = getprop("instrumentation/motormeter/serviceable");
		if (in_service == nil)
		{
			stop_motormeter();
	 		return ( settimer(motormeter, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_motormeter();
		 	return ( settimer(motormeter, 0.1) ); 
		}
		#Get engine valus
		fuel_flow=getprop("engines/engine/fuel-flow_pph");
		oil_pressure=getprop("engines/engine/oil-pressure-psi");
		engine_temperature=getprop("engines/engine/egt-degc");
		#get engine control value
		engine_control=getprop("systems/electrical-real/outputs/engine_control/on");
		if (
			(fuel_flow==nil) 
			or (oil_pressure==nil) 
			or (engine_temperature==nil)
			or (engine_control==nil)
		)
		{
			stop_motormeter();
	 		return ( settimer(motormeter, 0.1) ); 
		}
		if (engine_control==0)
		{
			setprop("instrumentation/motormeter/fuel-flow-gph", 0);
			setprop("instrumentation/motormeter/oilp-norm", 0);
			setprop("instrumentation/motormeter/oilt-norm", 0);
			stop_motormeter();
		 	return ( settimer(motormeter, 0.1) ); 
		}
		#Constatnts get from test runs
		setprop("instrumentation/motormeter/fuel-flow-norm", fuel_flow/5000);
		setprop("instrumentation/motormeter/oil-pressure-norm", oil_pressure/70);
		setprop("instrumentation/motormeter/oil-temperature-norm", engine_temperature/1000);
		settimer(motormeter, 0.1);
	}

init_motormeter=func
{
	setprop("instrumentation/motormeter/serviceable", 1);
	setprop("instrumentation/motormeter/fuel-flow-norm", 0);
	setprop("instrumentation/motormeter/oil-pressure-norm", 0);
	setprop("instrumentation/motormeter/oil-temperature-norm", 0);
}

init_motormeter();

motormeter();

#-----------------------------------------------------------------------
#Tachometer
stop_tachometer=func
	{
	}

tachometer=func
	{
		# check power
		in_service = getprop("instrumentation/tachometer/serviceable");
		if (in_service == nil)
		{
			stop_tachometer();
	 		return ( settimer(tachometer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_tachometer();
		 	return ( settimer(tachometer, 0.1) ); 
		}
		#Get engine value
		rpm=getprop("engines/engine/rpm");
		#get engine control value
		engine_control=getprop("systems/electrical-real/outputs/engine_control/on");
		if ((rpm==nil) or (engine_control==nil))
		{
			stop_tachometer();
	 		return ( settimer(tachometer, 0.1) ); 
		}
		if (engine_control==0)
		{
			setprop("instrumentation/tachometer/rpm", 0);
			stop_tachometer();
		 	return ( settimer(tachometer, 0.1) ); 
		}
		setprop("instrumentation/tachometer/rpm", rpm);
		settimer(tachometer, 0.1);
	}

init_tachometer=func
{
	setprop("instrumentation/tachometer/serviceable", 1);
	setprop("instrumentation/tachometer/rpm", 0);
}

init_tachometer();

tachometer();

#-----------------------------------------------------------------------
#Machometer
stop_machometer=func
	{
	}

machometer=func
	{
		# check power
		in_service = getprop("instrumentation/machometer/serviceable");
		if (in_service == nil)
		{
			stop_machometer();
	 		return ( settimer(machometer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_machometer();
		 	return ( settimer(machometer, 0.1) ); 
		}
		#Get values
		mach=getprop("velocities/mach");
		bus=getprop("systems/electrical-real/bus");
		if ((mach==nil) or (bus==nil))
		{
			stop_machometer();
	 		return ( settimer(machometer, 0.1) ); 
		}
		if (bus==1)
		{
			setprop("instrumentation/machometer/indicated-mach", mach);
		}
		settimer(machometer, 0.1);
	}

init_machometer=func
{
	setprop("instrumentation/machometer/serviceable", 1);
}

init_machometer();

machometer();

#-----------------------------------------------------------------------
#Turnometer
stop_turnometer=func
	{
	}

turnometer=func
	{
		# check power
		in_service = getprop("instrumentation/turnometer/serviceable");
		if (in_service == nil)
		{
			stop_turnometer();
	 		return ( settimer(turnometer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_turnometer();
		 	return ( settimer(turnometer, 0.1) ); 
		}
		#Get values
		turn=getprop("orientation/roll-deg");
		bus=getprop("systems/electrical-real/bus");
		if ((bus==nil) or (turn==nil))
		{
			stop_turnometer();
	 		return ( settimer(turnometer, 0.1) ); 
		}
		if (bus==0)
		{
			stop_turnometer();
	 		return ( settimer(turnometer, 0.3) ); 
		}
		setprop("instrumentation/turnometer/indicated-turn-rate", turn);
		settimer(turnometer, 0.1);
	}

init_turnometer=func
{
	setprop("instrumentation/turnometer/serviceable", 1);
	setprop("instrumentation/turnometer/indicated-turn-rate", 0);
}

init_turnometer();

turnometer();

#-----------------------------------------------------------------------
#Vertspeedometer
stop_vertspeedometer=func
	{
	}

vertspeedometer=func
	{
		# check power
		in_service = getprop("instrumentation/vertspeedometer/serviceable");
		if (in_service == nil)
		{
			stop_vertspeedometer();
	 		return ( settimer(vertspeedometer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_vertspeedometer();
		 	return ( settimer(vertspeedometer, 0.1) ); 
		}
		#Get values
		vertspeed=getprop("fdm/jsbsim/velocities/v-down-fps");
		bus=getprop("systems/electrical-real/bus");
		if ((bus==nil) or (vertspeed==nil))
		{
			stop_vertspeedometer();
	 		return ( settimer(vertspeedometer, 0.1) ); 
		}
		if (bus==0)
		{
			stop_vertspeedometer();
	 		return ( settimer(vertspeedometer, 0.3) ); 
		}
		vertspeed=vertspeed*0.30480;
		setprop("instrumentation/vertspeedometer/indicated-speed-m", vertspeed);
		settimer(vertspeedometer, 0.1);
	}

init_vertspeedometer=func
{
	setprop("instrumentation/vertspeedometer/serviceable", 1);
	setprop("instrumentation/vertspeedometer/indicated-speed-fpm", 0);
}

init_vertspeedometer();

vertspeedometer();

#-----------------------------------------------------------------------
#Headsight
stop_headsight=func
	{
		setprop("instrumentation/headsight/lamp", 0);
		setprop("instrumentation/headsight/sign", 0);
		setprop("instrumentation/headsight/ring-lamp", 0);
		setprop("instrumentation/headsight/cross-lamp", 0);
		setprop("instrumentation/headsight/gyro-pitch-shift", 0);
		setprop("instrumentation/headsight/gyro-yaw-shift", 0);
	}

headsight=func
	{
		# check power
		in_service = getprop("instrumentation/headsight/serviceable");
		if (in_service == nil)
		{
			stop_headsight();
	 		return ( settimer(headsight, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_headsight();
		 	return ( settimer(headsight, 0.1) ); 
		}
		switchmove("instrumentation/headsight/up", "dummy/dummy");
		switchmove("instrumentation/headsight/gyro", "dummy/dummy");
		switchmove("instrumentation/headsight/frame", "dummy/dummy");
		#Get values
		power=getprop("systems/electrical-real/outputs/headsight/volts-norm");
		gyro=getprop("instrumentation/headsight/gyro/switch-pos-norm");
		up=getprop("instrumentation/headsight/up/switch-pos-norm");
		brightness=getprop("instrumentation/headsight/brightness");
		pitch_speed = getprop("orientation/pitch-rate-degps");
		yaw_speed = getprop("orientation/yaw-rate-degps");
		target_size=getprop("instrumentation/headsight/target-size");
		target_distance=getprop("instrumentation/headsight/target-distance");
		distance_from_eye_to_sight=getprop("instrumentation/headsight/from-eye-to-sight");
		view_offset_x=getprop("sim/view[1]/config/x-offset-m");
		view_offset_y=getprop("sim/view[1]/config/y-offset-m");
		view_offset_z=getprop("sim/view[1]/config/z-offset-m");
		view_heading_offset_deg=getprop("sim/view[1]/config/heading-offset-deg");
		view_pitch_offset_deg=getprop("sim/view[1]/config/pitch-offset-deg");
		view_roll_offset_deg=getprop("sim/view[1]/config/roll-offset-deg");
		view_field_offset=getprop("sim/view[1]/config/default-field-of-view-deg");
		current_view_number=getprop("sim/current-view/view-number");
		photo_machinegun=getprop("systems/electrical-real/outputs/photo-machinegun/volts-norm");
		if (
			(power==nil)
			or (gyro==nil)
			or (up==nil)
			or (brightness==nil)
			or (pitch_speed==nil)
			or (yaw_speed==nil)
			or (target_size==nil)
			or (target_distance==nil)
			or (distance_from_eye_to_sight==nil)
			or (view_offset_x==nil)
			or (view_offset_y==nil)
			or (view_offset_z==nil)
			or (view_heading_offset_deg==nil)
			or (view_pitch_offset_deg==nil)
			or (view_roll_offset_deg==nil)
			or (view_field_offset==nil)
			or (current_view_number==nil)
			or (photo_machinegun==nil)
		)
		{
			stop_headsight();
			setprop("instrumentation/headsight/error", 1);
	 		return ( settimer(headsight, 0.1) ); 
		}
		setprop("instrumentation/headsight/error", 0);
		setprop("sim/view[1]/config/z-offset-m", 1.545+0.184+distance_from_eye_to_sight);
		if (current_view_number==1)
		{
			setprop("sim/current-view/x-offset-m", view_offset_x);
			setprop("sim/current-view/y-offset-m", view_offset_y);
			setprop("sim/current-view/z-offset-m", view_offset_z);
			setprop("sim/current-view/heading-offset-deg", view_heading_offset_deg);
			setprop("sim/current-view/pitch-offset-deg", view_pitch_offset_deg);
			setprop("sim/current-view/roll-offset-deg", view_roll_offset_deg);
			setprop("sim/current-view/field-of-view", view_field_offset);
		}
		if (power==0)
		{
			stop_headsight();
	 		return ( settimer(headsight, 0.1) ); 
		}
		if ((current_view_number==1) and (photo_machinegun==1))
		{
			setprop("instrumentation/headsight/sign", 1);
		}
		else
		{
			setprop("instrumentation/headsight/sign", 0);
		}
		if (up==1)
		{
			setprop("instrumentation/headsight/lamp", power);
			lamp_brightness=power*brightness;
			setprop("instrumentation/headsight/lamp-brightness", lamp_brightness);
			if (gyro==1)
			{
				sight_source_size=0.020;
				bullet_speed=680;
				pitch_shift_edge=0.027;
				yaw_shift_edge=0.035;

				sight_dot_size=0.001;
				sight_angle_source=(target_size/2)/target_distance;
				sight_angle=math.atan2(sight_angle_source, 1);
				sight_size=distance_from_eye_to_sight*(math.sin(sight_angle)/math.cos(sight_angle));
				sight_scale_factor=sight_size/sight_source_size;
				time_to_target=target_distance/bullet_speed;
				pitch_shift_angle_deg=time_to_target*pitch_speed;
				yaw_shift_angle_deg=time_to_target*yaw_speed;
				pitch_shift_angle=pitch_shift_angle_deg/180*math.pi;
				yaw_shift_angle=yaw_shift_angle_deg/180*math.pi;
				pitch_shift=distance_from_eye_to_sight*(math.sin(pitch_shift_angle)/math.cos(pitch_shift_angle));
				yaw_shift=distance_from_eye_to_sight*(math.sin(yaw_shift_angle)/math.cos(yaw_shift_angle));
				sight_side_size=sight_size/2;
				sight_corner_size=sight_side_size*0.7071;
	
				setprop("instrumentation/headsight/cross-lamp", lamp_brightness);
				setprop("instrumentation/headsight/ring-lamp", 0);
				setprop("instrumentation/headsight/time_to_target", time_to_target);
				setprop("instrumentation/headsight/gyro-sight-scale", sight_scale_factor);
				setprop("instrumentation/headsight/gyro-sight-side-size", sight_side_size);
				setprop("instrumentation/headsight/gyro-sight-corner-size", sight_corner_size);
				setprop("instrumentation/headsight/pitch_shift_angle_deg", pitch_shift_angle_deg);
				setprop("instrumentation/headsight/yaw_shift_angle_deg", yaw_shift_angle_deg);
				setprop("instrumentation/headsight/gyro-pitch-shift", pitch_shift);
				setprop("instrumentation/headsight/gyro-yaw-shift", yaw_shift);

				pitch_shift=getprop("instrumentation/headsight/gyro-pitch-shift");
				yaw_shift=getprop("instrumentation/headsight/gyro-yaw-shift");

				if ((pitch_shift==nil) or (yaw_shift==nil))
				{
					stop_headsight();
		 			return ( settimer(headsight, 0.1) ); 
				}

				if (((pitch_shift+sight_side_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_side_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_side_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_side_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-visible", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-visible", 0);
				}

				if (((pitch_shift+sight_side_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift+sight_side_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-up", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-up", 0);
				}

				if (((pitch_shift-sight_side_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_side_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-down", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-down", 0);	
				}

				if (((pitch_shift+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_side_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift+sight_side_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-right", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-right", 0);
				}

				if (((pitch_shift+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift-sight_side_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_side_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-left", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-left", 0);
				}

				if (((pitch_shift+sight_corner_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift+sight_corner_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_corner_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift+sight_corner_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-up-right", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-up-right", 0);
				}

				if (((pitch_shift-sight_corner_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_corner_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift-sight_corner_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_corner_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-down-left", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-down-left", 0);
				}


				if (((pitch_shift+sight_corner_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift+sight_corner_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift-sight_corner_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_corner_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-up-left", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-up-left", 0);
				}


				if (((pitch_shift-sight_corner_size+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_corner_size-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_corner_size+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift+sight_corner_size-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-down-right", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-down-right", 0);
				}


				if (((pitch_shift+sight_dot_size)<pitch_shift_edge)
					and ((pitch_shift-sight_dot_size)>-pitch_shift_edge)
					and ((yaw_shift+sight_dot_size)<yaw_shift_edge)
					and ((yaw_shift-sight_dot_size)>-yaw_shift_edge))
				{
					setprop("instrumentation/headsight/gyro-sight-center", 1);
				}
				else
				{
					setprop("instrumentation/headsight/gyro-sight-center", 0);
				}

			}
			else
			{
				if (gyro==0)
				{
					setprop("instrumentation/headsight/cross-lamp", 0);
					setprop("instrumentation/headsight/ring-lamp", lamp_brightness);
				}
				else
				{
					setprop("instrumentation/headsight/lamp", 0);
					setprop("instrumentation/headsight/ring-lamp", 0);
					setprop("instrumentation/headsight/cross-lamp", 0);
				}
			}

		}
		else
		{
			setprop("instrumentation/headsight/lamp", 0);
			setprop("instrumentation/headsight/ring-lamp", 0);
			setprop("instrumentation/headsight/cross-lamp", 0);
		}
		settimer(headsight, 0.1);
	}

init_headsight=func
{
	setprop("instrumentation/headsight/serviceable", 1);
	switchinit("instrumentation/headsight/up", 1, "dummy/dummy");
	switchinit("instrumentation/headsight/gyro", 1, "dummy/dummy");
	switchinit("instrumentation/headsight/frame", 0, "dummy/dummy");
	setprop("instrumentation/headsight/brightness", 1);
	setprop("instrumentation/headsight/target-size", 15);
	setprop("instrumentation/headsight/target-distance", 400);
	setprop("instrumentation/headsight/from-eye-to-sight", 0.4);
	setprop("instrumentation/headsight/lamp", 0);
	setprop("instrumentation/headsight/sign", 0);
	setprop("instrumentation/headsight/ring-lamp", 0);
	setprop("instrumentation/headsight/cross-lamp", 0);
	setprop("instrumentation/headsight/stat-cross-lamp", 0);
	setprop("instrumentation/headsight/gyro-pitch-shift", 0);
	setprop("instrumentation/headsight/yaw-pitch-shift", 0);
	setprop("instrumentation/headsight/gyro-sight-scale", 1);
	#values to move object to real zero
	setprop("instrumentation/headsight/one", 1);
}

init_headsight();

#keyboard functions

less_sight_distance = func 
	{
		set_pos=getprop("instrumentation/headsight/target-distance");
		if (!(set_pos==nil))
		{
			if (set_pos>180)
			{
				set_pos=set_pos-10;
				setprop("instrumentation/headsight/target-distance", set_pos);
			}
		}
	}

more_sight_distance = func 
	{
		set_pos=getprop("instrumentation/headsight/target-distance");
		if (!(set_pos==nil))
		{
			if (set_pos<800)
			{
				set_pos=set_pos+10;
				setprop("instrumentation/headsight/target-distance", set_pos);
			}
		}
	}

headsight();

#-----------------------------------------------------------------------
#Stick
stop_stick=func
	{
	}

stick=func
	{
		# check power
		in_service = getprop("instrumentation/stick/serviceable");
		if (in_service == nil)
		{
	 		return ( stop_stick() ); 
		}
		if ( in_service != 1 )
		{
	 		return ( stop_stick() ); 
		}
		#Get values
		aileron=getprop("controls/flight/aileron");
		elevator=getprop("controls/flight/elevator");
		if (
			(aileron==nil) 
			or (elevator==nil)
		)
		{
	 		return ( stop_stick() ); 
		}
		setprop("fdm/jsbsim/fcs/elevator-cmd-norm-real", elevator);
		setprop("fdm/jsbsim/fcs/aileron-cmd-norm-real", aileron);
		elevator_stick_deg=-elevator*4;
		aileron_stick_deg=-aileron*5;
		#constants getted fom sick model
		elevator_rod_shift_x=-(0.088)*math.sin(elevator_stick_deg/180*math.pi);
		elevator_rod_shift_z=(0.088)*(-1+math.cos(elevator_stick_deg/180*math.pi));
		elevator_rod_shift_y=(0.088)*math.sin(aileron_stick_deg/180*math.pi);
		aileron_first_rod_shift_y=(0.088)*math.sin(aileron_stick_deg/180*math.pi);
		aileron_rocker_source_angle=math.atan2((0.200-0.168), (0.068-0.036))/math.pi*180;
		aileron_rocker_next_angle=math.atan2((0.200-aileron_first_rod_shift_y-0.168), (0.068-0.036))/math.pi*180;
		aileron_rocker_shift_angle=aileron_rocker_next_angle-aileron_rocker_source_angle;
		aileron_second_rod_source_angle=math.atan2((0.230-0.200), (0.036-0.007))/math.pi*180;
		aileron_second_rod_next_angle=aileron_second_rod_source_angle+aileron_rocker_shift_angle;
		aileron_second_rod_shift_x=math.sqrt((0.230-0.200)*(0.230-0.200)+(0.036-0.007)*(0.036-0.007))*(-math.sin(aileron_second_rod_source_angle/180*math.pi)+math.sin(aileron_second_rod_next_angle/180*math.pi));

		setprop("instrumentation/stick/elevator_stick_deg", elevator_stick_deg);
		setprop("instrumentation/stick/aileron_stick_deg", aileron_stick_deg);
		setprop("instrumentation/stick/elevator_rod_shift_x", elevator_rod_shift_x);
		setprop("instrumentation/stick/elevator_rod_shift_y", elevator_rod_shift_y);
		setprop("instrumentation/stick/elevator_rod_shift_z", elevator_rod_shift_z);
		setprop("instrumentation/stick/aileron_first_rod_shift_y", aileron_first_rod_shift_y);
		setprop("instrumentation/stick/aileron_rocker_shift_angle", aileron_rocker_shift_angle);
		setprop("instrumentation/stick/aileron_second_rod_shift_x", aileron_second_rod_shift_x);
		setprop("instrumentation/stick/already-moved", 0);
	}

init_stick=func
{
	setprop("instrumentation/stick/serviceable", 1);
	setprop("instrumentation/stick/elevator_stick_deg", 0);
	setprop("instrumentation/stick/aileron_stick_deg", 0);
	setprop("instrumentation/stick/elevator_rod_shift_x", 0);
	setprop("instrumentation/stick/elevator_rod_shift_y", 0);
	setprop("instrumentation/stick/elevator_rod_shift_z", 0);
	setprop("instrumentation/stick/aileron_first_rod_shift_y", 0);
	setprop("instrumentation/stick/aileron_rocker_shift_angle", 0);
	setprop("instrumentation/stick/aileron_second_rod_shift_x", 0);
}

init_stick();

setlistener("controls/flight/aileron", stick);
setlistener("controls/flight/elevator", stick);

#-----------------------------------------------------------------------
#Stick buttons
stop_stick_buttons=func
	{
	}

stick_buttons=func
	{
		# check power
		in_service = getprop("instrumentation/stick/serviceable");
		if (in_service == nil)
		{
			stop_stick_buttons();
	 		return ( settimer(stick_buttons, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_stick_buttons();
		 	return ( settimer(stick_buttons, 0.1) ); 
		}
		switchmove("instrumentation/stick/fix", "dummy/dummy");
		switchmove("instrumentation/stick/brake-all", "dummy/dummy");
		#Get values
		left_brake=getprop("controls/gear/brake-left");
		right_brake=getprop("controls/gear/brake-right");
		brake_parking=getprop("controls/gear/brake-parking");
		fix_pos=getprop("instrumentation/stick/fix/switch-pos-norm");
		button_set_pos=getprop("instrumentation/stick/button/set-pos");
		button_pos=getprop("instrumentation/stick/button/switch-pos-norm");
		#command is from vc by mouse, button is from keyboard
		fire_command=getprop("controls/fire-command");
		fire_button=getprop("controls/armanent/trigger");
		bomb_command=getprop("controls/bomb-command");
		bomb_button=getprop("controls/bomb-button");
		if (
			(left_brake==nil)
			or (right_brake==nil)
			or (brake_parking==nil)
			or (fix_pos==nil)
			or (button_set_pos==nil)
			or (button_pos==nil)
			or (fire_command==nil)
			or (fire_button==nil)
			or (bomb_command==nil)
			or (bomb_button==nil)
		)
		{
			stop_stick_buttons();
	 		return ( settimer(stick_buttons, 0.1) ); 
		}
		if ((fire_command==1) or (fire_button==1))
		{
			fire_pressed=1;
		}
		else
		{
			fire_pressed=0;
		}
		if (fix_pos==1)
		{
			fire_pressed=0;
			setprop("controls/fire-command", 0);
		}
		setprop("controls/fire-pressed", fire_pressed);
		switchfeedback("instrumentation/stick/button", "controls/fire-pressed");
		timedswitchmove("instrumentation/stick/button", 0.2, "dummy/dummy", 1);
		if ((bomb_command==1) or (bomb_button==1))
		{
			bomb_pressed=1;
		}
		else
		{
			bomb_pressed=0;
		}
		setprop("controls/bomb-pressed", bomb_pressed);
		switchfeedback("instrumentation/stick/bomb-button", "controls/bomb-pressed");
		timedswitchmove("instrumentation/stick/bomb-button", 0.2, "dummy/dummy", 1);
		if (brake_parking==0)
		{
			brake_angle=((left_brake+right_brake)/2)*16;
		}
		else
		{
			brake_angle=(brake_parking)*16;
		}
		#constants getted fom sick model

		brake_middle_x=abs((-0.005-0.016)/2);
		brake_middle_y=abs((-0.011-0.002)/2);
		brake_z=0.337;
		saxle_middle_x=abs((-0.032-0.049)/2);
		saxle_middle_y=abs((-0.038-0.018)/2);
		saxle_z=0.345;
		blocker_middle_x=abs((-0.038-0.043)/2);
		blocker_middle_y=abs((-0.031-0.026)/2);
		blocker_z=0.216;
		rod_middle_x=abs((-0.020-0.031)/2);
		rod_middle_y=abs((-0.023-0.010)/2);
		rod_z=0.338;

		saxle_shoulder_xy=math.sqrt((brake_middle_x-saxle_middle_x)*(brake_middle_x-saxle_middle_x)+(brake_middle_y-saxle_middle_y)*(brake_middle_y-saxle_middle_y));
		aa=saxle_shoulder_xy;
		saxle_shoulder_z=abs(brake_z-saxle_z);
		saxle_source_angle=math.atan2(abs(brake_z-saxle_z), saxle_shoulder_xy);
		saxle_source_angle_deg=saxle_source_angle/math.pi*180;
		saxle_angle=saxle_source_angle+brake_angle/180*math.pi;
		saxle_angle_deg=saxle_angle/math.pi*180;
		saxle_shoulder=math.sqrt(saxle_shoulder_xy*saxle_shoulder_xy+saxle_shoulder_z*saxle_shoulder_z);
		saxle_pos_xy=saxle_shoulder*math.cos(saxle_angle);
		saxle_pos_z=brake_z+saxle_shoulder*math.sin(saxle_angle);
		blocker_source_xy=math.sqrt((brake_middle_x-blocker_middle_x)*(brake_middle_x-blocker_middle_x)+(brake_middle_y-blocker_middle_y)*(brake_middle_y-blocker_middle_y));
		blocker_shoulder_xy=abs(blocker_source_xy-saxle_pos_xy);
		blocker_shoulder_z=abs(blocker_z-saxle_pos_z);
		blocker_angle=math.atan2(blocker_shoulder_xy, blocker_shoulder_z);
		blocker_angle_deg=blocker_angle/math.pi*180;

		rod_shoulder_xy=math.sqrt((brake_middle_x-rod_middle_x)*(brake_middle_x-rod_middle_x)+(brake_middle_y-rod_middle_y)*(brake_middle_y-rod_middle_y));
		rod_shoulder_z=abs(brake_z-rod_z);
		rod_source_angle=math.atan2(rod_shoulder_z, rod_shoulder_xy);
		rod_angle=rod_source_angle+brake_angle/180*math.pi;
		rod_angle_deg=rod_angle/math.pi*180;
		rod_z=rod_shoulder_xy*math.sin(rod_angle)/math.cos(rod_angle);
		rod_shift_z=-rod_shoulder_z+rod_z;

		setprop("instrumentation/stick/blocker_deg", blocker_angle_deg);
		setprop("instrumentation/stick/brake_rod_shift_z", rod_shift_z);

		setprop("instrumentation/stick/brake_deg", brake_angle);

		settimer(stick_buttons, 0.1);
	}

init_stick_buttons=func
{
	setprop("instrumentation/stick/brake_deg", 0);
	setprop("instrumentation/stick/blocker_deg", 0);
	switchinit("instrumentation/stick/fix", 1, "dummy/dummy");
	switchinit("instrumentation/stick/brake-all", 0, "dummy/dummy");
	setprop("controls/fire-command", 0);
	setprop("controls/armanent/trigger", 0);
	setprop("controls/fire-pressed", 0);
	switchinit("instrumentation/stick/button", 0, "dummy/dummy");
	setprop("controls/bomb-command", 0);
	setprop("controls/bomb-button", 0);
	setprop("controls/bomb-pressed", 0);
	switchinit("instrumentation/stick/bomb-button", 0, "dummy/dummy");
}

init_stick_buttons();

press_fire=func
	{
		setprop("controls/armanent/trigger", 1);
	}

unpress_fire=func
	{
		setprop("controls/armanent/trigger", 0);
	}

press_bomb=func
	{
		setprop("controls/bomb-button", 1);
	}

unpress_bomb=func
	{
		setprop("controls/bomb-button", 0);
	}

stick_buttons();

#-----------------------------------------------------------------------
#Cannon
stop_cannon=func
	{
	}

cannon=func
	{
		# check power
		in_service = getprop("instrumentation/cannon/serviceable");
		if (in_service == nil)
		{
			stop_cannon();
	 		return ( settimer(cannon, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_cannon();
		 	return ( settimer(cannon, 0.1) ); 
		}
		power=getprop("systems/electrical-real/outputs/machinegun/volts-norm");
		photo_power=getprop("systems/electrical-real/outputs/photo/volts-norm");
		button_pos=getprop("instrumentation/stick/button/switch-pos-norm");
		on=getprop("instrumentation/cannon/on");
		n37_count = getprop("ai/submodels/submodel[1]/count");
		ns23_inner_count = getprop("ai/submodels/submodel[3]/count");
		ns23_outer_count = getprop("ai/submodels/submodel[5]/count");
		if (
			(power==nil)
			or (photo_power==nil)
			or (button_pos==nil)
			or (on==nil)
			or (n37_count==nil) 
			or (ns23_inner_count==nil)
			or (ns23_outer_count==nil)
		)
		{
			stop_cannon();
			setprop("controls/cannon/error", 1);
	 		return ( settimer(cannon, 0.1) ); 
		}
		setprop("controls/cannon/error", 0);
		if (power==0) 
		{
			if (button_pos==1)
			{
				if (photo_power==0)
				{
					setprop("controls/fire-command", 0);
				}
			}
			else
			{
				if (on==1)
				{
					setprop("instrumentation/cannon/on", 0);
					cfire_cannon();
				}
			}
		}
		else
		{
			if (button_pos==1)
			{
				if (on==0)
				{
					fire_cannon();
				}
				setprop("instrumentation/cannon/on", 1);
				setprop("controls/fire-command", 0);
			}
			else
			{
				if (on==1)
				{
					setprop("instrumentation/cannon/on", 0);
					cfire_cannon();
				}
			}
		}
		if (n37_count==0) 
		{
			setprop("sounds/cannon/big-on", 0);
		}
		if (
			(ns23_inner_count==0) 
			and (ns23_outer_count==0)
		)
		{
			setprop("sounds/cannon/small-on", 0);
		}
		settimer(cannon, 0.1);
	}

init_cannon=func
{
	setprop("instrumentation/cannon/on", 0);
	setprop("instrumentation/cannon/serviceable", 1);
	setprop("sounds/cannon/big-on", 0);
	setprop("sounds/cannon/small-on", 0);
}

init_cannon();

cannon();

#-----------------------------------------------------------------------
#Wind process

stop_windprocess=func
	{
	}

windprocess=func
	{
		flaps=getprop("fdm/jsbsim/fcs/flap-pos-norm");
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		speed_brake=getprop("surface-positions/speedbrake-pos-norm");
		speed=getprop("velocities/airspeed-kt");
		canopy_pos=getprop("instrumentation/canopy/switch-pos-inter");
		if (
			(flaps==nil)
			or (gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
			or (speed_brake==nil)
			or (speed==nil)
			or (canopy_pos==nil)
		)
		{
			stop_windprocess();
			setprop("sounds/wind/error", 1);
			return ( settimer(windprocess, 0.1) ); 
		}
		volume=(speed*(1+flaps+gear_one_pos*0.3+gear_two_pos*0.3+gear_three_pos*0.3+speed_brake))/500;
		setprop("sounds/wind/volume", volume);
		if (canopy_pos<=0.2)
		{
			internal_factor=0.3+(canopy_pos/0.2);
		}
		if (canopy_pos>0.2)
		{
			internal_factor=1.0;
		}
		volume_internal=volume*internal_factor;
		setprop("sounds/wind/volume-internal", volume_internal);
		settimer(windprocess, 0.1);
	}

init_windprocess=func
{
		setprop("sounds/wind/volume", 0);
		setprop("sounds/wind/volume-internal", 0);
}

init_windprocess();

windprocess();

#-----------------------------------------------------------------------
#Gear valve
stop_gearvalve=func
	{
	}

gearvalve=func
	{
		# check power
		in_service = getprop("instrumentation/gear-valve/serviceable");
		if (in_service == nil)
		{
			stop_gearvalve();
	 		return ( settimer(gearvalve, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearvalve();
		 	return ( settimer(gearvalve, 0.1) ); 
		}
		switchmove("instrumentation/gear-valve/handle", "dummy/dummy");
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		set_pos=getprop("instrumentation/gear-valve/set-pos");
		handle_pos=getprop("instrumentation/gear-valve/handle/switch-pos-norm");
		#emergency handles positions
		left_handle_pos=getprop("instrumentation/gear-handles/left/switch-pos-norm");
		right_handle_pos=getprop("instrumentation/gear-handles/right/switch-pos-norm");
		gear_control_switch_pos=getprop("instrumentation/gear-control/switch-pos-norm");
		pressure=getprop("instrumentation/gear-valve/pressure-norm");	
		pressure_error=getprop("instrumentation/gear-valve/pressure-error");	
		bus=getprop("systems/electrical-real/bus");
		engine_running=getprop("engines/engine/running");
		if (
			(gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
			or (gear_one_tored==nil)
			or (gear_two_tored==nil)
			or (gear_three_tored==nil)
			or (set_pos==nil)
			or (handle_pos==nil)
			or (left_handle_pos==nil)
			or (right_handle_pos==nil)
			or (gear_control_switch_pos==nil)
			or (bus==nil) 
			or (engine_running==nil))
		{
			stop_gearvalve();
			setprop("instrumentation/gear-valve/error", 1);
	 		return ( settimer(gearvalve, 0.1) ); 
		}
		setprop("instrumentation/gear-valve/error", 0);
		if (set_pos==1)
		{
			if (handle_pos==1)
			{
				if (
					(gear_control_switch_pos==-1)
					and (left_handle_pos==1)
					and (right_handle_pos==1)
					and (gear_one_tored==0)
					and (gear_two_tored==0)
					and (gear_three_tored==0)
				)
				{
					switchmove("instrumentation/gear-valve", "fdm/jsbsim/gear/gear-cmd-norm-real");
					pressure=0.8-abs((gear_one_pos+gear_two_pos+gear_three_pos)/3)*0.5;
				}
				else
				{
					switchmove("instrumentation/gear-valve", "dummy/dummy");
					pressure=0.8-abs((gear_one_pos+gear_two_pos+gear_three_pos)/3)*0.5;
				}
			}
			else
			{
				switchswap("instrumentation/gear-valve");
			}
		}
		if (engine_running==1)
		{
			pressure_error=pressure_error+(1-2*rand(123))*0.01;
			if (pressure_error>0.03)
			{
				pressure_error=0.03;
			}
			if (pressure_error<-0.03)
			{
				pressure_error=-0.03;
			}
		}
		else
		{
			pressure_error=0;
		}
		setprop("instrumentation/gear-valve/pressure-norm", pressure);
		setprop("instrumentation/gear-valve/pressure-error", pressure_error);
		pressure_indicated=pressure+pressure_error;
		setprop("instrumentation/gear-valve/pressure-indicated", pressure_indicated);
		settimer(gearvalve, 0.1);
	}

init_gearvalve=func
{
	setprop("instrumentation/gear-valve/serviceable", 1);
	switchinit("instrumentation/gear-valve", 0, "dummy/dummy");
	switchinit("instrumentation/gear-valve/handle", 0, "dummy/dummy");
	setprop("instrumentation/gear-valve/pressure-norm", 0.8);
	setprop("instrumentation/gear-valve/pressure-indicated", 0.8);
	setprop("instrumentation/gear-valve/pressure-error", 0);
}

init_gearvalve();

gearvalve();

#-----------------------------------------------------------------------
#Gear handles
stop_gearhandles=func
	{
	}

gearhandles=func
	{
		# check power
		in_service = getprop("instrumentation/gear-handles/serviceable");
		if (in_service == nil)
		{
			stop_gearhandles();
	 		return ( settimer(gearhandles, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearhandles();
		 	return ( settimer(gearhandles, 0.1) ); 
		}
		switchmove("instrumentation/gear-handles/left", "dummy/dummy");
		switchmove("instrumentation/gear-handles/right", "dummy/dummy");
		settimer(gearhandles, 0.1);
	}

init_gearhandles=func
{
	setprop("instrumentation/gear-handles/serviceable", 1);
	switchinit("instrumentation/gear-handles/left", 0, "dummy/dummy");
	switchinit("instrumentation/gear-handles/right", 0, "dummy/dummy");
}

init_gearhandles();

gearhandles();

#--------------------------------------------------------------------
# Gear pressure indicator

# helper 
stop_gearpressure = func 
	{
	}

gearpressure = func 
	{
		# check power
		in_service = getprop("instrumentation/gear-pressure-indicator/serviceable" );
		if (in_service == nil)
		{
			stop_gearpressure();
	 		return ( settimer(gearpressure, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_gearpressure();
		 	return ( settimer(gearpressure, 0.1) ); 
		}
		bus=getprop("systems/electrical-real/bus");
		indicated_error=getprop("instrumentation/gear-pressure-indicator/indicated-pressure-error");	
		gear_down_real = getprop("fdm/jsbsim/gear/gear-cmd-norm-real");
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		if (
			(bus==nil)
			or (indicated_error==nil)
			or (gear_down_real==nil)
			or (gear_one_pos==nil)
			or (gear_two_pos==nil)
			or (gear_three_pos==nil)
		)
		{
			stop_gearpressure();
	 		return ( settimer(gearpressure, 0.1) ); 
		}
		indicated_error=indicated_error+(1-2*rand(123))*0.01;
		if (indicated_error>0.03)
		{
			indicated_error=0.03;
		}
		if (indicated_error<-0.03)
		{
			indicated_error=-0.03;
		}
		setprop("instrumentation/gear-pressure-indicator/indicated-pressure-error", indicated_error);
		if (bus==0) 
		{
			indicated_pressure=0;
		}
		else
		{
			indicated_pressure=0.5+abs(gear_down_real-(gear_one_pos+gear_two_pos+gear_three_pos)/3)*0.2+indicated_error;
		}
		setprop("instrumentation/gear-pressure-indicator/indicated-pressure-norm", indicated_pressure);
		settimer(gearpressure, 0.1);
	  }

# set startup configuration
init_gearpressure=func
{
	setprop("instrumentation/gear-pressure-indicator/serviceable", 1);
	setprop("instrumentation/gear-pressure-indicator/indicated-pressure-norm", 0);
	setprop("instrumentation/gear-pressure-indicator/indicated-pressure-error", 0);
}

init_gearpressure();

gearpressure();

#-----------------------------------------------------------------------
#Flaps valve
stop_flapsvalve=func
	{
	}

flapsvalve=func
	{
		in_service = getprop("instrumentation/flaps-valve/serviceable");
		if (in_service == nil)
		{
			stop_flapsvalve();
	 		return ( settimer(flapsvalve, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_flapsvalve();
		 	return ( settimer(flapsvalve, 0.1) ); 
		}
		switchmove("instrumentation/flaps-valve/handle", "dummy/dummy");
		flaps_pos = getprop("fdm/jsbsim/fcs/flap-pos-norm");
		set_pos=getprop("instrumentation/flaps-valve/set-pos");
		switch_pos=getprop("instrumentation/flaps-valve/switch-pos-norm");
		handle_pos=getprop("instrumentation/flaps-valve/handle/switch-pos-norm");
		flaps_control_switch_pos=getprop("instrumentation/flaps-control/switch-pos-norm");
		pressure=getprop("instrumentation/flaps-valve/pressure-norm");	
		pressure_error=getprop("instrumentation/flaps-valve/pressure-error");	
		bus=getprop("systems/electrical-real/bus");
		engine_running=getprop("engines/engine/running");
		tored = getprop("fdm/jsbsim/fcs/flap-tored");
		if (
			(flaps_pos==nil)
			or (set_pos==nil)
			or (switch_pos==nil)
			or (handle_pos==nil)
			or (flaps_control_switch_pos==nil)
			or (pressure==nil)
			or (pressure_error==nil)
			or (bus==nil)
			or (engine_running==nil)
			or (tored==nil)
		)
		{
			stop_flapsvalve();
			setprop("instrumentation/flaps-valve/error", 1);
	 		return ( settimer(flapsvalve, 0.1) ); 
		}
		setprop("instrumentation/flaps-valve/error", 0);
		if (
			(set_pos==1)
			and (flaps_pos!=set_pos)
		)
		{
			if (handle_pos==1)
			{
				if ((flaps_control_switch_pos==1) and (tored==0))
				{
					switchmove("instrumentation/flaps-valve", "fdm/jsbsim/fcs/flap-cmd-norm-real");
					pressure=0.8-abs(flaps_pos)*0.5;
				}
				else
				{
					switchmove("instrumentation/flaps-valve", "dummy/dummy");
					pressure=0.8-abs(switch_pos)*0.5;
				}
			}
			else
			{
				switchswap("instrumentation/flaps-valve");
			}
		}
		if (engine_running==1)
		{
			pressure_error=pressure_error+(1-2*rand(123))*0.01;
			if (pressure_error>0.03)
			{
				pressure_error=0.03;
			}
			if (pressure_error<-0.03)
			{
				pressure_error=-0.03;
			}
		}
		else
		{
			pressure_error=0;
		}
		setprop("instrumentation/flaps-valve/pressure-error", pressure_error);
		setprop("instrumentation/flaps-valve/pressure-norm", pressure);
		indicated_pressure=pressure+pressure_error;
		setprop("instrumentation/flaps-valve/pressure-indicated", indicated_pressure);
		settimer(flapsvalve, 0.1);
	}

init_flapsvalve=func
{
	setprop("instrumentation/flaps-valve/serviceable", 1);
	switchinit("instrumentation/flaps-valve", 0, "dummy/dummy");
	switchinit("instrumentation/flaps-valve/handle", 0, "dummy/dummy");
	setprop("instrumentation/flaps-valve/pressure-norm", 0.8);
	setprop("instrumentation/flaps-valve/pressure-indicated", 0.8);
	setprop("instrumentation/flaps-valve/pressure-error", 0);
}

init_flapsvalve();

flapsvalve();

#--------------------------------------------------------------------
# flaps pressure indicator

# helper 
stop_flapspressure = func 
	{
	}

flapspressure = func 
	{
		# check power
		in_service = getprop("instrumentation/flaps-pressure-indicator/serviceable" );
		if (in_service == nil)
		{
			stop_flapspressure();
	 		return ( settimer(flapspressure, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_flapspressure();
		 	return ( settimer(flapspressure, 0.1) ); 
		}
		bus=getprop("systems/electrical-real/bus");
		indicated_error=getprop("instrumentation/flaps-pressure-indicator/indicated-pressure-error");	
		flaps_set_pos = getprop("controls/flight/flaps");
		flaps_pos = getprop("fdm/jsbsim/fcs/flap-pos-norm");
		tored = getprop("fdm/jsbsim/fcs/flap-tored");
		if (
			(bus==nil)
			or (indicated_error==nil)
			or (flaps_set_pos==nil)
			or (flaps_pos==nil)
			or (tored==nil)
		)
		{
			stop_flapspressure();
	 		return ( settimer(flapspressure, 0.1) ); 
		}
		indicated_error=indicated_error+(1-2*rand(123))*0.01;
		if (indicated_error>0.03)
		{
			indicated_error=0.03;
		}
		if (indicated_error<-0.03)
		{
			indicated_error=-0.03;
		}
		setprop("instrumentation/flaps-pressure-indicator/indicated-pressure-error", indicated_error);
		if ((bus==0) or (tored==1))
		{
			indicated_pressure=0;
		}
		else
		{
			indicated_pressure=0.5+abs(flaps_set_pos-flaps_pos)*0.2+indicated_error;
		}
		setprop("instrumentation/flaps-pressure-indicator/indicated-pressure-norm", indicated_pressure);
		settimer(flapspressure, 0.1);
	  }

# set startup configuration
init_flapspressure=func
{
	setprop("instrumentation/flaps-pressure-indicator/serviceable", 1);
	setprop("instrumentation/flaps-pressure-indicator/indicated-pressure-norm", 0);
	setprop("instrumentation/flaps-pressure-indicator/indicated-pressure-error", 0);
}

init_flapspressure();

flapspressure();

#--------------------------------------------------------------------
#Trimmer

# helper 
stop_trimmer = func 
	{
	}

trimmer = func 
	{
		in_service = getprop("instrumentation/trimmer/serviceable" );
		if (in_service == nil)
		{
			stop_trimmer();
	 		return ( settimer(trimmer, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_trimmer();
		 	return ( settimer(trimmer, 0.1) ); 
		}
		power=getprop("systems/electrical-real/outputs/trimmer/volts-norm");
		elevator_offset=getprop("instrumentation/trimmer/elevator-offset");
		aileron_offset=getprop("instrumentation/trimmer/aileron-offset");
		aileron_trim=getprop("controls/flight/aileron-trim");
		elevator_trim=getprop("controls/flight/elevator-trim");
		if (
			(power==nil)
			or (elevator_offset==nil)
			or (aileron_offset==nil)
			or (elevator_trim==nil)
			or (aileron_trim==nil)
		)
		{
			stop_trimmer();
			setprop("instrumentation/trimmer/error", 1);
	 		return ( settimer(trimmer, 0.1) ); 
		}
		setprop("instrumentation/trimmer/error", 0);
		setprop("fdm/jsbsim/fcs/roll-trim-norm-indicated", aileron_trim);
		setprop("fdm/jsbsim/fcs/pitch-trim-norm-indicated", elevator_trim);
		if (power==1) 
		{
			aileron_trim=(aileron_trim+aileron_offset)/5;
			elevator_trim=(elevator_trim+elevator_offset)/5;
			setprop("fdm/jsbsim/fcs/roll-trim-norm-real", aileron_trim);
			setprop("fdm/jsbsim/fcs/pitch-trim-norm-real", elevator_trim);
		}
		settimer(trimmer, 0.1);
	  }

# set startup configuration
init_trimmer=func
{
	setprop("instrumentation/trimmer/serviceable", 1);
	elevator_offset=(1-2*rand(123))*0.1;
	setprop("instrumentation/trimmer/elevator-offset", elevator_offset);
	aileron_offset=(1-2*rand(123))*0.1;
	setprop("instrumentation/trimmer/aileron-offset", aileron_offset);
	setprop("fdm/jsbsim/fcs/roll-trim-norm-real", aileron_offset);
	setprop("fdm/jsbsim/fcs/pitch-trim-norm-real", elevator_offset);
	setprop("fdm/jsbsim/fcs/roll-trim-norm-indicated", 0);
	setprop("fdm/jsbsim/fcs/pitch-trim-norm-indicated", 0);
}

init_trimmer();

trimmer();

#--------------------------------------------------------------------
# Radio Compass

# helper 
stop_radiocompass = func 
	{
		setprop("instrumentation/radiocompass/lamp", 0);
		setprop("instrumentation/radiocompass/degree", 0);
		setprop("instrumentation/radiocompass/recieve-lamp", 0);
		setprop("sounds/radio-search-left/on", 0);
		setprop("sounds/radio-search-right/on", 0);
		setprop("sounds/radio-tune/on", 0);
		setprop("sounds/radio-morse/on", 0);
		setprop("sounds/radio-noise/on", 0);
	}

radiocompass = func 
	{
		var frequency=[0, 1, 2];
		var low_frequency=[0, 1, 2];
		var high_frequency=[0, 1, 2];
		var high_frequency=[0, 1, 2];
		in_service = getprop("instrumentation/radiocompass/serviceable" );
		if (in_service == nil)
		{
			stop_radiocompass();
	 		return ( settimer(radiocompass, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_radiocompass();
		 	return ( settimer(radiocompass, 0.1) ); 
		}
		switchmove("instrumentation/radiocompass/type", "dummy/dummy");
		switchmove("instrumentation/radiocompass/band", "dummy/dummy");
		switchmove("instrumentation/radiocompass/tl-or-tg/", "dummy/dummy");
		power=getprop("systems/electrical-real/outputs/radiocompass/volts-norm");
		brightness=getprop("instrumentation/radiocompass/brightness");
		loudness=getprop("instrumentation/radiocompass/loudness");
		tg_loudness=getprop("instrumentation/radiocompass/telegraph-loudness");
		tl_loudness=getprop("instrumentation/radiocompass/telephone-loudness");
		degree=getprop("instrumentation/adf/indicated-bearing-deg");
		current_degree=getprop("instrumentation/radiocompass/degree");
		frame_speed=getprop("instrumentation/radiocompass/frame-speed");
		type=getprop("instrumentation/radiocompass/type/switch-pos-norm");
		band=getprop("instrumentation/radiocompass/band/switch-pos-norm");
		frequency[0]=getprop("instrumentation/radiocompass/band[0]/frequency");
		low_frequency[0]=getprop("instrumentation/radiocompass/band[0]/low-frequency");
		high_frequency[0]=getprop("instrumentation/radiocompass/band[0]/high-frequency");
		frequency[1]=getprop("instrumentation/radiocompass/band[1]/frequency");
		low_frequency[1]=getprop("instrumentation/radiocompass/band[1]/low-frequency");
		high_frequency[1]=getprop("instrumentation/radiocompass/band[1]/high-frequency");
		frequency[2]=getprop("instrumentation/radiocompass/band[2]/frequency");
		low_frequency[2]=getprop("instrumentation/radiocompass/band[2]/low-frequency");
		high_frequency[2]=getprop("instrumentation/radiocompass/band[2]/high-frequency");
		vern=getprop("instrumentation/radiocompass/frequency-vern");
		vern_prev=getprop("instrumentation/radiocompass/frequency-vern-previous");
		ident=getprop("instrumentation/adf/ident");
		tl_or_tg=getprop("instrumentation/radiocompass/tl-or-tg/switch-pos-norm");
		repeat_time=getprop("instrumentation/radiocompass/repeat-time");
		wait_time=getprop("instrumentation/radiocompass/wait-time");
		wait_degree_time=getprop("instrumentation/radiocompass/wait-degree-time");
		if ((power==nil) 
			or (brightness==nil)
			or (loudness==nil)
			or (tg_loudness==nil)
			or (tl_loudness==nil)
			or (degree==nil)
			or (current_degree==nil)
			or (frame_speed==nil)
			or (type==nil)
			or (band==nil)
			or (frequency[0]==nil)
			or (low_frequency[0]==nil)
			or (high_frequency[0]==nil)
			or (frequency[1]==nil)
			or (low_frequency[1]==nil)
			or (high_frequency[1]==nil)
			or (frequency[2]==nil)
			or (low_frequency[2]==nil)
			or (high_frequency[2]==nil)
			or (vern==nil)
			or (vern_prev==nil)
			or (ident==nil)
			or (tl_or_tg==nil)
			or (repeat_time==nil)
			or (wait_time==nil)
			or (wait_degree_time==nil)
			)
		{
			stop_radiocompass();
			setprop("instrumentation/radiocompass/error", 1);
	 		return ( settimer(radiocompass, 0.1) ); 
		}
		setprop("instrumentation/radiocompass/error", 0);
		if (vern!=vern_prev)
		{
			step=vern-vern_prev;
			if (vern>360)
			{
				vern=vern-360;
			}
			if (vern<0)
			{
				vern=vern+360;
			}
			setprop("instrumentation/radiocompass/frequency-vern", vern);
			setprop("instrumentation/radiocompass/frequency-vern-previous", vern);
			frequency[band]=frequency[band]+step;
			if (frequency[band]>high_frequency[band])
			{
				frequency[band]=high_frequency[band];
			}
			if (frequency[band]<low_frequency[band])
			{
				frequency[band]=low_frequency[band];
			}
			setprop("instrumentation/radiocompass/band["~band~"]/frequency", frequency[band]);
		}
		setprop("instrumentation/adf/frequencies/selected-khz", frequency[band]);
		setprop("instrumentation/radiocompass/frequency", frequency[band]);
		for (var i=0; i < 3; i = i+1) 
		{
			if (band==i)
			{
				setprop("instrumentation/radiocompass/band["~i~"]/active/set-pos", 1);		
			}
			else
			{
				setprop("instrumentation/radiocompass/band["~i~"]/active/set-pos", 0);		
			}
			switchmove("instrumentation/radiocompass/band["~i~"]/active", "dummy/dummy");
		}
		if ((power==0) or (type==0))
		{
			setprop("instrumentation/radiocompass/frequency", 0);
			setprop("instrumentation/radiocompass/recieve-quality", 0);
			stop_radiocompass();
			setprop("instrumentation/radiocompass/wait-time", 0);
		 	return ( settimer(radiocompass, repeat_time) ); 
		}
		setprop("instrumentation/radiocompass/lamp", power*brightness);
		if ((type==1) or (type==3))
		{
			setprop("sounds/radio-tune/on", 0);
			setprop("sounds/radio-morse/on", 0);
			setprop("sounds/radio-noise/on", 0);
			if (ident=="")
			{
			 	setprop("instrumentation/radiocompass/degree", 0);
				setprop("instrumentation/radiocompass/recieve-lamp", 0);
				setprop("instrumentation/radiocompass/recieve-quality", 0);
				setprop("sounds/radio-search-left/on", 0);
				setprop("sounds/radio-search-right/on", 0);
				setprop("instrumentation/radiocompass/wait-time", 0);
			}
			else
			{
				if (wait_time<1)
				{
					wait_time=wait_time+0.1;
					setprop("instrumentation/radiocompass/wait-time", wait_time);
				}
				else
				{

					if (abs(degree-current_degree)>100)
					{
						if (wait_degree_time<0.5)
						{
							wait_degree_time=wait_degree_time+0.1;
							setprop("instrumentation/radiocompass/wait-degree-time", wait_degree_time);
							degree=current_degree;
						}
						else
						{
							setprop("instrumentation/radiocompass/wait-degree-time", 0);
						}
					}
					else
					{
						setprop("instrumentation/radiocompass/wait-degree-time", 0);
						if (type==1)
						{
							degree=current_degree+(degree-current_degree)*0.5;
						}
						else
						{
							degree=current_degree+(degree-current_degree)*abs(frame_speed);
						}
					}
				 	setprop("instrumentation/radiocompass/degree", degree);
					setprop("instrumentation/radiocompass/recieve-lamp", power*brightness);
					setprop("instrumentation/radiocompass/recieve-quality", 1);
					right_volume=0.5*(1+math.sin(degree/180*math.pi));
					left_volume=1-right_volume;
					right_volume=right_volume*(0.5+
						0.25*(1+math.cos(degree/180*math.pi)));
					left_volume=left_volume*(0.5+
						0.25*(1+math.cos(degree/180*math.pi)));
					left_volume=left_volume*loudness;
					right_volume=right_volume*loudness;
					setprop("sounds/radio-search-left/volume-norm", left_volume);
					setprop("sounds/radio-search-right/volume-norm", right_volume);
					setprop("sounds/radio-noise/on", 0);
					setprop("sounds/radio-search-left/on", 1);
					setprop("sounds/radio-search-right/on", 1);
				}
			}
		}
		if (type==2)
		{
			setprop("sounds/radio-search-left/on", 0);
			setprop("sounds/radio-search-right/on", 0);
			setprop("instrumentation/radiocompass/wait-time", 0);
		 	setprop("instrumentation/radiocompass/degree", 0);	
			setprop("instrumentation/radiocompass/recieve-lamp", 0);
			setprop("instrumentation/radiocompass/recieve-quality", 0);
			if (ident=="")
			{
				setprop("sounds/radio-tune/on", 0);
				setprop("sounds/radio-morse/on", 0);
				if (tl_or_tg==1)
				{
					setprop("instrumentation/radiocompass/noise-loudness", tl_loudness);
				}
				else
				{
					setprop("instrumentation/radiocompass/noise-loudness", tg_loudness);
				}
				setprop("sounds/radio-noise/on", 1);
			}
			else
			{
				if (tl_or_tg==1)
				{
					setprop("sounds/radio-morse/on", 0);
					setprop("sounds/radio-tune/on", 1);
				}
				else
				{
					setprop("sounds/radio-tune/on", 0);
					setprop("sounds/radio-morse/on", 1);
				}
				setprop("sounds/radio-noise/on", 0);
			}
		}
		settimer(radiocompass, repeat_time);
	}

# set startup configuration
init_radiocompass=func
{
	setprop("instrumentation/radiocompass/serviceable", 1);
	setprop("instrumentation/radiocompass/lamp", 0);
	setprop("instrumentation/radiocompass/brightness", 0.75);
	setprop("instrumentation/radiocompass/loudness", 0.25);
	setprop("instrumentation/radiocompass/telegraph-loudness", 0.75);
	setprop("instrumentation/radiocompass/telephone-loudness", 0.75);
	setprop("instrumentation/radiocompass/noise-loudness", 0.75);
	setprop("instrumentation/radiocompass/degree", 0);
	setprop("instrumentation/radiocompass/frequency", 0);
	setprop("instrumentation/radiocompass/wait-time", 0);
	setprop("instrumentation/radiocompass/wait-degree-time", 0);
	switchinit("instrumentation/radiocompass/type", 0, "dummy/dummy");
	switchinit("instrumentation/radiocompass/band", 0, "dummy/dummy");
	switchinit("instrumentation/radiocompass/band[0]/active", 1, "dummy/dummy");
	setprop("instrumentation/radiocompass/band[0]/frequency", 150);
	setprop("instrumentation/radiocompass/band[0]/low-frequency", 150);
	setprop("instrumentation/radiocompass/band[0]/high-frequency", 310);
	switchinit("instrumentation/radiocompass/band[1]/active", 0, "dummy/dummy");
	setprop("instrumentation/radiocompass/band[1]/frequency", 310);
	setprop("instrumentation/radiocompass/band[1]/low-frequency", 310);
	setprop("instrumentation/radiocompass/band[1]/high-frequency", 640);
	switchinit("instrumentation/radiocompass/band[2]/active", 0, "dummy/dummy");
	setprop("instrumentation/radiocompass/band[2]/frequency", 640);
	setprop("instrumentation/radiocompass/band[2]/low-frequency", 640);
	setprop("instrumentation/radiocompass/band[2]/high-frequency", 1300);
	setprop("instrumentation/radiocompass/frequency-vern", 0);
	setprop("instrumentation/radiocompass/frequency-vern-previous", 0);
	setprop("instrumentation/radiocompass/recieve-lamp", 0);
	setprop("instrumentation/radiocompass/recieve-quality", 0);
	switchinit("instrumentation/radiocompass/tl-or-tg/", 0, "dummy/dummy");
	setprop("sounds/radio-tune/on", 0);
	setprop("sounds/radio-morse/on", 0);
	setprop("sounds/radio-noise/on", 0);
	setprop("sounds/radio-search-left/on", 0);
	setprop("sounds/radio-search-right/on", 0);
	setprop("instrumentation/radiocompass/frame-speed", 0.5);
	setprop("instrumentation/radiocompass/repeat-time", 0.1);
}

init_radiocompass();

# start radio compass process first time
radiocompass ();

#----------------------------------------------------------------------------------
#Marker lamp

# helper 
stop_marklamp = func 
	{
	}

marklamp = func 
	{
		in_service = getprop("instrumentation/marker-beacon/serviceable" );
		if (in_service == nil)
		{
			stop_marklamp();
	 		return ( settimer(marklamp, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_marklamp();
		 	return ( settimer(marklamp, 0.1) ); 
		}
		inner=getprop("instrumentation/marker-beacon/inner");
		middle=getprop("instrumentation/marker-beacon/middle");
		outer=getprop("instrumentation/marker-beacon/outer");
		brightness=getprop("instrumentation/marker-beacon/brightness");
		mark_time=getprop("instrumentation/marker-beacon/mark-time");
		bus=getprop("systems/electrical-real/bus");
		if ((inner==nil)
			or (outer==nil)
			or (middle==nil)
			or (outer==nil)
			or (brightness==nil)
			or (mark_time==nil)
			or (bus==nil)
		)
		{
			stop_marklamp();
			setprop("instrumentation/marker-beacon/error", 1);
	 		return ( settimer(marklamp, 0.1) ); 
		}
		setprop("instrumentation/marker-beacon/error", 0);
		if (((inner==1)  or (middle==1) or (outer==1)) and (bus==1))
		{
			setprop("instrumentation/marker-beacon/lamp", brightness);
			setprop("instrumentation/marker-beacon/mark-time", 1);
		}
		else
		{
			if (mark_time>0)
			{
				mark_time=mark_time-0.1;
				if (mark_time<0)
				{
					mark_time=0;
				}
				setprop("instrumentation/marker-beacon/mark-time", mark_time);
			}
			else
			{
				setprop("instrumentation/marker-beacon/lamp", 0);
			}
		}
		settimer(marklamp, 0.1);
	  }

# set startup configuration
init_marklamp=func
{
	setprop("instrumentation/marker-beacon/brightness", 1);
	setprop("instrumentation/marker-beacon/lamp", 0);
	setprop("instrumentation/marker-beacon/mark-time", 0);
	#stop beeping
	setprop("instrumentation/marker-beacon/audio-btn", 0);
}

init_marklamp();

#start
marklamp();

#----------------------------------------------------------------------
# helper 
stop_canopy = func 
	{
	}

canopymove = func 
	{
		in_service = getprop("instrumentation/canopy/serviceable" );
		if (in_service == nil)
		{
			stop_canopy();
	 		return ( settimer(canopymove, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_canopy();
		 	return ( settimer(canopymove, 0.1) ); 
		}
		pos=getprop("instrumentation/canopy/switch-pos-norm");
		set_pos=getprop("instrumentation/canopy/set-pos");
		speed=getprop("velocities/airspeed-kt");
		tored=getprop("instrumentation/canopy/tored");
		if (
			(pos==nil)
			or (set_pos==nil)
			or (speed==nil)
			or (tored==nil)
		)
		{
			stop_canopy();
			setprop("instrumentation/canopy/error", 1);
			return ( settimer(canopymove, 0.1) ); 
		}
		if (tored==1)
		{
			stop_canopy();
			return ( settimer(canopymove, 0.1) ); 
		}
		speed_km=speed*1.852;
		if (
			(pos!=0)
			and (speed_km>300)
		)
		{
			tear_canopy();
			stop_canopy();
			return ( settimer(canopymove, 0.1) ); 
		}
		if (
			(pos!=0)
			and (speed_km>200)
		)
		{
			if (set_pos==0)
			{
				set_pos=1;
				setprop("instrumentation/canopy/set-pos", 1);
			}
		}
		if (
			(set_pos==1) 
			and (pos!=set_pos)
		)
		{
			setprop("instrumentation/canopy/lock/set-pos", 1);
			timedswitchmove("instrumentation/canopy/lock", 0.3, "dummy/dummy", 0);
			lock_pos=getprop("instrumentation/canopy/lock/switch-pos-norm");
			if (lock_pos==nil)
			{
				stop_canopy();
				setprop("instrumentation/canopy/error", 1);
		 		return ( settimer(canopymove, 0.1) ); 
			}
			if (lock_pos==1)
			{
				timedswitchmove("instrumentation/canopy", 2.8, "dummy/dummy", 0);
			}
		}
		else
		{
			if ((pos>0) and (pos<0.02))
			{
				setprop("instrumentation/canopy/lock/set-pos", 1);

			}
			else
			{
				setprop("instrumentation/canopy/lock/set-pos", 0);
			}
			timedswitchmove("instrumentation/canopy/lock", 0.3, "dummy/dummy", 0);
			timedswitchmove("instrumentation/canopy", 2.8, "dummy/dummy", 0);
		}
		canopy_impact=getprop("ai/submodels/canopy-impact");
		if (canopy_impact!=nil)
		{
			if (canopy_impact!="")
			{
				setprop("ai/submodels/canopy-impact", "");
				canopy_touch_down();
			}
		}
		canopy_drop=getprop("ai/submodels/canopy-drop");
		if (canopy_drop!=nil)
		{
			if (
				(tored==0) 
				and (canopy_drop==1)
			)
			{
				setprop("ai/submodels/canopy-drop", 0);
			}
		}
		settimer(canopymove, 0.1);
	}

# set startup configuration
init_canopymove=func
{
	setprop("instrumentation/canopy/serviceable", 1);
	setprop("instrumentation/canopy/tored", 0);
	switchinit("instrumentation/canopy", 1, "dummy/dummy");
	switchinit("instrumentation/canopy/lock", 0, "dummy/dummy");
}

tear_canopy=func
{
	setprop("ai/submodels/canopy-drop", 1);
	setprop("instrumentation/canopy/tored", 1);
	switchinit("instrumentation/canopy", 1, "dummy/dummy");
	switchinit("instrumentation/canopy/lock", 0, "dummy/dummy");
	canopytoredsound();
}

canopytoredsound = func
	{
		setprop("sounds/canopy-crash/volume", 1);
		setprop("sounds/canopy-crash/on", 1);
		settimer(canopytoredsoundoff, 0.3);
	}

canopytoredsoundoff = func
	{
		setprop("sounds/canopy-crash/on", 0);
	}

canopy_touch_down = func
	{
		setprop("sounds/canopy-crash/volume", 0.2);
		setprop("sounds/canopy-crash/on", 1);
		settimer(end_canopy_touch_down, 3);
	}

end_canopy_touch_down = func
	{
		setprop("sounds/canopy-crash/on", 0);
	}

init_canopymove();

#start
canopymove();

#----------------------------------------------------------------------
# helper 
stop_photo = func 
	{
	}

photo = func 
	{
		in_service = getprop("instrumentation/photo/serviceable" );
		if (in_service == nil)
		{
			stop_photo();
	 		return ( settimer(photo, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_photo();
		 	return ( settimer(photo, 0.1) ); 
		}
		photo_power=getprop("systems/electrical-real/outputs/photo/volts-norm");
		photo_machinegun_power=getprop("systems/electrical-real/outputs/photo-machinegun/volts-norm");
		headsight_ready=getprop("instrumentation/headsight/sign");
		button_pos=getprop("instrumentation/stick/button/switch-pos-norm");
		on=getprop("instrumentation/photo/on");
		maked=getprop("instrumentation/photo/maked");
		view_number=getprop("sim/current-view/view-number");
		logged_view_number=getprop("instrumentation/photo/view-number");
		if ((photo_power==nil)
			or (photo_machinegun_power==nil)
			or (headsight_ready==nil)
			or (button_pos==nil)
			or (on==nil)
			or (maked==nil)
			or (view_number==nil)
			or (logged_view_number==nil)
		)
		{
			stop_photo();
			setprop("instrumentation/photo/error", 1);
	 		return ( settimer(photo, 0.1) ); 
		}
		setprop("instrumentation/photo/error", 0);
		if (photo_power==0)
		{
			if (on==1)
			{
				setprop("instrumentation/photo/on", 0);
			}
			if (logged_view_number!=-1)
			{
				machinegun_view_back();
			}
		}
		else
		{
			if (button_pos==1)
			{
				if (
					((on==0) and (button_pos==1))
					and ((maked==0) or (photo_machinegun_power>0))
				)
				{
					setprop("controls/fire-command", 0);
					setprop("instrumentation/photo/on", 1);
					setprop("instrumentation/photo/maked", 1);
					if (photo_machinegun_power>0)
					{
						if (view_number==1)
						{
							make_photo();
						}
						else
						{
							start_machinegun_photo();
						}
					}
					else
					{
						make_photo();
					}
				}
			}
			else
			{
				setprop("instrumentation/photo/maked", 0);
				if (logged_view_number!=-1)
				{
					machinegun_view_back();
				}
			}
		}
		settimer(photo, 0.1);
	  }

# set startup configuration
init_photo=func
{
	setprop("instrumentation/photo/serviceable", 1);
	setprop("instrumentation/photo/on", 0);
	setprop("instrumentation/photo/maked", 0);
	setprop("instrumentation/photo/view-number", -1);
	setprop("sounds/photo/on", 0);
}

init_photo();

#make photo
make_photo = func
	{
		setprop("sounds/photo/on", 1);
		fgcommand("screen-capture");
		settimer(end_photo, 1);
	}

end_photo = func
	{
		setprop("instrumentation/photo/on", 0);
		setprop("sounds/photo/on", 0);
	}

start_machinegun_photo = func
	{
		view_number=getprop("sim/current-view/view-number");
		if (view_number==nil)
		{
			return (0);
		}
		setprop("instrumentation/photo/view-number", view_number);
		setprop("sim/current-view/view-number", 1);
		settimer(make_photo, 0.5);
		return (1);
	}

machinegun_view_back = func
	{
		view_number=getprop("instrumentation/photo/view-number");
		if (view_number==nil)
		{
			return (0);
		}
		setprop("sim/current-view/view-number", view_number);
		setprop("instrumentation/photo/view-number", -1);
		return (1);
	}

#start
photo();

#----------------------------------------------------------------------
#Droptank
stop_droptank = func 
	{
	}

droptank = func 
	{
		in_service = getprop("instrumentation/drop-tank/serviceable" );
		if (in_service == nil)
		{
			stop_droptank();
	 		return ( settimer(droptank, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_droptank();
		 	return ( settimer(droptank, 0.1) ); 
		}
		drop_power=getprop("systems/electrical-real/outputs/drop-tank/volts-norm");
		bomb_power=getprop("systems/electrical-real/outputs/bomb/volts-norm");
		bomb_button_pos=getprop("instrumentation/stick/bomb-button/switch-pos-norm");
		left_level=getprop("consumables/fuel/tank[3]/level-gal_us");
		right_level=getprop("consumables/fuel/tank[4]/level-gal_us");
		dropped=getprop("instrumentation/drop-tank/dropped");
		if (
			(drop_power==nil)
			or (bomb_power==nil)
			or (bomb_button_pos==nil)
			or (left_level==nil)
			or (right_level==nil)
			or (dropped==nil)
		)
		{
			stop_droptank();
			setprop("instrumentation/drop-tank/error", 1);
	 		return ( settimer(droptank, 0.1) ); 
		}
		setprop("instrumentation/drop-tank/error", 0);
		if (bomb_button_pos==1)
		{
			if (drop_power>0)
			{
				setprop("consumables/fuel/tank[3]/level-gal_us", 0);
				setprop("consumables/fuel/tank[3]/selected", 0);
				setprop("consumables/fuel/tank[4]/level-gal_us", 0);
				setprop("consumables/fuel/tank[4]/selected", 0);
				left_level=0;
				right_level=0;
				if (bomb_power>0)
				{
					setprop("ai/submodels/bomb-tank", 1);
				}
				else
				{
					setprop("ai/submodels/drop-tank", 1);
				}
				settimer(setdrop, 0.2);
			}
			setprop("controls/bomb-command", 0);
		}
		if ((dropped=1) and ((left_level>0) or (right_level>0)))
		{
			setprop("instrumentation/drop-tank/dropped", 0);
			setprop("fdm/jsbsim/tanks/fastened", 1);
			setprop("ai/submodels/drop-tank", 0);
			setprop("ai/submodels/bomb-tank", 0);
		}
		left_bomb_tank_impact=getprop("ai/submodels/left-bomb-tank-impact");
		if (left_bomb_tank_impact!=nil)
		{
			if (left_bomb_tank_impact!="")
			{
				setprop("ai/submodels/left-bomb-tank-impact", "");
				bomb_explode();
			}
		}
		right_bomb_tank_impact=getprop("ai/submodels/right-bomb-tank-impact");
		if (right_bomb_tank_impact!=nil)
		{
			if (right_bomb_tank_impact!="")
			{
				setprop("ai/submodels/right-bomb-tank-impact", "");
				bomb_explode();
			}
		}
		left_drop_tank_impact=getprop("ai/submodels/left-drop-tank-impact");
		if (left_drop_tank_impact!=nil)
		{
			if (left_drop_tank_impact!="")
			{
				setprop("ai/submodels/left-drop-tank-impact", "");
				tank_down();
			}
		}
		right_drop_tank_impact=getprop("ai/submodels/right-drop-tank-impact");
		if (right_drop_tank_impact!=nil)
		{
			if (right_drop_tank_impact!="")
			{
				setprop("ai/submodels/right-drop-tank-impact", "");
				tank_down();
			}
		}
		settimer(droptank, 0.1);
	  }

# set startup configuration
init_droptank=func
{
	setprop("instrumentation/drop-tank/serviceable", 1);
	setprop("instrumentation/drop-tank/dropped", 0);
	setprop("ai/submodels/drop-tank", 0);
	setprop("ai/submodels/bomb-tank", 0);
	setprop("fdm/jsbsim/tanks/fastened", 1);
	#values to move object to real zero
	setprop("instrumentation/drop-tank/one", 1);
}

init_droptank();

setdrop = func
	{
		setprop("instrumentation/drop-tank/dropped", 1);
		setprop("fdm/jsbsim/tanks/fastened", 0);
	}

bomb_explode = func
	{
		setprop("sounds/bomb-explode/on", 1);
		settimer(end_bomb_explode, 3);
	}

end_bomb_explode = func
	{
		setprop("sounds/bomb-explode/on", 0);
	}

tank_down = func
	{
		setprop("sounds/tank-down/on", 1);
		settimer(end_tank_down, 3);
	}

end_tank_down = func
	{
		setprop("sounds/tank-down/on", 0);
	}

#start
droptank();

#-----------------------------------------------------------------------
#Pedals
stop_pedals=func
	{
	}

pedals=func
	{
		# check power
		in_service = getprop("instrumentation/pedals/serviceable");
		if (in_service == nil)
		{
			stop_pedals();
	 		return( 0 ); 
		}
		if ( in_service != 1 )
		{
			stop_pedals();
		 	return( 0 ); 
		}
		#Get values
		rudder=getprop("controls/flight/rudder");
		if (rudder==nil) 
		{
			stop_pedals();
	 		return( 0 ); 
		}
		setprop("fdm/jsbsim/fcs/rudder-cmd-norm-real", -rudder);
		#constants getted from pedals model
		pedals_shift_x=(0.0882)*rudder;
		pedals_tubes_source_angle=math.atan2(0, 0.087)/math.pi*180;
		pedals_tubes_next_angle=math.atan2(pedals_shift_x, 0.087)/math.pi*180;
		pedals_tubes_shift_angle=-(pedals_tubes_next_angle-pedals_tubes_source_angle);
		pedals_shift_rod_x=pedals_shift_x/0.087*0.057;

		setprop("instrumentation/pedals/shift_x", pedals_shift_x);
		setprop("instrumentation/pedals/shift_tubes_angle", pedals_tubes_shift_angle);
		setprop("instrumentation/pedals/tubes_source_angle", pedals_tubes_source_angle);
		setprop("instrumentation/pedals/tubes_next_angle", pedals_tubes_next_angle);
		setprop("instrumentation/pedals/shift_rod_x", pedals_shift_rod_x);
		setprop("instrumentation/pedals/rudder", rudder);

		return(1);
	}

init_pedals=func
{
	setprop("instrumentation/pedals/serviceable", 1);
	setprop("instrumentation/pedals/shift_x", 0);
	setprop("instrumentation/pedals/shift_rod_x", 0);
	setprop("instrumentation/pedals/shift_tubes_angle", 0);
	setprop("instrumentation/pedals/rudder", 0);
}

init_pedals();

setlistener("surface-positions/rudder-pos-norm", pedals);


#-----------------------------------------------------------------------
#Max g load tremble
stop_gtremble=func
	{
	}

gtremble=func()
	{
		tremble_on=getprop("fdm/jsbsim/gtremble/on");
		tremble_way=getprop("fdm/jsbsim/gtremble/way");
		tremble_max=getprop("fdm/jsbsim/gtremble/max");
		tremble_step=getprop("fdm/jsbsim/gtremble/step");
		tremble_current=getprop("fdm/jsbsim/gtremble/current");
		crack=getprop("fdm/jsbsim/accelerations/crack");
		crack_on=getprop("sounds/aircraft-crack/on");
		crack_volume=getprop("sounds/aircraft-crack/volume");
		crack_next_time=getprop("sounds/aircraft-crack/next-time");
		if (
			(tremble_on == nil)
			or (tremble_way == nil)
			or (tremble_max == nil)
			or (tremble_current == nil)
			or (tremble_step == nil)
			or (crack == nil)
			or (crack_on == nil)
			or (crack_volume == nil)
			or (crack_next_time == nil)
		)
		{
			stop_gtremble();
			return ( settimer(gtremble, 0.1) ); 
		}
		if (crack==1)
		{
			if (crack_on==0)
			{
				if (crack_next_time<=0)
				{
					crack_next_time=rand()+(1-crack_volume);
					setprop("sounds/aircraft-crack/next-time", crack_next_time);
					crack_sound();
				}
				else
				{
					crack_next_time=crack_next_time-0.1;
					setprop("sounds/aircraft-crack/next-time", crack_next_time);
				}
			}
		}
		if (( tremble_on != 1 ) and (tremble_current==0))
		{
			stop_gtremble();
			return ( settimer(gtremble, 0.1) ); 
		}
		tremble_current=tremble_current+tremble_way*tremble_step;
		setprop("fdm/jsbsim/gtremble/current", tremble_current);
		if (abs(tremble_current)>=tremble_max)
		{
			tremble_way=-1*(abs(tremble_current)/tremble_current);
			setprop("fdm/jsbsim/gtremble/way", tremble_way);
		}
		return ( settimer(gtremble, 0.1) ); 
	}

crack_sound = func
	{
		setprop("sounds/aircraft-crack/on", 1);
		settimer(end_crack_sound, 1);
	}

end_crack_sound = func
	{
		setprop("sounds/aircraft-crack/on", 0);
	}

init_gtremble=func()
{
	setprop("fdm/jsbsim/gtremble/on", 0);
	setprop("fdm/jsbsim/gtremble/way", 1);
	setprop("fdm/jsbsim/gtremble/max", 1);
	setprop("fdm/jsbsim/gtremble/step", 0.3);
	setprop("fdm/jsbsim/gtremble/current", 0);
	setprop("sounds/aircraft-crack/on", 0);
	setprop("sounds/aircraft-crack/volume", 0);
	setprop("sounds/aircraft-crack/next-time", 0);
	setprop("sounds/aircraft-creaking/on", 0);
	setprop("sounds/aircraft-creaking/volume", 0);
}

init_gtremble();

gtremble();

#-----------------------------------------------------------------------
#Aircraft break
aircraft_lock = func 
	{
		#Stop instruments
		setprop("instrumentation/radioaltimeter/serviceable", 0);
		setprop("instrumentation/clock/serviceable", 0);
		setprop("instrumentation/manometer/serviceable", 0);
		setprop("instrumentation/gear-indicator/serviceable", 0);
		setprop("instrumentation/flaps-lamp/serviceable", 0);
		setprop("instrumentation/fuelometer/serviceable", 0);
		setprop("instrumentation/altimeter-lamp/serviceable", 0);
		setprop("instrumentation/gear-lamp/serviceable", 0);
		setprop("instrumentation/oxygen-pressure-meter/serviceable", 0);
		setprop("instrumentation/artifical-horizon/serviceable", 0);
		setprop("instrumentation/gyrocompass/serviceable", 0);
		setprop("instrumentation/brake-pressure-meter/serviceable", 0);
		setprop("instrumentation/ignition-lamp/serviceable", 0);
		setprop("instrumentation/airspeedometer/serviceable", 0);
		setprop("instrumentation/gastermometer/serviceable", 0);
		setprop("instrumentation/motormeter/serviceable", 0);
		setprop("instrumentation/tachometer/serviceable", 0);
		setprop("instrumentation/machometer/serviceable", 0);
		setprop("instrumentation/turnometer/serviceable", 0);
		setprop("instrumentation/vertspeedometer/serviceable", 0);
		setprop("instrumentation/gear-pressure-indicator/serviceable", 0);
		setprop("instrumentation/flaps-pressure-indicator/serviceable", 0);
		setprop("instrumentation/marker-beacon/serviceable", 0);
		#Lock controls
		setprop("instrumentation/gear-control/serviceable", 0);
		setprop("instrumentation/flaps-control/serviceable", 0);
		setprop("instrumentation/stop-control/serviceable", 0);
		setprop("instrumentation/speed-brake-control/serviceable", 0);
		setprop("instrumentation/gas-control/serviceable", 0);
		setprop("instrumentation/ignition-button/serviceable", 0);
		setprop("instrumentation/buster-control/serviceable", 0);
		setprop("instrumentation/headsight/serviceable", 0);
		setprop("instrumentation/stick/serviceable", 0);
		setprop("instrumentation/cannon/serviceable", 0);
		setprop("instrumentation/gear-valve/serviceable", 0);
		setprop("instrumentation/gear-handles/serviceable", 0);
		setprop("instrumentation/flaps-valve/serviceable", 0);
		setprop("instrumentation/trimmer/serviceable", 0);
		setprop("instrumentation/radiocompass/serviceable", 0);
		setprop("instrumentation/photo/serviceable", 0);
		setprop("instrumentation/drop-tank/serviceable", 0);
		setprop("instrumentation/pedals/serviceable", 0);
		#Switch off power
		setprop("instrumentation/switches/battery/set-pos", 0);
		setprop("instrumentation/switches/generator/set-pos", 0);
		#Switch off engine
		setprop("controls/engines/engine/cutoff", 1);
		setprop("controls/engines/engine/cutoff-reason", "aircraft break");
	}

aircraft_crash=func(crashtype, crashg, solid)
	{
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		if (crashed==nil)
		{
			return (0);
		}
		if (crashed==0)
		{
			setprop("fdm/jsbsim/simulation/crash-type", crashtype);
			setprop("fdm/jsbsim/simulation/crash-g", crashg);
			setprop("fdm/jsbsim/simulation/crashed", 1);
			aircraft_lock();
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(0, "crash");
			}
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(1, "crash");
			}
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(2, "crash");
			}
		}

		if (solid==1)
		{
			aircraft_crash_sound();
		}
		else
		{
			aircraft_water_crash_sound();
		}

		setprop("sim/replay/disable", 1);
		setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
		return (1);
	}

stop_aircraftbreakprocess = func 
	{
	}

aircraftbreakprocess=func
	{
		# check state
		in_service = getprop("processes/aircraft-break/enabled" );
		if (in_service == nil)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		maximum_g=getprop("fdm/jsbsim/accelerations/Nz-max");
		lat = getprop("position/latitude-deg");
		lon = getprop("position/longitude-deg");
		#check altitude positions
		altitude=getprop("position/altitude-ft");
		elevation=getprop("position/ground-elev-ft");
		speed=getprop("velocities/airspeed-kt");
		exploded=getprop("fdm/jsbsim/simulation/exploded");
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		#Gear middle
		wow[0]=getprop("gear/gear[0]/wow");
		#Gear left
		wow[1]=getprop("gear/gear[1]/wow");
		#Gear right
		wow[2]=getprop("gear/gear[2]/wow");
		#Wing Left
		wow[3]=getprop("gear/gear[3]/wow");
		#Wing right
		wow[4]=getprop("gear/gear[4]/wow");
		#Fus nose down
		wow[5]=getprop("gear/gear[5]/wow");
		#Fus nose up
		wow[6]=getprop("gear/gear[6]/wow");
		#Fus middle down
		wow[7]=getprop("gear/gear[7]/wow");
		#Cabin middle up
		wow[8]=getprop("gear/gear[8]/wow");
		#Back stab up
		wow[9]=getprop("gear/gear[9]/wow");
		#Fus back down
		wow[10]=getprop("gear/gear[10]/wow");
		if (
			(pilot_g==nil)
			or (maximum_g==nil)
			or (lat==nil)
			or (lon==nil)
			or (altitude==nil)
			or (elevation==nil)
			or (speed==nil)
			or (exploded==nil)
			or (crashed==nil)
			or (wow[0]==nil)
			or (wow[1]==nil)
			or (wow[2]==nil)
			or (wow[3]==nil)
			or (wow[4]==nil)
			or (wow[5]==nil)
			or (wow[6]==nil)
			or (wow[7]==nil)
			or (wow[8]==nil)
			or (wow[9]==nil)
			or (wow[10]==nil)
		)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		speed_km=speed*1.852;
		info = geodinfo(lat, lon);
		if (info == nil)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		if (
			(info[0] == nil)
			or (info[1] == nil)
		)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		real_altitude_m = (0.3048*(altitude-elevation));
		if (
			(real_altitude_m<=25)
			and (speed_km>10)
		)
		{
			terrain_lege_height=0;
			i=0;
			foreach(terrain_name; info[1].names)
			{
				if (
					(terrain_lege_height<25)
					and
					(
						(terrain_name=="EvergreenForest")
						or (terrain_name=="DeciduousForest")
						or (terrain_name=="MixedForest")
						or (terrain_name=="RainForest")
						or (terrain_name=="Urban")
						or (terrain_name=="Town")
					)
				)
				{
					terrain_lege_height=25;
				}
				if (
					(terrain_lege_height<20)
					and
					(
						(terrain_name=="Orchard")
						or (terrain_name=="CropWood")

					)
				)
				{
					terrain_lege_height=20;
				}
			}
			if (real_altitude_m<terrain_lege_height)
			{
				crashed=aircraft_crash("tree hit", pilot_g, info[1].solid);
			}
		}
		if (pilot_g>(maximum_g/2))
		{
			if (pilot_g>maximum_g)
			{
				setprop("sounds/aircraft-crack/volume", 1);
				setprop("sounds/aircraft-creaking/volume", 1);
				setprop("fdm/jsbsim/gtremble/max", 1);
			}
			else
			{
				tremble_max=math.sqrt((pilot_g-(maximum_g/2))/(maximum_g/2));
				setprop("sounds/aircraft-crack/volume", tremble_max);
				setprop("sounds/aircraft-creaking/volume", tremble_max);
				setprop("fdm/jsbsim/gtremble/max", 1);
			}
			if (pilot_g>(maximum_g*0.75))
			{
				setprop("fdm/jsbsim/accelerations/crack", 1);
			}
			setprop("sounds/aircraft-creaking/on", 1);
			setprop("fdm/jsbsim/accelerations/crack", 1);
			setprop("fdm/jsbsim/gtremble/on", 1);
		}
		else
		{
			setprop("fdm/jsbsim/accelerations/crack", 0);
			setprop("sounds/aircraft-creaking/on", 0);
			setprop("fdm/jsbsim/gtremble/on", 0);
		}
		if (
			(exploded!=1)
			and
			(abs(pilot_g)>maximum_g)
		)
		{
			exploded=1;
			aircraft_lock();
			aircraft_explode(pilot_g);
		}
		if (
			(
				(wow[3]==1)
				or (wow[4]==1)
				or (wow[5]==1)
				or (wow[6]==1)
				or (wow[7]==1)
				or (wow[8]==1)
				or (wow[9]==1)
				or (wow[10]==1)
			)
			and
			(
				(speed_km>275)
				or (pilot_g>2.5)
				or
				(
					(speed_km>250)
					and
					(
						(info[1].solid!=1)
						or (info[1].bumpiness>0.1)
						or (info[1].rolling_friction>0.05)
						or (info[1].friction_factor<0.7)
					)
				)
			)
		)
		{
			crashed=aircraft_crash("ground slide", pilot_g, info[1].solid);
		}
		if (crashed==1)
		{
			if (exploded==0)
			{
				exploded=1;
				aircraft_explode(pilot_g);
			}
			if (
				(
					(wow[3]==1)
					or (wow[4]==1)
					or (wow[5]==1)
					or (wow[6]==1)
					or (wow[7]==1)
					or (wow[8]==1)
					or (wow[9]==1)
					or (wow[10]==1)
				)
				and (speed_km>10)
			)
			{
				var pos= geo.Coord.new().set_latlon(lat, lon);
				setprop("fdm/jsbsim/simulation/wildfire-ignited", 1);
				wildfire.ignite(pos, 1);
			}
		}
		settimer(aircraftbreakprocess, 0.1);
	}

init_aircraftbreakprocess=func
{
	setprop("fdm/jsbsim/simulation/exploded", 0);
	setprop("fdm/jsbsim/simulation/crashed", 0);
	setprop("fdm/jsbsim/accelerations/explode-g", 0);
	setprop("fdm/jsbsim/accelerations/crack", 0);
	setprop("fdm/jsbsim/simulation/crash-type", "");
	setprop("fdm/jsbsim/accelerations/crash-g", 0);
	setprop("fdm/jsbsim/velocities/v-down-previous", 0);
	setprop("processes/aircraft-break/enabled", 1);
}

init_aircraftbreakprocess();

aircraft_explode = func(pilot_g)
	{
		setprop("fdm/jsbsim/simulation/explode-g", pilot_g);
		setprop("fdm/jsbsim/simulation/exploded", 1);
		setprop("sounds/aircraft-explode/on", 1);
		setprop("sim/replay/disable", 1);
		setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
		settimer(end_aircraft_explode, 3);
	}

end_aircraft_explode = func
	{
		#Lock swithes
		setprop("instrumentation/panels/left/serviceable", 0);
		setprop("instrumentation/panels/right/serviceable", 0);
		setprop("sounds/aircraft-explode/on", 0);
	}

#Start
aircraftbreakprocess();

#--------------------------------------------------------------------
# Aircraft breaks listener

# helper 
stop_aircraftbreaklistener = func 
	{
	}

aircraftbreaklistener = func 
	{
		# check state
		in_service = getprop("listneners/aircraft-break/enabled" );
		if (in_service == nil)
		{
			return ( stop_aircraftbreaklistener );
		}
		if ( in_service != 1 )
		{
			return ( stop_aircraftbreaklistener );
		}
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		lat = getprop("position/latitude-deg");
		lon = getprop("position/longitude-deg");
		exploded=getprop("fdm/jsbsim/simulation/exploded");
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		#Gear middle
		wow[0]=getprop("gear/gear[0]/wow");
		#Gear left
		wow[1]=getprop("gear/gear[1]/wow");
		#Gear right
		wow[2]=getprop("gear/gear[2]/wow");
		#Wing Left
		wow[3]=getprop("gear/gear[3]/wow");
		#Wing right
		wow[4]=getprop("gear/gear[4]/wow");
		#Fus nose down
		wow[5]=getprop("gear/gear[5]/wow");
		#Fus nose up
		wow[6]=getprop("gear/gear[6]/wow");
		#Fus middle down
		wow[7]=getprop("gear/gear[7]/wow");
		#Cabin middle up
		wow[8]=getprop("gear/gear[8]/wow");
		#Back stab up
		wow[9]=getprop("gear/gear[9]/wow");
		#Fus back down
		wow[10]=getprop("gear/gear[10]/wow");
		tanks_fastened=getprop("fdm/jsbsim/tanks/fastened");
		gear_started=getprop("fdm/jsbsim/init/finally-initialized");
		if (
			(pilot_g==nil)
			or (lat==nil)
			or (lon==nil)
			or (exploded==nil)
			or (crashed==nil)
			or (wow[0]==nil)
			or (wow[1]==nil)
			or (wow[2]==nil)
			or (wow[3]==nil)
			or (wow[4]==nil)
			or (wow[5]==nil)
			or (wow[6]==nil)
			or (wow[7]==nil)
			or (wow[8]==nil)
			or (wow[9]==nil)
			or (wow[10]==nil)
			or (tanks_fastened==nil)
			or (gear_started==nil)
		)
		{
			return ( stop_aircraftbreaklistener ); 
		}
		if (gear_started==0)
		{
			return ( stop_aircraftbreaklistener ); 
		}
		if (
			(
				(wow[6]==1)
				or (wow[8]==1)
				or (wow[9]==1)
			)
			or
			(
				(
					(wow[3]==1)
					or (wow[4]==1)
					or (wow[5]==1)
					or (wow[7]==1)
					or (wow[10]==1)
				)
				and (pilot_g>3)
			)
			or (
				(tanks_fastened==1)
				and (pilot_g>1.5)
				and 
				(
					((wow[3]==1) and (wow[7]==1))
					or
					((wow[4]==1) and (wow[7]==1))
				)
			)
		)
		{
			info = geodinfo(lat, lon);
			if (info == nil)
			{
				return ( stop_aircraftbreaklistener ); 
			}
			if (info[1]==nil)
			{
				return ( stop_aircraftbreaklistener ); 
			}
			crashed=aircraft_crash("ground hit", pilot_g, info[1].solid);
			if (exploded==0)
			{
				exploded=1;
				aircraft_explode(pilot_g);
			}
		}
	}

init_aircraftbreaklistener = func 
{
	setprop("sounds/aircraft-crash/on", 0);
	setprop("sounds/aircraft-water-crash/on", 0);
	setprop("listneners/aircraft-break/enabled", 1);
}

init_aircraftbreaklistener();

aircraft_crash_sound = func
	{
		speed=getprop("velocities/airspeed-kt");
		sounded=getprop("sounds/aircraft-crash/on");
		if ((speed!=nil) and (sounded!=nil))
		{
			speed_km=speed*1.852;
			if ((speed_km>10) and (sounded==0))
			{
				setprop("sounds/aircraft-crash/on", 1);
				settimer(end_aircraft_crash, 3);
			}
		}
	}

end_aircraft_crash = func
	{
		setprop("sounds/aircraft-crash/on", 0);
	}

aircraft_water_crash_sound = func
	{
		speed=getprop("velocities/airspeed-kt");
		sounded=getprop("sounds/aircraft-water-crash/on");
		if ((speed!=nil) and (sounded!=nil))
		{
			speed_km=speed*1.852;
			if ((speed_km>10) and (sounded==0))
			{
				setprop("sounds/aircraft-water-crash/on", 1);
				settimer(end_aircraft_water_crash, 3);
			}
		}
	}

end_aircraft_water_crash = func
	{
		setprop("sounds/aircraft-water-crash/on", 0);
	}

setlistener("gear/gear[3]/wow", aircraftbreaklistener);
setlistener("gear/gear[4]/wow", aircraftbreaklistener);
setlistener("gear/gear[5]/wow", aircraftbreaklistener);
setlistener("gear/gear[6]/wow", aircraftbreaklistener);
setlistener("gear/gear[7]/wow", aircraftbreaklistener);
setlistener("gear/gear[8]/wow", aircraftbreaklistener);
setlistener("gear/gear[9]/wow", aircraftbreaklistener);
setlistener("gear/gear[10]/wow", aircraftbreaklistener);

#-----------------------------------------------------------------------
#Aircraft repair

aircraft_unlock=func
	{
		#Repair instruments
		setprop("instrumentation/radioaltimeter/serviceable", 1);
		setprop("instrumentation/clock/serviceable", 1);
		setprop("instrumentation/manometer/serviceable", 1);
		setprop("instrumentation/gear-indicator/serviceable", 1);
		setprop("instrumentation/flaps-lamp/serviceable", 1);
		setprop("instrumentation/fuelometer/serviceable", 1);
		setprop("instrumentation/altimeter-lamp/serviceable", 1);
		setprop("instrumentation/gear-lamp/serviceable", 1);
		setprop("instrumentation/oxygen-pressure-meter/serviceable", 1);
		setprop("instrumentation/artifical-horizon/serviceable", 1);
		setprop("instrumentation/gyrocompass/serviceable", 1);
		setprop("instrumentation/brake-pressure-meter/serviceable", 1);
		setprop("instrumentation/ignition-lamp/serviceable", 1);
		setprop("instrumentation/airspeedometer/serviceable", 1);
		setprop("instrumentation/gastermometer/serviceable", 1);
		setprop("instrumentation/motormeter/serviceable", 1);
		setprop("instrumentation/tachometer/serviceable", 1);
		setprop("instrumentation/machometer/serviceable", 1);
		setprop("instrumentation/turnometer/serviceable", 1);
		setprop("instrumentation/vertspeedometer/serviceable", 1);
		setprop("instrumentation/gear-pressure-indicator/serviceable", 1);
		setprop("instrumentation/flaps-pressure-indicator/serviceable", 1);
		setprop("instrumentation/marker-beacon/serviceable", 1);
		#Repair controls
		setprop("instrumentation/gear-control/serviceable", 1);
		setprop("instrumentation/flaps-control/serviceable", 1);
		setprop("instrumentation/stop-control/serviceable", 1);
		setprop("instrumentation/speed-brake-control/serviceable", 1);
		setprop("instrumentation/gas-control/serviceable", 1);
		setprop("instrumentation/ignition-button/serviceable", 1);
		setprop("instrumentation/buster-control/serviceable", 1);
		setprop("instrumentation/headsight/serviceable", 1);
		setprop("instrumentation/stick/serviceable", 1);
		setprop("instrumentation/cannon/serviceable", 1);
		setprop("instrumentation/gear-valve/serviceable", 1);
		setprop("instrumentation/gear-handles/serviceable", 1);
		setprop("instrumentation/flaps-valve/serviceable", 1);
		setprop("instrumentation/trimmer/serviceable", 1);
		setprop("instrumentation/radiocompass/serviceable", 1);
		setprop("instrumentation/photo/serviceable", 1);
		setprop("instrumentation/drop-tank/serviceable", 1);
		setprop("instrumentation/pedals/serviceable", 1);
		setprop("instrumentation/panels/left/serviceable", 1);
		setprop("instrumentation/panels/right/serviceable", 1);
	}

aircraft_repair=func
	{
		#Repair gears
		setprop("fdm/jsbsim/gear/unit[0]/pos-norm", 1);
		setprop("fdm/jsbsim/gear/unit[1]/pos-norm", 1);
		setprop("fdm/jsbsim/gear/unit[2]/pos-norm", 1);

		setprop("fdm/jsbsim/gear/unit[0]/tored", 0);
		setprop("fdm/jsbsim/gear/unit[1]/tored", 0);
		setprop("fdm/jsbsim/gear/unit[2]/tored", 0);

		setprop("fdm/jsbsim/gear/unit[0]/break-type", "");
		setprop("fdm/jsbsim/gear/unit[1]/break-type", "");
		setprop("fdm/jsbsim/gear/unit[2]/break-type", "");

		setprop("fdm/jsbsim/gear/unit[0]/stuck", 0);
		setprop("fdm/jsbsim/gear/unit[1]/stuck", 0);
		setprop("fdm/jsbsim/gear/unit[2]/stuck", 0);

		init_gearvalve();
		init_gearhandles();

		#Repair flaps
		setprop("fdm/jsbsim/fcs/flap-tored", 0);
		init_flapsvalve();

		#Repair canopy
		setprop("instrumentation/canopy/tored", 0);

		#Unlock aircraft
		aircraft_unlock();

		#Set repaired
		setprop("fdm/jsbsim/simulation/crashed", 0);
		setprop("fdm/jsbsim/simulation/exploded", 0);
	}

aircraft_init=func
	{
		#Init indication instrumentation
		init_radioaltimeter();
		init_chron();
		init_manometer();
		init_magnetic_compass();
		init_gearindicator();
		init_flapslamp();
		init_fuelometer();
		init_altlamp();
		init_gearlamp();
		init_oxypressmeter();
		init_arthorizon();
		init_gyrocompass();
		init_brakepressmeter();
		init_ignitionlamp();
		init_airspeedometer();
		init_gastermometer();
		init_motormeter();
		init_tachometer();
		init_machometer();
		init_turnometer();
		init_vertspeedometer();
		init_headsight();
		init_gearpressure();
		init_flapspressure();
		init_radiocompass();
		init_marklamp();

		#Init processes
		init_gearbreaksprocess();
		init_gearmove();
		init_flapsbreaksprocess();
		init_engineprocess();
		init_realelectric();
		init_lightning();
		init_cannon();
		init_windprocess();
		init_photo();
		init_droptank();
		init_aircraftbreakprocess();

		#Init control instrumentattion
		init_gear_control();
		init_flapscontrol();
		init_stopcontrol();
		init_speedbrakecontrol();
		init_gascontrol();
		init_ignitionbutton();
		init_bustercontrol();
		init_leftpanel();
		init_rightpanel();
		init_stick();
		init_stick_buttons();
		init_gearvalve();
		init_gearhandles();
		init_flapsvalve();
		init_trimmer();
		init_canopymove();
		init_pedals();
	}

aircraft_start_refuel=func
	{
		setprop("processes/engine/on", 0);
		wow_one=getprop("gear/gear/wow");
		wow_two=getprop("gear/gear[1]/wow");
		wow_three=getprop("gear/gear[2]/wow");
		setprop("consumables/fuel/tank[0]/level-gal_us", 1.5);
		setprop("consumables/fuel/tank[1]/level-gal_us", 300);
		setprop("consumables/fuel/tank[2]/level-gal_us", 0);
		setprop("consumables/fuel/tank[3]/level-gal_us", 60);
		setprop("consumables/fuel/tank[4]/level-gal_us", 60);
	}

aircraft_end_refuel=func
	{
		setprop("consumables/fuel/tank[2]/level-gal_us", 30);
		setprop("processes/engine/on", 1);
		setprop("ai/submodels/submodel[1]/count", 40);
		setprop("ai/submodels/submodel[3]/count", 80);
		setprop("ai/submodels/submodel[4]/count", 80);
		setprop("fdm/jsbsim/weights/shells/n37", 40);
		setprop("fdm/jsbsim/weights/shells/n23-inner", 80);
		setprop("fdm/jsbsim/weights/shells/n23-outer", 80);
		setprop("consumables/oxygen/pressure-norm", 0.75);
	}

aircraft_refuel=func
	{
		aircraft_start_refuel();
		settimer(aircraft_end_refuel, 1);
	}


end_aircraftrestart=func
	{
		aircraft_end_refuel();
		#Start break listeners
		setprop("listneners/aircraft-break/enabled", 1);
		setprop("listneners/gear-break/enabled", 1);
		#Start break processes
		setprop("processes/aircraft-break/enabled", 1);
		setprop("processes/gear-break/enabled", 1);
		#Unlock replay
		setprop("sim/replay/disable", 0);
		setprop("sim/menubar/default/menu[1]/item[8]/enabled", 1);
	}

aircraft_restart=func
	{
		#Get freeze values
		sim_clock=getprop("sim/freeze/clock");
		sim_master=getprop("sim/freeze/master");
		if (
			(sim_clock!=nil)
			and (sim_master!=nil)
		)
		{
			#Stop break listeners
			setprop("listneners/aircraft-break/enabled", 0);
			setprop("listneners/gear-break/enabled", 0);
			#Stop break processes
			setprop("processes/aircraft-break/enabled", 0);
			setprop("processes/gear-break/enabled", 0);
			#Lock controls
			aircraft_lock();
			setprop("sim/freeze/clock", 1);
			setprop("sim/freeze/master", 1);
			aircraft_repair();
			#Lock replay
			setprop("sim/replay/disable", 1);
			setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
			#Additional gears restart
			setprop("fdm/jsbsim/gear/gear-pos-norm", 1);
			setprop("fdm/jsbsim/gear/gear-pos-norm-inter", 1);
			setprop("gear/gear[0]/position-norm", 1);
			setprop("gear/gear[1]/position-norm", 1);
			setprop("gear/gear[2]/position-norm", 1);
			#Aircraft initialization
			aircraft_init();
			init_controls();
			init_fdm();
			init_positions();
			aircraft_start_refuel();
			setprop("fdm/jsbsim/simulation/reset", 1);
			setprop("sim/freeze/clock", sim_clock);
			setprop("sim/freeze/master", sim_master);
			settimer(end_aircraftrestart, 1);
		}
	}

setprop("sim/freeze/state-saved/clock", 0);
setprop("sim/freeze/state-saved/master", 0);

#-----------------------------------------------------------------------
#Aircraft autostart

aurostart_switch_move=func(autostart_pos, switch_name, set_pos, autostart_current_pos)
	{
		if (autostart_current_pos==autostart_pos)
		{
			switch_pos=getprop(switch_name~"/switch-pos-norm");
			if (switch_pos==nil)
			{
				return (-1);
			}
			if (switch_pos!=set_pos)
			{
				setprop(switch_name~"/set-pos", set_pos);
			}
			else
			{
				autostart_current_pos=autostart_current_pos+1;
				setprop("processes/autostart/pos", autostart_current_pos);
			}
		}
		return (autostart_current_pos);
	}

stop_autostart_process = func 
	{
		setprop("processes/autostart/elapsed-time", 0);
		setprop("processes/autostart/pos", 0);
	}

autostart_process = func 
	{
		in_service = getprop("processes/autostart/enabled" );
		if (in_service == nil)
		{
			stop_autostart_process();
			return ( settimer(autostart_process, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_autostart_process();
			return ( settimer(autostart_process, 0.1) ); 
		}
		pos=getprop("processes/autostart/pos");
		elapsed_time=getprop("processes/autostart/elapsed-time");
		wow_one=getprop("gear/gear/wow");
		wow_two=getprop("gear/gear[1]/wow");
		wow_three=getprop("gear/gear[2]/wow");
		exploded=getprop("fdm/jsbsim/simulation/exploded");
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		starter_command=getprop("controls/engines/engine/starter-command");
		engine_running=getprop("engines/engine/running");
		throttle_pos=getprop("instrumentation/gas-control/switch-pos-norm");
		throttle_set_pos=getprop("controls/engines/engine/throttle");
		mail_tank_lbs=getprop("consumables/fuel/tank[1]/level-lbs");
		if (
			(pos==nil)
			or (elapsed_time==nil)
			or (wow_one==nil)
			or (wow_two==nil)
			or (wow_three==nil)
			or (exploded==nil)
			or (crashed==nil)
			or (starter_command==nil)
			or (engine_running==nil)
			or (throttle_pos==nil)
			or (throttle_set_pos==nil)
			or (mail_tank_lbs==nil)
		)
		{
			stop_autostart_process();
			return ( settimer(autostart_process, 0.1) ); 
		}

		if (
			(wow_one==0)
			or (wow_two==0)
			or (wow_three==0)
			or (exploded==1)
			or (crashed==1)
			or (mail_tank_lbs<10)
		)
		{
			stop_autostart_process();
			return ( 0 ); 
		}

		if (elapsed_time<240)
		{
			elapsed_time=elapsed_time+0.1;
			setprop("processes/autostart/elapsed-time", elapsed_time);
		}
		else
		{
			stop_autostart_process();
			return ( 0 ); 
		}

		pos=aurostart_switch_move(0, "instrumentation/stop-control", 1, pos);


		if (pos==1) 
		{
			if (engine_running==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		pos=aurostart_switch_move(2, "instrumentation/switches/battery", 0, pos);
		pos=aurostart_switch_move(3, "instrumentation/switches/generator", 0, pos);
		pos=aurostart_switch_move(4, "instrumentation/switches/pump", 0, pos);
		pos=aurostart_switch_move(5, "instrumentation/switches/isolation-valve", 0, pos);
		pos=aurostart_switch_move(6, "instrumentation/switches/ignition-type", 0, pos);
		pos=aurostart_switch_move(7, "instrumentation/switches/ignition", 0, pos);
		pos=aurostart_switch_move(8, "instrumentation/switches/engine-control", 0, pos);
		pos=aurostart_switch_move(9, "instrumentation/switches/third-tank-pump", 0, pos);
		pos=aurostart_switch_move(10, "instrumentation/stop-control", 0, pos);
		pos=aurostart_switch_move(11, "instrumentation/gas-control/lock", 0, pos);

		if (pos==12)
		{
			if (throttle_pos!=0.11)
			{
				setprop("controls/engines/engine/throttle", 0.11);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		pos=aurostart_switch_move(13, "instrumentation/gas-control/fix", 0, pos);

		if (pos==14)
		{
			if (throttle_pos!=0)
			{
				setprop("controls/engines/engine/throttle", 0);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		pos=aurostart_switch_move(15, "instrumentation/gas-control/lock", 1, pos);
		pos=aurostart_switch_move(16, "instrumentation/switches/battery", 1, pos);
		pos=aurostart_switch_move(17, "instrumentation/switches/pump", 1, pos);
		pos=aurostart_switch_move(18, "instrumentation/switches/ignition", 1, pos);
		pos=aurostart_switch_move(19, "instrumentation/switches/engine-control", 1, pos);

		if (pos==20) 
		{
			if (starter_command==0)
			{
				starter_command=1;
				setprop("controls/engines/engine/starter-command", starter_command);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==21) 
		{
			if (engine_running==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		pos=aurostart_switch_move(22, "instrumentation/switches/generator", 1, pos);
		pos=aurostart_switch_move(23, "instrumentation/switches/ignition", 1, pos);
		pos=aurostart_switch_move(24, "instrumentation/gas-control/lock", 0, pos);

		if (pos==25)
		{
			if (throttle_pos!=0.2)
			{
				setprop("controls/engines/engine/throttle", 0.2);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		pos=aurostart_switch_move(26, "instrumentation/gas-control/fix", 1, pos);

		if (pos==27)
		{
			if (throttle_pos!=0.04)
			{
				setprop("controls/engines/engine/throttle", 0.04);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		pos=aurostart_switch_move(28, "instrumentation/switches/ignition", 0, pos);

		pos=aurostart_switch_move(29, "instrumentation/switches/trimmer", 1, pos);
		pos=aurostart_switch_move(30, "instrumentation/switches/horizon", 1, pos);
		pos=aurostart_switch_move(31, "instrumentation/switches/radioaltimeter", 1, pos);
		pos=aurostart_switch_move(32, "instrumentation/switches/radiocompass", 1, pos);
		pos=aurostart_switch_move(33, "instrumentation/switches/drop-tank", 1, pos);
		pos=aurostart_switch_move(34, "instrumentation/switches/headsight", 1, pos);
		pos=aurostart_switch_move(35, "instrumentation/switches/machinegun", 1, pos);

		pos=aurostart_switch_move(36, "instrumentation/canopy", 0, pos);

		if (pos==37)
		{
			setprop("processes/autostart/elapsed-time", 0);
			return (1);
		}
		else
		{
			return ( settimer(autostart_process, 0.1) );
		}


	}

# set startup configuration
init_autostart_process = func
{
	setprop("processes/autostart/enabled", 1);
	setprop("processes/autostart/elapsed-time", 0);
	setprop("processes/autostart/pos", 0);
}

aircraft_autostart = func
{
	setprop("processes/autostart/pos", 0);
	setprop("processes/autostart/elapsed-time", 0);
	autostart_process();
}

init_autostart_process();

#-----------------------------------------------------------------------
#Property tree dump

dump_properties=func
{
	fg_home = getprop("sim/fg-home" );
	if (fg_home!=nil)
	{
		io.write_properties(fg_home~"/state/properties-dump.xml", "/");
	}
}

#-----------------------------------------------------------------------
#Menu changer

stop_menuchanger_process = func 
	{
		setprop("processes/menuchanger/on", 0);
	}

menuchanger_process = func 
	{
		in_service = getprop("processes/menuchanger/enabled" );
		if (in_service == nil)
		{
			stop_menuchanger();
			return ( settimer(menuchanger_process, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_menuchanger();
			return ( settimer(menuchanger_process, 0.1) ); 
		}
		autostart_elapsed_time=getprop("processes/autostart/elapsed-time");
		replay=getprop("sim/freeze/replay-state");
		if (autostart_elapsed_time==nil)
		{
			stop_menuchanger_process();
			return ( settimer(menuchanger_process, 0.1) ); 
		}
		if (autostart_elapsed_time>0)
		{
			replay=0;
			setprop("sim/replay/disable", 1);
			setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
		}
		else
		{
			setprop("sim/replay/disable", 0);
			setprop("sim/menubar/default/menu[1]/item[8]/enabled", 1);
		}
		if (replay!=nil)
		{
			if (replay==1)
			{
				setprop("sim/menubar/default/menu[50]/item[0]/enabled", 0);
				setprop("sim/menubar/default/menu[50]/item[1]/enabled", 0);
				setprop("sim/menubar/default/menu[50]/item[2]/enabled", 0);
				setprop("sim/menubar/default/menu[50]/item[3]/enabled", 0);
			}
			else
			{
				setprop("sim/menubar/default/menu[50]/item[0]/enabled", 1);
				setprop("sim/menubar/default/menu[50]/item[1]/enabled", 1);
				setprop("sim/menubar/default/menu[50]/item[2]/enabled", 1);
				setprop("sim/menubar/default/menu[50]/item[3]/enabled", 1);
			}
		}
		else
		{
			setprop("sim/menubar/default/menu[50]/item[0]/enabled", 1);
			setprop("sim/menubar/default/menu[50]/item[1]/enabled", 1);
			setprop("sim/menubar/default/menu[50]/item[2]/enabled", 1);
			setprop("sim/menubar/default/menu[50]/item[3]/enabled", 1);
		}
		return ( settimer(menuchanger_process, 0.1) );
	}

# set startup configuration
init_menuchanger_process = func
{
	setprop("processes/menuchanger/enabled", 1);
	setprop("processes/menuchanger/on", 1);
}

init_menuchanger_process();

menuchanger_process();
