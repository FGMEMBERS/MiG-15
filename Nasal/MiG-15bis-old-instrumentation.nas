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
		switchmove("instrumentation/artifical-horizon", "fdm/jsbsym/systems/arthorizon/button");
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
			interpolate("instrumentation/artifical-horizon/indicated-roll-deg-inter", ind_roll_deg, 0.1);
			interpolate("instrumentation/artifical-horizon/indicated-pitch-deg-inter", ind_pitch_deg, 0.1);

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

#init_arthorizon();

# start artifical horizon process first time
#arthorizon ();

#Unused since smoother JSBSim only version

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

#init_headsight();

#headsight();
#Switched off due move to better JSBSim only version

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

#init_gascontrol();

# start gas control process first time
#gascontrol ();

