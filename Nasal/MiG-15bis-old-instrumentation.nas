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

#init_rightpanel();

# start ignition lamp process first time
#rightpanel ();

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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
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
		set_generator=getprop("fdm/jsbsim/systems/rightpanel/generator-switch");
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
				setprop("fdm/jsbsim/systems/leftpanel/pump-input", 0);
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

#init_gear_control();

gear_control_up = func
	{
		setprop("fdm/jsbsim/systems/gearcontrol/control-input", 1);
	}

gear_control_down = func
	{
		setprop("fdm/jsbsim/systems/gearcontrol/control-input", -1);
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

# start gear control process first time
#gearcontrol ();

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
			aileron_second_rod_shift_x=math.sqrt(
				(0.230-0.200)*(0.230-0.200)+(0.036-0.007)*(0.036-0.007)
				)
				*(-math.sin(aileron_second_rod_source_angle/180*math.pi)+math.sin(aileron_second_rod_next_angle/180*math.pi));

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
		setprop("instrumentation/stick/brake_middle_x", brake_middle_x);
		brake_middle_y=abs((-0.011-0.002)/2);
		setprop("instrumentation/stick/brake_middle_y", brake_middle_y);
		brake_z=0.337;
		setprop("instrumentation/stick/brake_z", brake_z);
		saxle_middle_x=abs((-0.032-0.049)/2);
		setprop("instrumentation/stick/saxle_middle_x", saxle_middle_x);
		saxle_middle_y=abs((-0.038-0.018)/2);
		setprop("instrumentation/stick/saxle_middle_y", saxle_middle_y);
		saxle_z=0.345;
		setprop("instrumentation/stick/saxle_z", saxle_z);
		blocker_middle_x=abs((-0.038-0.043)/2);
		setprop("instrumentation/stick/blocker_middle_x", blocker_middle_x);
		blocker_middle_y=abs((-0.031-0.026)/2);
		setprop("instrumentation/stick/blocker_middle_y", blocker_middle_y);
		blocker_z=0.216;
		setprop("instrumentation/stick/blocker_z", blocker_z);
		rod_middle_x=abs((-0.020-0.031)/2);
		setprop("instrumentation/stick/rod_middle_x", rod_middle_x);
		rod_middle_y=abs((-0.023-0.010)/2);
		setprop("instrumentation/stick/rod_middle_y", rod_middle_y);
		rod_z=0.338;
		setprop("instrumentation/stick/rod_z", rod_z);

		saxle_shoulder_xy=math.sqrt((brake_middle_x-saxle_middle_x)*(brake_middle_x-saxle_middle_x)+(brake_middle_y-saxle_middle_y)*(brake_middle_y-saxle_middle_y));
		setprop("instrumentation/stick/saxle_shoulder_xy", saxle_shoulder_xy);
		saxle_shoulder_z=abs(brake_z-saxle_z);
		setprop("instrumentation/stick/saxle_shoulder_z", saxle_shoulder_z);
		saxle_source_angle=math.atan2(abs(brake_z-saxle_z), saxle_shoulder_xy);
		setprop("instrumentation/stick/saxle_source_angle", saxle_source_angle);
		saxle_source_angle_deg=saxle_source_angle/math.pi*180;
		setprop("instrumentation/stick/saxle_source_angle_deg", saxle_source_angle_deg);
		saxle_angle=saxle_source_angle+brake_angle/180*math.pi;
		setprop("instrumentation/stick/saxle_angle", saxle_angle);
		saxle_angle_deg=saxle_angle/math.pi*180;
		setprop("instrumentation/stick/saxle_angle_deg", saxle_angle_deg);
		saxle_shoulder=math.sqrt(saxle_shoulder_xy*saxle_shoulder_xy+saxle_shoulder_z*saxle_shoulder_z);
		setprop("instrumentation/stick/saxle_shoulder", saxle_shoulder);
		saxle_pos_xy=saxle_shoulder*math.cos(saxle_angle);
		setprop("instrumentation/stick/saxle_pos_xy", saxle_pos_xy);
		saxle_pos_z=brake_z+saxle_shoulder*math.sin(saxle_angle);
		setprop("instrumentation/stick/saxle_pos_z", saxle_pos_z);
		blocker_source_xy=math.sqrt((brake_middle_x-blocker_middle_x)*(brake_middle_x-blocker_middle_x)+(brake_middle_y-blocker_middle_y)*(brake_middle_y-blocker_middle_y));
		setprop("instrumentation/stick/blocker_source_xy", blocker_source_xy);
		blocker_shoulder_xy=abs(blocker_source_xy-saxle_pos_xy);
		setprop("instrumentation/stick/blocker_shoulder_xy", blocker_shoulder_xy);
		blocker_shoulder_z=abs(blocker_z-saxle_pos_z);
		setprop("instrumentation/stick/blocker_shoulder_z", blocker_shoulder_z);
		blocker_angle=math.atan2(blocker_shoulder_xy, blocker_shoulder_z);
		setprop("instrumentation/stick/blocker_angle", blocker_angle);
		blocker_angle_deg=blocker_angle/math.pi*180;
		setprop("instrumentation/stick/blocker_angle_deg", blocker_angle_deg);

		rod_shoulder_xy=math.sqrt((brake_middle_x-rod_middle_x)*(brake_middle_x-rod_middle_x)+(brake_middle_y-rod_middle_y)*(brake_middle_y-rod_middle_y));
		setprop("instrumentation/stick/rod_shoulder_xy", rod_shoulder_xy);
		rod_shoulder_z=abs(brake_z-rod_z);
		setprop("instrumentation/stick/rod_shoulder_z", rod_shoulder_z);
		rod_source_angle=math.atan2(rod_shoulder_z, rod_shoulder_xy);
		setprop("instrumentation/stick/rod_source_angle", rod_source_angle);
		rod_angle=rod_source_angle+brake_angle/180*math.pi;
		setprop("instrumentation/stick/rod_angle", rod_angle);
		rod_angle_deg=rod_angle/math.pi*180;
		setprop("instrumentation/stick/rod_angle_deg", rod_angle_deg);
		rod_account_z=rod_shoulder_xy*math.sin(rod_angle)/math.cos(rod_angle);
		setprop("instrumentation/stick/rod_account_z", rod_account_z);
		rod_shift_z=-rod_shoulder_z+rod_account_z;
		setprop("instrumentation/stick/rod_shift_z", rod_shift_z);

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

#init_stick_buttons();

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

#stick_buttons();

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
		gear_one_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		gear_two_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		gear_three_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
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
