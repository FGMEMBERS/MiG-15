fautotakeoff = func {

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
		}
		if (ns23_inner_count>0) 
		{
			ns23_inner_count=ns23_inner_count-1;
			setprop("ai/submodels/NS-23-I", 1);
		}
		if (ns23_outer_count>0) 
		{
			ns23_outer_count=ns23_outer_count-1;
			setprop("ai/submodels/NS-23-O", 1);
		}
		setprop("fdm/jsbsim/shells/n37", n37_count);
		setprop("fdm/jsbsim/shells/n23-inner", ns23_inner_count);
		setprop("fdm/jsbsim/shells/n23-outer", ns23_outer_count);
		return (1);
	}

cfire_cannon = func 
	{
		setprop("ai/submodels/N-37", 0);
		setprop("ai/submodels/NS-23-I", 0);
		setprop("ai/submodels/NS-23-O", 0);
		setprop("sounds/cannon/big-on", 0);
		setprop("sounds/cannon/small-on", 0);
	}

cannon_shells_weght=func
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
			return (settimer (cannon_shells_weght, 0.1));
		}
		shell_weight_as_fuel=(n37_count*0.735+(ns23_inner_count+ns23_outer_count)*0.2)/2.76;
		setprop("consumables/fuel/tank[5]/level-gal_us", shell_weight_as_fuel);
		settimer (cannon_shells_weght, 0.1);
	}

init_cannon_shells_weght=func
	{
		setprop("consumables/fuel/tank[5]/selected", 0);
	}

init_cannon_shells_weght();

cannon_shells_weght();

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

	setprop("fdm/jsbsim/gear/gear-cmd-norm", 1);
	setprop("fdm/jsbsim/gear/gear-cmd-norm-real", 1);

	setprop("fdm/jsbsim/gear/unit[0]/pos-norm", 1);
	setprop("fdm/jsbsim/gear/unit[1]/pos-norm", 1);
	setprop("fdm/jsbsim/gear/unit[2]/pos-norm", 1);

	setprop("fdm/jsbsim/gear/unit[0]/pos-norm-real", 1);
	setprop("fdm/jsbsim/gear/unit[1]/pos-norm-real", 1);
	setprop("fdm/jsbsim/gear/unit[2]/pos-norm-real", 1);

	setprop("fdm/jsbsim/gear/unit[0]/z-position", -1.459/0.0254);
	setprop("fdm/jsbsim/gear/unit[1]/z-position", -1.332/0.0254);
	setprop("fdm/jsbsim/gear/unit[2]/z-position", -1.332/0.0254);

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
		setprop("gear/gear[0]/position-norm", 1);
		setprop("gear/gear[1]/position-norm", 1);
		setprop("gear/gear[2]/position-norm", 1);
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
		canopy = getprop("fdm/jsbsim/systems/canopy/pos");
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
		setprop("fdm/jsbsim/gear/unit["~gear_number~"]/pos-norm-real", 0);
		setprop("fdm/jsbsim/gear/unit["~gear_number~"]/z-position", 0);
#		setprop("gear/gear["~gear_number~"]/position-norm", 0);
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
		mach=getprop("velocities/mach");
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
			or (mach==nil)
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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		maximum_g=getprop("fdm/jsbsim/accelerations/Nz-max");
		maximum_g_tenth=getprop("fdm/jsbsim/accelerations/Nz-max-tenth");
		speed=getprop("velocities/airspeed-kt");
		mach=getprop("velocities/mach");
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
			or (mach==nil)
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

#Gear move process
#--------------------------------------------------------------------

gear_control_up = func
	{
		setprop("fdm/jsbsim/systems/gearcontrol/control-input", 0);
	}

gear_control_down = func
	{
		setprop("fdm/jsbsim/systems/gearcontrol/control-input", 1);
	}

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

one_gear_move=func(gear_num, gear_pos, gear_command, gear_stuck, move_time, z_max, max_angle, speed_km, speed_limit)
	{
		if (
			(gear_stuck==0)
			or
			(gear_command>gear_pos)
		)
		{
			timedhmove("fdm/jsbsim/gear/unit["~gear_num~"]/pos-norm-real", "fdm/jsbsim/gear/gear-cmd-norm-real", move_time);
			gear_pos=getprop("fdm/jsbsim/gear/unit["~gear_num~"]/pos-norm-real");
			if (gear_pos==nil)
			{
				return (0);
			}
			if  (gear_pos>=0.5)
			{
				gear_angle=(1-(gear_pos-0.5)/0.5)*max_angle/180*math.pi;
				z_poz=z_max*(-1/0.0254)*math.cos(gear_angle);
				setprop("fdm/jsbsim/gear/unit["~gear_num~"]/z-position", z_poz);
			}
			if (
				(speed_km>speed_limit) 
				and (gear_pos>0)
				and (gear_command<gear_pos)
			)
			{
				if (gear_command<gear_pos)
				{
					gearstuck(gear_num, 1);
				}
				else
				{
					gearstuck(gear_num, 0);
				}
			}
			if (gear_pos==1)
			{
				setprop("fdm/jsbsim/gear/unit["~gear_num~"]/stuck", 0);
			}
		}
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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
		gear_one_tored=getprop("fdm/jsbsim/gear/unit[0]/tored");
		gear_two_tored=getprop("fdm/jsbsim/gear/unit[1]/tored");
		gear_three_tored=getprop("fdm/jsbsim/gear/unit[2]/tored");
		gear_one_stuck=getprop("fdm/jsbsim/gear/unit[0]/stuck");
		gear_two_stuck=getprop("fdm/jsbsim/gear/unit[1]/stuck");
		gear_three_stuck=getprop("fdm/jsbsim/gear/unit[2]/stuck");
		gear_command=getprop("fdm/jsbsim/systems/gearcontrol/control-switch");
		gear_command_real=getprop("fdm/jsbsim/gear/gear-cmd-norm-real");

		speed=getprop("velocities/airspeed-kt");

		#get gear valve and handles values
		valve_press=getprop("fdm/jsbsim/systems/gearvalve/pressure-pos");
		left_handle_pos=getprop("fdm/jsbsim/systems/gearvalve/left-handle-switch");
		right_handle_pos=getprop("fdm/jsbsim/systems/gearvalve/right-handle-switch");
		#get power values
		pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		engine_running=getprop("engines/engine/running");
		set_generator=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");

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
			or (gear_command==nil)
			or (gear_command_real==nil)
			or (speed==nil)

			or (valve_press==nil)
			or (left_handle_pos==nil)
			or (right_handle_pos==nil)
			or (pump==nil)
			or (engine_running==nil)
			or (set_generator==nil)

		)
		{
			stop_gearmove();
			return ( settimer(gearmove, 0.1) ); 
		}

		if (
			(
				(pump==1) 
				and (valve_press>=0.75)
			)
			and
			(
				(engine_running!=1)
				or (set_generator!=1)
			)
			and (gear_command_real!=gear_command)
		)
		{
			pump=0;
			setprop("fdm/jsbsim/systems/leftpanel/pump-input", 0);
		}

		if (
			(pump==1)
			and (valve_press>=0.75)
			and (left_handle_pos==0)
			and (right_handle_pos==0)
		)
		{
			setprop("fdm/jsbsim/gear/gear-cmd-norm-real", gear_command);
			gear_command_real=gear_command;
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
		if (gear_one_tored==0)
		{
			one_gear_move(0, gear_one_pos, gear_command_real, gear_one_stuck, 4.2, 1.459, 105, speed_km, 375);
		}
		if (gear_two_tored==0)
		{
			one_gear_move(1, gear_two_pos, gear_command_real, gear_two_stuck, 4.8, 1.332, 95, speed_km, 355);
		}
		if (gear_three_tored==0)
		{
			one_gear_move(2, gear_three_pos, gear_command_real, gear_three_stuck, 5, 1.332, 95, speed_km, 350);
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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
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

#-----------------------------------------------------------------------

init_gearvalve=func
{
	setprop("fdm/jsbsim/systems/gearvalve/left-handle-input", 0);
	setprop("fdm/jsbsim/systems/gearvalve/left-handle-command", 0);
	setprop("fdm/jsbsim/systems/gearvalve/left-handle-pos", 0);
	setprop("fdm/jsbsim/systems/gearvalve/right-handle-input", 0);
	setprop("fdm/jsbsim/systems/gearvalve/right-handle-command", 0);
	setprop("fdm/jsbsim/systems/gearvalve/right-handle-pos", 0);
	setprop("fdm/jsbsim/systems/gearvalve/safer-input", 0);
	setprop("fdm/jsbsim/systems/gearvalve/safer-command", 0);
	setprop("fdm/jsbsim/systems/gearvalve/safer-pos", 0);
	setprop("fdm/jsbsim/systems/gearvalve/valve-input", 0);
	setprop("fdm/jsbsim/systems/gearvalve/valve-command", 0);
	setprop("fdm/jsbsim/systems/gearvalve/valve-pos", 0);
	setprop("fdm/jsbsim/systems/gearvalve/pressure-pos", 1);
}

init_gearvalve();

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
		fuel_control_pos=getprop("fdm/jsbsim/systems/fuelcontrol/control-switch");
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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
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
stop_flapsprocess = func 
	{
	}

flapsprocess = func 
	{
		# check power
		var in_service = getprop("fdm/jsbsim/systems/flapscontrol/serviceable" );
		if (in_service == nil)
		{
			stop_flapsprocess();
	 		return ( settimer(flapsprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_flapsprocess();
		 	return ( settimer(flapsprocess, 0.1) ); 
		}
		# get flaps values
		var tored = getprop("fdm/jsbsim/fcs/flap-tored");
		var flaps_command_pos = getprop("fdm/jsbsim/fcs/flap-cmd-norm");
		# get instrumentation values
		var flaps_go=getprop("fdm/jsbsim/systems/flapscontrol/flaps-go");
		var valve_press=getprop("fdm/jsbsim/systems/flapsvalve/pressure-pos");
		#get pump value
		var pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		var engine_running=getprop("engines/engine/running");
		var set_generator=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");
		if (
			(tored==nil)
			or (flaps_command_pos == nil)
			or (flaps_go==nil)
			or (valve_press==nil)
			or (pump==nil)
			or (engine_running==nil)
			or (set_generator==nil)
		)
		{
			stop_flapsprocess();
			return ( settimer(flapsprocess, 0.1) ); 
		}
		if ((pump==1) and (valve_press==1.0) and (tored==0) and (flaps_go==1))
		{
			if ((engine_running==1) and (set_generator==1))
			{
				setprop("fdm/jsbsim/fcs/flap-cmd-norm-real", flaps_command_pos);
			}
			else
			{
				setprop("fdm/jsbsim/systems/leftpanel/pump-input", 0);
			}
		}
		settimer(flapsprocess, 0.1);
	}

# set startup configuration
init_flapsprocess = func 
{
}

init_flapsprocess();

# start flaps control process first time
flapsprocess ();

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
		brake_control_pos = getprop("fdm/jsbsim/systems/speedbrakescontrol/control-switch");
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
# Ignition button

# helper 
stop_ignitionbutton = func 
	{
	}

ignitionbutton = func 
	{
		starter_key=getprop("controls/engines/engine/starter-key");
		starter_command=getprop("controls/engines/engine/starter-command");
		if (
			(starter_key==nil)
			or
			(starter_command==nil)
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
			setprop("fdm/jsbsim/systems/ignitionbutton/button-input", 1);
		}
		else
		{
			setprop("fdm/jsbsim/systems/ignitionbutton/button-input", 0);
		}
		settimer(ignitionbutton, 0.1);
	  }

# set startup configuration
init_ignitionbutton = func 
{
	setprop("controls/engines/engine/starter-command", 0);
	setprop("controls/engines/engine/starter-key", 0);
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
		var in_service = getprop("processes/engine/on");
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
		var starter=getprop("controls/engines/engine/starter");
		var starter_pressed=getprop("fdm/jsbsim/systems/ignitionbutton/button-switch");
		var running=getprop("engines/engine/running");
		var out_of_fuel=getprop("engines/engine/out-of-fuel");
		var engine_n2=getprop("engines/engine/n2");
		var engine_thrust=getprop("engines/engine/thrust_lb");
		var engine_temperature=getprop("engines/engine/egt-degf");
		#To compaility wth FG previous versions
		if (engine_temperature==nil)
		{
			engine_temperature=getprop("engines/engine/egt_degf");
		}
		var pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		var bus=getprop("systems/electrical-real/bus");
		var gen_on=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");
		var pump=getprop("systems/electrical-real/outputs/pump/volts-norm");
		var third_tank_pump=getprop("systems/electrical-real/outputs/third-tank-pump/volts-norm");
		var fuel_control_pos=getprop("fdm/jsbsim/systems/fuelcontrol/control-input");
		var tank=[0,0,0,0,0];
		var tank_selected=[0,0,0,0,0];
		tank[0]=getprop("consumables/fuel/tank[0]/level-gal_us");
		tank[1]=getprop("consumables/fuel/tank[1]/level-gal_us");
		tank[2]=getprop("consumables/fuel/tank[2]/level-gal_us");
		tank[3]=getprop("consumables/fuel/tank[3]/level-gal_us");
		tank[4]=getprop("consumables/fuel/tank[4]/level-gal_us");
		var ignition_power=getprop("systems/electrical-real/outputs/ignition/on");
		#Timers
		var simulation_time=getprop("fdm/jsbsim/sim-time-sec");
		var starter_begin_time=getprop("engines/engine/starter-begin-time");
		var low_throttle_prev_time=getprop("engines/engine/low-throttle-prev-time");
		var low_throttle_time=getprop("engines/engine/low-throttle-time");
		var high_temperature_prev_time=getprop("engines/engine/high-temperature-prev-time");
		var high_temperature_time=getprop("engines/engine/high-temperature-time");
		var ignition_power_begin_time=getprop("engines/engine/ignition-power-begin-time");
		if (
			(starter==nil)
			or (starter_pressed==nil)
			or (running==nil)
			or (out_of_fuel==nil)
			or (engine_n2==nil)
			or (engine_thrust==nil)
			or (engine_temperature==nil)
			or (pilot_g==nil)
			or (bus==nil)
			or (gen_on==nil)
			or (pump==nil)
			or (third_tank_pump==nil)
			or (fuel_control_pos==nil)
			or (tank[0]==nil)
			or (tank[1]==nil)
			or (tank[2]==nil)
			or (tank[3]==nil)
			or (tank[4]==nil)
			or (ignition_power==nil)
			or (simulation_time==nil)
			or (starter_begin_time==nil)
			or (low_throttle_prev_time==nil)
			or (low_throttle_time==nil)
			or (high_temperature_prev_time==nil)
			or (high_temperature_time==nil)
			or (ignition_power_begin_time==nil)
		)
		{
			stop_engineprocess();
			setprop("engines/engine/error", 1);
	 		return ( settimer(engineprocess, 0.1) ); 
		}
		setprop("engines/engine/error", 0);
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
		if (tank[0]<1)
		{
			var active_tanks=0;
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
		var engine_temperature_degc=((engine_temperature-32)*5/9)/740*850;
		setprop("engines/engine/egt-degc", engine_temperature_degc);
		#get speed, ignition type, engine emergency brake, control switch and isolation valve values
		var speed=getprop("velocities/airspeed-kt");
		var ignition_type=getprop("fdm/jsbsim/systems/leftpanel/ignition-type-switch");
		var brake_pos=getprop("fdm/jsbsim/systems/stopcontrol/lever-pos");
		var brake_switch=getprop("fdm/jsbsim/systems/stopcontrol/lever-switch");
		var switch_pos=getprop("fdm/jsbsim/systems/gascontrol/lever-pos");
		var valve_pos=getprop("engines/engine/isolation-valve");
		var rpm=getprop("engines/engine/rpm");
		if (
			(speed==nil) 
			or (ignition_type==nil)
			or (brake_pos==nil)
			or (brake_switch==nil)
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
				and (abs(switch_pos-0.0)<0.001)
				and (brake_switch==0)
				and (valve_pos==0)
				and (gen_on==0)
				and (bus>0)
			)
			{
				if (
					(starter_begin_time==0)
					or
					((simulation_time-starter_begin_time)<10)
				)
				{
					#one type of ingnition on earth and another in flight
					if ((speed<108) and (ignition_type==0) and (ignition_power==1))
					{
						setprop("controls/engines/engine/cutoff", 1);
						setprop("engines/engine/cutoff-reason", "on Earth time<10 starter");
						setprop("controls/engines/engine/starter", 1);
						setprop("engines/engine/spoolup", 1);
						setprop("engines/engine/combustion", 0);
						if (starter_begin_time==0)
						{
							starter_begin_time=simulation_time;
							setprop("engines/engine/starter-begin-time", simulation_time);
						}
						var starter_time=simulation_time-starter_begin_time;
						rpm=(starter_time/10)*1000;
						setprop("engines/engine/rpm", rpm);
						setprop("fdm/jsbsim/propulsion/engine/rpm", rpm);
						setprop("fdm/jsbsim/systems/tachometer/input-rpm", rpm);
					}
					else
					{
						setprop("controls/engines/engine/cutoff", 1);
						setprop("engines/engine/cutoff-reason", "on Earth time<10 no start");
						setprop("controls/engines/engine/starter", 0);
						setprop("controls/engines/engine/starter-command", 0);
						setprop("controls/engines/engine/starter-indicate", 0);
						setprop("engines/engine/starter-begin-time", 0);
						setprop("engines/engine/starter-time", 0);
					}
				}
				else
				{
					if ((simulation_time-starter_begin_time)<30)
					{
						if ((out_of_fuel==1) or (ignition_power==0))
						{
							setprop("controls/engines/engine/cutoff", 1);
							setprop("engines/engine/cutoff-reason", "on Earth, time<30 out_of_fuel=1 or ignition_power=0");
							setprop("controls/engines/engine/starter", 0);
							setprop("controls/engines/engine/starter-command", 0);
							setprop("controls/engines/engine/starter-indicate", 0);
							setprop("engines/engine/starter-begin-time", 0);
							setprop("engines/engine/starter-time", 0);
						}
						else
						{
							setprop("controls/engines/engine/cutoff", 0);
							setprop("controls/engines/engine/starter", 1);
							setprop("engines/engine/spoolup", 0);
							var starter_time=simulation_time-starter_begin_time;
							setprop("engines/engine/starter-time", starter_time);
							setprop("engines/engine/combustion", 1);
							rpm=1000;
							setprop("engines/engine/rpm", rpm);
							setprop("fdm/jsbsim/propulsion/engine/rpm", rpm);
							setprop("fdm/jsbsim/systems/tachometer/input-rpm", rpm);
						}
					}
					else
					{
						starter_begin_time=0;
						setprop("engines/engine/starter-begin-time", starter_begin_time);
						setprop("engines/engine/starter-time", 0);
						setprop("controls/engines/engine/starter-command", 0);
					}
				}
			}
			else
			{
				setprop("engines/engine/starter-begin-time", 0);
				setprop("engines/engine/starter-time", 0);
				setprop("controls/engines/engine/starter-command", 0);
			}	
		}
		#In flight ignition
		if (
			(running==0)
			and (brake_switch==0)
			and (valve_pos==0)
			and (ignition_type==1)
			and (out_of_fuel==0)
			and (ignition_power==1)
			and (speed>100)
			and (speed<300)
			and (gen_on==0)
			and (bus>0)
		)
		{	
			if (abs(switch_pos*500-speed)<20)
			{
				if (
					(starter_begin_time==0)
					or
					((simulation_time-starter_begin_time)<10)
				)
				{
					#one type of ingnition on earth and another in flight
					setprop("controls/engines/engine/cutoff", 1);
					setprop("engines/engine/cutoff-reason", "in flight starter_time<10");
					setprop("controls/engines/engine/starter", 1);
					setprop("engines/engine/combustion", 1);
					if (starter_begin_time==0)
					{
						starter_begin_time=simulation_time;
						setprop("engines/engine/starter-begin-time", simulation_time);
					}
					var starter_time=simulation_time-starter_begin_time;
					setprop("engines/engine/starter-time", starter_time);
					rpm=(1+starter_time/20)*1000;
					setprop("engines/engine/rpm", rpm);
					setprop("fdm/jsbsim/propulsion/engine/rpm", rpm);
					setprop("fdm/jsbsim/systems/tachometer/input-rpm", rpm);
				}
				else
				{
					if ((simulation_time-starter_begin_time)<30)
					{
						setprop("controls/engines/engine/cutoff", 0);
						setprop("controls/engines/engine/starter", 1);
						var starter_time=simulation_time-starter_begin_time;
						setprop("engines/engine/starter-time", starter_time);
						setprop("engines/engine/combustion", 1);
						rpm=(1+starter_time/20)*1000;
						setprop("engines/engine/rpm", rpm);
						setprop("fdm/jsbsim/propulsion/engine/rpm", rpm);
						setprop("fdm/jsbsim/systems/tachometer/input-rpm", rpm);
					}
					else
					{
						starter_begin_time=0;
						setprop("controls/engines/engine/starter", starter_begin_time);
						setprop("engines/engine/starter-begin-time", 0);
						setprop("engines/engine/starter-time", 0);
						setprop("controls/engines/engine/starter-command", 0);
					}
				}
			}
			else
			{
				setprop("controls/engines/engine/cutoff", 1);
				setprop("engines/engine/cutoff-reason", "in flight throttle shift");
				setprop("controls/engines/engine/starter", 0);
				setprop("engines/engine/starter-begin-time", 0);
				setprop("engines/engine/starter-time", 0);
				setprop("controls/engines/engine/starter-command", 0);
			}
		}
		if (
			(running==1)
			or (brake_switch==1)
			or (valve_pos==1)
			or (out_of_fuel==1)
			or (ignition_power==0)
			or (bus==0)
			or (starter_begin_time==0) 
		)
		{
			setprop("engines/engine/spoolup", 0);
			setprop("engines/engine/combustion", 0);
			setprop("engines/engine/starter-begin-time", 0);
			setprop("engines/engine/starter-time", 0);
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
			if (brake_switch==1)
			{
				running=engine_stop("braked");
			}
		}
		if (running==1) 
		{		
			if (abs(switch_pos-0.0)<0.001)
			{
				#On fast fight low throttle fix must be switched on, otherwise engine shutdown
				if (low_throttle_prev_time==0)
				{
					low_throttle_prev_time=simulation_time;
				}
				setprop("engines/engine/low-throttle-prev-time", simulation_time);
				var low_throttle_time=low_throttle_time+(1+speed/100)*(simulation_time-low_throttle_prev_time);
				setprop("engines/engine/low-throttle-time", low_throttle_time);
				if (low_throttle_time>60)
				{
					running=engine_stop("low throttle");
				}
			}
			else
			{
				setprop("engines/engine/low-throttle-time", 0);
				setprop("engines/engine/low-throttle-prev-time", 0);
			}
			if (engine_temperature_degc>825)
			{
				#Engine switch off if it goes on high temperature too long
				if (high_temperature_prev_time==0)
				{
					high_temperature_prev_time=simulation_time;
				}
				setprop("engines/engine/high-temperature-prev-time", simulation_time);
				var high_temperature_time=high_temperature_time+(simulation_time-high_temperature_prev_time)*(engine_temperature_degc-825)/25;
				setprop("engines/engine/high-temperature-time", high_temperature_time);
				if (high_temperature_time>30)
				{
					running=engine_stop("high temperature "~engine_temperature_degc);
				}
			}
			else
			{
				setprop("engines/engine/high-temperature-time", 0);
				setprop("engines/engine/high-temperature-prev-time", 0);
			}
			if (ignition_power==1)
			{
				if (ignition_power_begin_time==0)
				{
					ignition_power_begin_time=simulation_time;
					setprop("engines/engine/ignition_power_begin_time", simulation_time);
				}
			}
			else
			{
				ignition_power_begin_time=0;
				setprop("engines/engine/ignition-power-begin-time", 0);
			}
			if (
				(ignition_power_begin_time!=0)
				and 
				((simulation_time-ignition_power_begin_time)>60)
			)
			{
				setprop("engines/engine/ignition-power-begin-time", 0);
				setprop("fdm/jsbsim/systems/rightpanel/battery-input", 0);
				setprop("fdm/jsbsim/systems/rightpanel/generator-input", 0);
			}
			var set_throttle=0;
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
			var sound=((engine_n2-70)/30)*1.1;
			setprop("engines/engine/sound", sound);
			rpm=((engine_n2-70)/35)*15000;
			setprop("engines/engine/rpm", rpm);
			setprop("fdm/jsbsim/propulsion/engine/rpm", rpm);
			setprop("fdm/jsbsim/systems/tachometer/input-rpm", rpm);
		}
		else
		{
			setprop("fdm/jsbsim/fcs/throttle-cmd-norm-real", 0.3);
			setprop("engines/engine/sound", 0);
			if (starter_begin_time==0)
			{
	 			rpm=rpm+(speed*2-rpm)/10;
				setprop("engines/engine/rpm", rpm);
				setprop("fdm/jsbsim/propulsion/engine/rpm", rpm);
				setprop("fdm/jsbsim/systems/tachometer/input-rpm", rpm);
			}
		}
		settimer(engineprocess, 0.0); 
	}


init_engineprocess = func 
{
	setprop("processes/engine/on", 1);
	setprop("engines/engine/stop", 0);
	setprop("engines/engine/starter-begin-time", 0);
	setprop("engines/engine/starter-time", 0);
	setprop("engines/engine/low-throttle-prev-time", 0);
	setprop("engines/engine/low-throttle-time", 0);
	setprop("engines/engine/high-temperature-prev-time", 0);
	setprop("engines/engine/high-temperature-time", 0);
	setprop("engines/engine/ignition-power-begin-time", 0);
	setprop("engines/engine/egt-degc", 0);
	setprop("engines/engine/sound", 0);
	setprop("engines/engine/rpm", 0);
	setprop("fdm/jsbsim/propulsion/engine/rpm", 0);
	setprop("fdm/jsbsim/systems/tachometer/input-rpm", 0);
	setprop("engines/engine/spoolup", 0);
	setprop("engines/engine/combustion", 0);
}

init_engineprocess();

engine_stop = func(stop_reason)
	{
		setprop("engines/engine/stop-reason", stop_reason);
		setprop("engines/engine/starter-begin-time", 0);
		setprop("engines/engine/starter-time", 0);
		setprop("engines/engine/low-throttle-prev-time", 0);
		setprop("engines/engine/low-throttle-time", 0);
		setprop("engines/engine/high-temperature-prev-time", 0);
		setprop("engines/engine/high-temperature-time", 0);
		setprop("engines/engine/ignition-power-begin-time", 0);
		setprop("controls/engines/engine/cutoff", 1);
		setprop("engines/engine/cutoff-reason", "engine stop");
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

#------------------------------------------------------------
#So, electrical system seems works strange in Flight Gear too
#There's pretty simple "on/off" electrical system for aircraft

stop_realelectric=func
	{
	}

realelectric=func
	{
		# check power
		var in_service = getprop("systems/electrical-real/serviceable");
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
		var set_battery=getprop("fdm/jsbsim/systems/rightpanel/battery-switch");
		var set_generator=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");

		var starter_pressed=getprop("fdm/jsbsim/systems/ignitionbutton/button-switch");

		var ignition_type=getprop("fdm/jsbsim/systems/leftpanel/ignition-type-switch");
		var set_engine_control=getprop("fdm/jsbsim/systems/leftpanel/engine-control-switch");
		var set_pump=getprop("fdm/jsbsim/systems/leftpanel/pump-switch");
		var set_third_tank_pump=getprop("fdm/jsbsim/systems/leftpanel/third-tank-pump-switch");
		var set_ignition=getprop("fdm/jsbsim/systems/leftpanel/ignition-switch");
		var set_isolation=getprop("fdm/jsbsim/systems/leftpanel/isolation-valve-switch");

		var set_headlight=getprop("fdm/jsbsim/systems/rightpanel/headlight-switch");
		var set_trimmer=getprop("fdm/jsbsim/systems/rightpanel/trimmer-switch");
		var set_horizon=getprop("fdm/jsbsim/systems/rightpanel/horizon-switch");
		var set_radio=getprop("fdm/jsbsim/systems/rightpanel/radio-switch");
		var set_radioaltimeter=getprop("fdm/jsbsim/systems/rightpanel/radioaltimeter-switch");
		var set_radiocompass=getprop("fdm/jsbsim/systems/rightpanel/radiocompass-switch");
		var set_drop_tank=getprop("fdm/jsbsim/systems/rightpanel/drop-tank-switch");
		var set_bomb=getprop("fdm/jsbsim/systems/rightpanel/bomb-switch");
		var set_photo=getprop("fdm/jsbsim/systems/rightpanel/photo-switch");
		var set_photo_machinegun=getprop("fdm/jsbsim/systems/rightpanel/photo-machinegun-switch");
		var set_headsight=getprop("fdm/jsbsim/systems/rightpanel/headsight-switch");
		var set_machinegun=getprop("fdm/jsbsim/systems/rightpanel/machinegun-switch");

		var battery_time=getprop("systems/electrical-real/battery-time");
		var battery_load_time=getprop("systems/electrical-real/battery-load-time");
		var battery_max_load_time=getprop("systems/electrical-real/battery-maximum-load-time");

		var engine_running=getprop("engines/engine/running");

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
			setprop("fdm/jsbsim/systems/rightpanel/battery-input", 0);
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
			#JSBsim handmaded instruments
			setprop("fdm/jsbsim/systems/airspeedometer/on", 1);
			setprop("fdm/jsbsim/systems/vertspeedometer/on", 1);
			setprop("fdm/jsbsim/systems/arthorizon/on", set_horizon);
			setprop("fdm/jsbsim/systems/headsight/on", set_headsight);
			setprop("fdm/jsbsim/systems/tachometer/on", 1);
			setprop("fdm/jsbsim/systems/radioaltimeter/on", set_radioaltimeter);
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
			#JSBsim handmaded instruments
			setprop("fdm/jsbsim/systems/airspeedometer/on", 0);
			setprop("fdm/jsbsim/systems/vertspeedometer/on", 0);
			setprop("fdm/jsbsim/systems/arthorizon/on", 0);
			setprop("fdm/jsbsim/systems/headsight/on", 0);
			setprop("fdm/jsbsim/systems/tachometer/on", 0);
			setprop("fdm/jsbsim/systems/radioaltimeter/on", 0);
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
	setprop("fdm/jsbsim/systems/headsight/on", 0);
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
		var in_service = getprop("instrumentation/motormeter/serviceable");
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
		var fuel_flow=getprop("engines/engine/fuel-flow_pph");
		var oil_pressure=getprop("engines/engine/oil-pressure-psi");
		var engine_temperature=getprop("engines/engine/egt-degc");
		#get engine control value
		var engine_control=getprop("systems/electrical-real/outputs/engine_control/on");
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
#Headsight keyboard functions

less_sight_distance = func 
	{
		set_pos=getprop("fdm/jsbsim/systems/headsight/target-distance");
		if (!(set_pos==nil))
		{
			if (set_pos>180)
			{
				set_pos=set_pos-10;
				setprop("fdm/jsbsim/systems/headsight/target-distance", set_pos);
			}
		}
	}

more_sight_distance = func 
	{
		set_pos=getprop("fdm/jsbsim/systems/headsight/target-distance");
		if (!(set_pos==nil))
		{
			if (set_pos<800)
			{
				set_pos=set_pos+10;
				setprop("fdm/jsbsim/systems/headsight/target-distance", set_pos);
			}
		}
	}

#-----------------------------------------------------------------------
#Headsight view returner
stop_headsight_view_returner=func
	{
	}

headsight_view_returner=func
	{
		# check power
		in_service = getprop("fdm/jsbsim/systems/headsight/serviceable");
		if (in_service == nil)
		{
			stop_headsight_view_returner();
	 		return ( settimer(headsight_view_returner, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_headsight_view_returner();
		 	return ( settimer(headsight_view_returner, 0.1) ); 
		}
		#Get values
		view_offset_x=getprop("sim/view[1]/config/x-offset-m");
		view_offset_y=getprop("sim/view[1]/config/y-offset-m");
		view_offset_z=getprop("sim/view[1]/config/z-offset-m");
		view_heading_offset_deg=getprop("sim/view[1]/config/heading-offset-deg");
		view_pitch_offset_deg=getprop("sim/view[1]/config/pitch-offset-deg");
		view_roll_offset_deg=getprop("sim/view[1]/config/roll-offset-deg");
		view_field_offset=getprop("sim/view[1]/config/default-field-of-view-deg");
		current_view_number=getprop("sim/current-view/view-number");
		photo_machinegun=getprop("systems/electrical-real/outputs/photo-machinegun/volts-norm");
		distance_from_eye_to_sight=getprop("fdm/jsbsim/systems/headsight/from-eye-to-sight");
		on=getprop("fdm/jsbsim/systems/headsight/on");
		if (
			(view_offset_x==nil)
			or (view_offset_y==nil)
			or (view_offset_z==nil)
			or (view_heading_offset_deg==nil)
			or (view_pitch_offset_deg==nil)
			or (view_roll_offset_deg==nil)
			or (view_field_offset==nil)
			or (current_view_number==nil)
			or (photo_machinegun==nil)
			or (distance_from_eye_to_sight==nil)
			or (on==nil)
		)
		{
			stop_headsight();
	 		return ( settimer(headsight, 0.1) ); 
		}
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
		if (on==0)
		{
			stop_headsight_view_returner();
	 		return ( settimer(headsight_view_returner, 0.1) ); 
		}
		if ((current_view_number==1) and (photo_machinegun==1))
		{
			setprop("fdm/jsbsim/systems/headsight/sign", 1);
		}
		else
		{
			setprop("fdm/jsbsim/systems/headsight/sign", 0);
		}
		settimer(headsight_view_returner, 0.1);
	}

init_headsight_view_returner=func
{
}

init_headsight_view_returner();

headsight_view_returner();

#-----------------------------------------------------------------------
#Stick buttons

press_fire=func
	{
		setprop("controls/armament/trigger", 1);
	}

unpress_fire=func
	{
		setprop("controls/armament/trigger", 0);
	}

press_bomb=func
	{
		setprop("fdm/jsbsim/systems/stick/drop-button-input", 1);
	}

unpress_bomb=func
	{
		setprop("fdm/jsbsim/systems/stick/drop-button-input", 0);
	}


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
		button_pos=getprop("/fdm/jsbsim/systems/stick/fire-button-switch");
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
		bullet_collision=getprop("sim/ai/aircraft/collision/N-37");
		if (bullet_collision!=nil)
		{
			if (bullet_collision!="")
			{
				setprop("sim/ai/aircraft/collision/N-37", "");
				bulletricochetsound();
			}
		}
		bullet_impact=getprop("sim/ai/aircraft/impact/N-37");
		if (bullet_impact!=nil)
		{
			if (bullet_impact!="")
			{
				setprop("sim/ai/aircraft/impact/N-37", "");
				bulletricochetsound();
			}
		}
		if (power==0) 
		{
			if ((button_pos==0) and (on==1))
			{
				setprop("instrumentation/cannon/on", 0);
				cfire_cannon();
			}
		}
		else
		{
			if ((button_pos==1) and (on==0))
			{
				setprop("instrumentation/cannon/on", 1);
				fire_cannon();
			}
			if ((button_pos==0) and (on==1))
			{
				setprop("instrumentation/cannon/on", 0);
				cfire_cannon();
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
	setprop("sounds/bullet-ricochet/on", 0);
}

init_cannon();

bulletricochetsound = func
	{
		setprop("a/a", 1);
		sound_on=getprop("sounds/bullet-ricochet/on");
		if (sound_on!=nil)
		{
			if (sound_on!=1)
			{
				setprop("sounds/bullet-ricochet/on", 1);
				settimer(bulletricochetsoundoff, 1.0);
			}
		}
	}

bulletricochetsoundoff = func
	{
		setprop("sounds/bullet-ricochet/on", 0);
	}

cannon();

#-----------------------------------------------------------------------
#Wind process

stop_windprocess=func
	{
	}

windprocess=func
	{
		flaps=getprop("fdm/jsbsim/fcs/flap-pos-norm");
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
		speed_brake=getprop("surface-positions/speedbrake-pos-norm");
		speed=getprop("velocities/airspeed-kt");
		canopy_pos=getprop("fdm/jsbsim/systems/canopy/pos");
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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
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

init_flapsvalve=func
{
	setprop("fdm/jsbsim/systems/flapsvalve/safer-input", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/safer-command", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/safer-pos", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/valve-input", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/valve-command", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/valve-pos", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/pressure-pos", 1);
}

init_flapsvalve();

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
#Tear canopy process, would be shifted on JSB in time
# helper 
stop_canopyprocess = func 
	{
	}

canopyprocess = func 
	{
		var in_service = getprop("fdm/jsbsim/systems/canopy/serviceable" );
		if (in_service == nil)
		{
			stop_canopyprocess();
	 		return ( settimer(canopyprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_canopy();
			return ( settimer(canopyprocess, 0.1) ); 
		}
		var pos=getprop("fdm/jsbsim/systems/canopy/pos");
		var tored=getprop("fdm/jsbsim/systems/canopy/tored");
		var mach=getprop("fdm/jsbsim/velocities/mach");
		if (
			(tored==nil)
			or (mach==nil)
		)
		{
			stop_canopyprocess();
			return ( settimer(canopyprocess, 0.1) ); 
		}
		if (
			(pos>0.01)
			and (tored==0)
			and (mach>0.3)
		)
		{
			tored=1;
			tear_canopy();
			stop_canopyprocess();
			return ( settimer(canopyprocess, 0.1) ); 
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
		settimer(canopyprocess, 0.1);
	}

# set startup configuration
init_canopyprocess=func
{
}

tear_canopy=func
{
	setprop("ai/submodels/canopy-drop", 1);
	setprop("fdm/jsbsim/systems/canopy/tored", 1);
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

init_canopyprocess();

#start
canopyprocess();

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
		headsight_ready=getprop("fdm/jsbsim/systems/headsight/sign");
		button_pos=getprop("fdm/jsbsim/systems/stick/fire-button-switch");
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
		bomb_button_pos=getprop("fdm/jsbsim/systems/stick/drop-button-switch");
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
		left_drop_tank_impact=getprop("sim/ai/aircraft/impact/left-drop-tank-impact");
		if (left_drop_tank_impact!=nil)
		{
			if (left_drop_tank_impact!="")
			{
				setprop("sim/ai/aircraft/impact/left-drop-tank-impact", "");
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
		settimer(droptank, 0.0);
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

crash_tank_drop = func
	{
		setprop("consumables/fuel/tank[3]/level-gal_us", 0);
		setprop("consumables/fuel/tank[3]/selected", 0);
		setprop("consumables/fuel/tank[4]/level-gal_us", 0);
		setprop("consumables/fuel/tank[4]/selected", 0);
		setprop("instrumentation/drop-tank/dropped", 1);
	}

#start
droptank();

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
		setprop("instrumentation/gastermometer/serviceable", 0);
		setprop("instrumentation/motormeter/serviceable", 0);
		setprop("instrumentation/machometer/serviceable", 0);
		setprop("instrumentation/turnometer/serviceable", 0);
		setprop("instrumentation/vertspeedometer/serviceable", 0);
		setprop("instrumentation/gear-pressure-indicator/serviceable", 0);
		setprop("instrumentation/flaps-pressure-indicator/serviceable", 0);
		setprop("instrumentation/marker-beacon/serviceable", 0);

		#JSB instruments and controls
		setprop("fdm/jsbsim/systems/airspeedometer/serviceable", 0);
		setprop("fdm/jsbsim/systems/vertspeedometer/serviceable", 0);
		setprop("fdm/jsbsim/systems/arthorizon/serviceable", 0);
		setprop("fdm/jsbsim/systems/tachometer/serviceable", 0);
		setprop("fdm/jsbsim/systems/headsignt/serviceable", 0);
		setprop("fdm/jsbsim/systems/gascontrol/serviceable", 0);
		setprop("fdm/jsbsim/systems/flapscontrol/serviceable", 0);
		setprop("fdm/jsbsim/systems/rightpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/stopcontrol/serviceable", 0);
		setprop("fdm/jsbsim/systems/leftpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 0);
		setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 0);
		setprop("fdm/jsbsim/systems/radioaltimeter/serviceable", 0);
		setprop("fdm/jsbsim/systems/stick/serviceable", 0);
		setprop("fdm/jsbsim/systems/pedals/serviceable", 0);
		setprop("fdm/jsbsim/systems/gearvalve/serviceable", 0);
		setprop("fdm/jsbsim/systems/flapsvalve/serviceable", 0);

		#Lock controls
		setprop("instrumentation/gear-control/serviceable", 0);
		setprop("instrumentation/flaps-control/serviceable", 0);
		setprop("instrumentation/speed-brake-control/serviceable", 0);
		setprop("instrumentation/ignition-button/serviceable", 0);
		setprop("instrumentation/buster-control/serviceable", 0);
		setprop("instrumentation/cannon/serviceable", 0);
		setprop("instrumentation/trimmer/serviceable", 0);
		setprop("instrumentation/radiocompass/serviceable", 0);
		setprop("instrumentation/photo/serviceable", 0);
		setprop("instrumentation/drop-tank/serviceable", 0);
		setprop("instrumentation/pedals/serviceable", 0);
		#Switch off power
		setprop("fdm/jsbsim/systems/rightpanel/battery-input", 0);
		setprop("fdm/jsbsim/systems/rightpanel/generator-input", 0);
		#Switch off engine
		setprop("controls/engines/engine/cutoff", 1);
		setprop("engines/engine/cutoff-reason", "aircraft break");
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

		gear_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(0, "crash");
			}
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(1, "crash");
			}
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
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

		crash_tank_drop();

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
		if (pilot_g>(maximum_g*0.5))
		{
			if (pilot_g>maximum_g)
			{
				setprop("sounds/aircraft-crack/volume", 1);
				setprop("sounds/aircraft-creaking/volume", 1);
				setprop("fdm/jsbsim/gtremble/max", 1);
			}
			else
			{
				tremble_max=math.sqrt((pilot_g-(maximum_g*0.5))/(maximum_g*0.5));
				setprop("sounds/aircraft-crack/volume", tremble_max);
				setprop("fdm/jsbsim/gtremble/max", 1);
				if (pilot_g>(maximum_g*0.75))
				{
					tremble_max=math.sqrt((pilot_g-(maximum_g*0.5))/(maximum_g*0.5));
					setprop("sounds/aircraft-creaking/volume", tremble_max);
					setprop("sounds/aircraft-creaking/on", 1);
				}
				else
				{
					setprop("sounds/aircraft-creaking/on", 0);
				}
			}
			if (pilot_g>(maximum_g*0.75))
			{
				setprop("fdm/jsbsim/accelerations/crack", 1);
			}
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
		setprop("fdm/jsbsim/systems/rightpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/leftpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 0);
		setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 0);
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
		setprop("instrumentation/gastermometer/serviceable", 1);
		setprop("instrumentation/motormeter/serviceable", 1);
		setprop("instrumentation/machometer/serviceable", 1);
		setprop("instrumentation/turnometer/serviceable", 1);
		setprop("instrumentation/vertspeedometer/serviceable", 1);
		setprop("instrumentation/gear-pressure-indicator/serviceable", 1);
		setprop("instrumentation/flaps-pressure-indicator/serviceable", 1);
		setprop("instrumentation/marker-beacon/serviceable", 1);

		#JSB instruments
		setprop("fdm/jsbsim/systems/airspeedometer/serviceable", 1);
		setprop("fdm/jsbsim/systems/vertspeedometer/serviceable", 1);
		setprop("fdm/jsbsim/systems/arthorizon/serviceable", 1);
		setprop("fdm/jsbsim/systems/tachometer/serviceable", 1);
		setprop("fdm/jsbsim/systems/headsignt/serviceable", 1);
		setprop("fdm/jsbsim/systems/gascontrol/serviceable", 1);
		setprop("fdm/jsbsim/systems/flapscontrol/serviceable", 1);
		setprop("fdm/jsbsim/systems/rightpanel/serviceable", 1);
		setprop("fdm/jsbsim/systems/stopcontrol/serviceable", 1);
		setprop("fdm/jsbsim/systems/leftpanel/serviceable", 1);
		setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 1);
		setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 1);
		setprop("fdm/jsbsim/systems/radioaltimeter/serviceable", 1);

		#Repair controls
		setprop("instrumentation/gear-control/serviceable", 1);
		setprop("instrumentation/flaps-control/serviceable", 1);
		setprop("instrumentation/speed-brake-control/serviceable", 1);

		setprop("instrumentation/ignition-button/serviceable", 1);
		setprop("instrumentation/buster-control/serviceable", 1);
		setprop("instrumentation/cannon/serviceable", 1);
		setprop("instrumentation/trimmer/serviceable", 1);
		setprop("instrumentation/radiocompass/serviceable", 1);
		setprop("instrumentation/photo/serviceable", 1);
		setprop("instrumentation/drop-tank/serviceable", 1);
		setprop("instrumentation/pedals/serviceable", 1);
		setprop("instrumentation/panels/left/serviceable", 1);
		setprop("fdm/jsbsim/systems/rightpanel/serviceable", 1);
		setprop("fdm/jsbsim/systems/leftpanel/serviceable", 1);
		setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 1);
		setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 1);
		setprop("fdm/jsbsim/systems/stick/serviceable", 1);
		setprop("fdm/jsbsim/systems/pedals/serviceable", 1);
		setprop("fdm/jsbsim/systems/gearvalve/serviceable", 1);
		setprop("fdm/jsbsim/systems/flapsvalve/serviceable", 1);
	}

aircraft_repair=func
	{
		#Repair gears
		setprop("fdm/jsbsim/gear/unit[0]/tored", 0);
		setprop("fdm/jsbsim/gear/unit[1]/tored", 0);
		setprop("fdm/jsbsim/gear/unit[2]/tored", 0);

		setprop("fdm/jsbsim/gear/unit[0]/break-type", "");
		setprop("fdm/jsbsim/gear/unit[1]/break-type", "");
		setprop("fdm/jsbsim/gear/unit[2]/break-type", "");

		setprop("fdm/jsbsim/gear/unit[0]/stuck", 0);
		setprop("fdm/jsbsim/gear/unit[1]/stuck", 0);
		setprop("fdm/jsbsim/gear/unit[2]/stuck", 0);

		#Repair gears
		init_gearvalve();

		#Repair flaps
		setprop("fdm/jsbsim/fcs/flap-tored", 0);
		init_flapsvalve();

		#Repair canopy
		setprop("fdm/jsbsim/systems/canopy/tored", 0);

		#Unlock aircraft
		aircraft_unlock();

		#Set repaired
		setprop("fdm/jsbsim/simulation/crashed", 0);
		setprop("fdm/jsbsim/simulation/exploded", 0);
	}

aircraft_init=func
	{
		#Init indication instrumentation
		init_chron();
		init_manometer();
		init_magnetic_compass();
		init_gearindicator();
		init_flapslamp();
		init_fuelometer();
		init_altlamp();
		init_gearlamp();
		init_oxypressmeter();
		init_gyrocompass();
		init_brakepressmeter();
		init_ignitionlamp();
		init_gastermometer();
		init_motormeter();
		init_machometer();
		init_turnometer();
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
		init_speedbrakecontrol();
		init_ignitionbutton();
		init_bustercontrol();

		init_gearvalve();
		init_flapsvalve();
		init_trimmer();
		init_canopyprocess();
	}

aircraft_start_refuel=func
	{
		setprop("processes/engine/on", 0);
		wow_one=getprop("gear/gear/wow");
		wow_two=getprop("gear/gear[1]/wow");
		wow_three=getprop("gear/gear[2]/wow");
		setprop("consumables/fuel/tank[0]/level-gal_us", 1.5);
		setprop("consumables/fuel/tank[1]/level-gal_us", 300);
		setprop("consumables/fuel/tank[2]/level-gal_us", 40);
		setprop("consumables/fuel/tank[3]/level-gal_us", 60);
		setprop("consumables/fuel/tank[4]/level-gal_us", 60);
		setprop("consumables/fuel/tank[5]/level-gal_us", 22.5);
		setprop("consumables/fuel/tank[5]/selected", 0);
	}

aircraft_end_refuel=func
	{
		setprop("processes/engine/on", 1);
		setprop("ai/submodels/submodel[1]/count", 40);
		setprop("ai/submodels/submodel[3]/count", 80);
		setprop("ai/submodels/submodel[4]/count", 80);
		setprop("fdm/jsbsim/shells/n37", 40);
		setprop("fdm/jsbsim/shells/n23-inner", 80);
		setprop("fdm/jsbsim/shells/n23-outer", 80);
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
		var in_service = getprop("processes/autostart/enabled" );
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
		var switch_pos=0;
		var pos=getprop("processes/autostart/pos");
		var elapsed_time=getprop("processes/autostart/elapsed-time");
		var wow_one=getprop("gear/gear/wow");
		var wow_two=getprop("gear/gear[1]/wow");
		var wow_three=getprop("gear/gear[2]/wow");
		var exploded=getprop("fdm/jsbsim/simulation/exploded");
		var crashed=getprop("fdm/jsbsim/simulation/crashed");
		var starter_command=getprop("controls/engines/engine/starter-command");
		var engine_running=getprop("engines/engine/running");
		var throttle_pos=getprop("fdm/jsbsim/systems/gascontrol/lever-pos");
		var throttle_lock_pos=getprop("fdm/jsbsim/systems/gascontrol/lock-pos");
		var throttle_fix_pos=getprop("fdm/jsbsim/systems/gascontrol/fix-pos");
		var throttle_set_pos=getprop("controls/engines/engine/throttle");
		var main_tank_lbs=getprop("consumables/fuel/tank[1]/level-lbs");
		var canopy_pos=getprop("fdm/jsbsim/systems/canopy/pos");
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
			or (throttle_lock_pos==nil)
			or (throttle_fix_pos==nil)
			or (throttle_set_pos==nil)
			or (main_tank_lbs==nil)
			or (canopy_pos==nil)
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
			or (main_tank_lbs<10)
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

		if (pos==0)
		{
			setprop("fdm/jsbsim/systems/stopcontrol/lever-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/stopcontrol/lever-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==1) 
		{
			if (engine_running==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==2)
		{
			setprop("fdm/jsbsim/systems/rightpanel/battery-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/battery-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==3)
		{
			setprop("fdm/jsbsim/systems/rightpanel/generator-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==4)
		{
			setprop("fdm/jsbsim/systems/leftpanel/pump-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/pump-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==5)
		{
			setprop("fdm/jsbsim/systems/leftpanel/isolation-valve-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/isolation-valve-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==6)
		{
			setprop("fdm/jsbsim/systems/leftpanel/ignition-type-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/ignition-type-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==7)
		{
			setprop("fdm/jsbsim/systems/leftpanel/ignition-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/ignition-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==8)
		{
			setprop("fdm/jsbsim/systems/leftpanel/engine-control-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/engine-control-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==9)
		{
			setprop("fdm/jsbsim/systems/leftpanel/third-tank-pump-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/third-tank-pump-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==10)
		{
			setprop("fdm/jsbsim/systems/stopcontrol/lever-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/stopcontrol/lever-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==11)
		{
			setprop("fdm/jsbsim/systems/gascontrol/lock-command", 0);
			if (throttle_lock_pos < 0.1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==12)
		{
			if (abs(throttle_pos-0.11)>0.001)
			{
				setprop("controls/engines/engine/throttle", 0.11);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==13)
		{
			setprop("fdm/jsbsim/systems/gascontrol/fix-command", 0);
			if (throttle_fix_pos == 0.0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==14)
		{
			if (abs(throttle_pos-0.0)>0.001)
			{
				setprop("controls/engines/engine/throttle", 0);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==15)
		{
			setprop("fdm/jsbsim/systems/gascontrol/lock-command", 1);
			if (throttle_lock_pos > 0.9)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==16)
		{
			setprop("fdm/jsbsim/systems/rightpanel/battery-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/battery-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==17)
		{
			setprop("fdm/jsbsim/systems/leftpanel/pump-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/pump-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==18)
		{
			setprop("fdm/jsbsim/systems/leftpanel/ignition-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/ignition-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==19)
		{
			setprop("fdm/jsbsim/systems/leftpanel/engine-control-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/engine-control-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

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

		if (pos==22)
		{
			setprop("fdm/jsbsim/systems/rightpanel/generator-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==23)
		{
			setprop("fdm/jsbsim/systems/leftpanel/ignition-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/ignition-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==24)
		{
			setprop("fdm/jsbsim/systems/gascontrol/lock-command", 0);
			if (throttle_lock_pos < 0.1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==25)
		{
			if (abs(throttle_pos-0.2)>0.001)
			{
				setprop("controls/engines/engine/throttle", 0.2);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==26)
		{
			setprop("fdm/jsbsim/systems/gascontrol/fix-command", 1);
			if (throttle_fix_pos > 0.9)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==27)
		{
			if (abs(throttle_pos-0.04)>0.001)
			{
				setprop("controls/engines/engine/throttle", 0.04);
			}
			else
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==28)
		{
			setprop("fdm/jsbsim/systems/leftpanel/ignition-input", 0);
			switch_pos=getprop("fdm/jsbsim/systems/leftpanel/ignition-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==0)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==29)
		{
			setprop("fdm/jsbsim/systems/rightpanel/trimmer-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/trimmer-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==30)
		{
			setprop("fdm/jsbsim/systems/rightpanel/horizon-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/horizon-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==31)
		{
			setprop("fdm/jsbsim/systems/rightpanel/radioaltimeter-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/radioaltimeter-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==32)
		{
			setprop("fdm/jsbsim/systems/rightpanel/radiocompass-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/radiocompass-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==33)
		{
			setprop("fdm/jsbsim/systems/rightpanel/drop-tank-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/drop-tank-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==34)
		{
			setprop("fdm/jsbsim/systems/rightpanel/headsight-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/headsight-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==35)
		{
			setprop("fdm/jsbsim/systems/rightpanel/machinegun-input", 1);
			switch_pos=getprop("fdm/jsbsim/systems/rightpanel/machinegun-switch");
			if (switch_pos==nil)
			{
				stop_autostart_process();
				return ( settimer(autostart_process, 0.1) ); 
			}
			if (switch_pos==1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

		if (pos==36)
		{
			setprop("fdm/jsbsim/systems/canopy/command", 0);
			if (canopy_pos > 0.1)
			{
				pos=pos+1;
				setprop("processes/autostart/pos", pos);
			}
		}

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
	setprop("processes/autostart/elapsed-time", 0);
	setprop("processes/autostart/enabled", 1);
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
