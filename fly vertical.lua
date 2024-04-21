-- command a Copter to takeoff to 5m and fly a vertical circle in the clockwise direction
--
-- CAUTION: This script only works for Copter
-- this script waits for the vehicle to be armed and RC6 input > 1800 and then:
--    a) switches to Guided mode
--    b) takeoff to 5m
--    c) flies a vertical circle using the velocity controller
--    d) switches to RTL mode

local takeoff_alt_above_home = 5
local copter_guided_mode_num = 4
local copter_poshold_mode = 16
local copter_rtl_mode_num = 6
local stage = 0
local circle_angle = 0
local circle_angle_increment = 1    -- increment the target angle by 1 deg every 0.1 sec (i.e. 10deg/sec)
local circle_speed = 1              -- velocity is always 1m/s
local yaw_cos = 0                   -- cosine of yaw at takeoff
local yaw_sin = 0                   -- sine of yaw at takeoff
local radius=0
-- the main update function that uses the takeoff and velocity controllers to fly a rough square pattern
function update()
  if not arming:is_armed() then -- reset state when disarmed
    stage = 0
    circle_angle = 0
  else
    pwm6 = rc:get_pwm(6)
    if(pwm6 and pwm6>1490 and pwm6<1510) then
      vehicle:set_mode(copter_poshold_mode)
    end
    if (pwm6 and pwm6 > 1800 and takeoff_alt_above_home >= 5) then    -- check if RC6 input has moved high
      vehicle:set_mode(copter_guided_mode_num)
      if (stage == 0) then          -- change to guided mode
        vehicle:set_mode(copter_guided_mode_num)
        if (vehicle:set_mode(copter_guided_mode_num)) then  -- change to Guided mode
          local yaw_rad = ahrs:get_yaw()
          yaw_cos = math.cos(yaw_rad)
          yaw_sin = math.sin(yaw_rad)
          stage = stage + 1
        end
      elseif (stage == 1 ) then   -- Stage3: fly a vertical circle

        -- calculate velocity vector
        circle_angle = circle_angle + circle_angle_increment
        if (circle_angle >= 360) then
          -- stage = stage
          circle_angle=0
        end
        pwm1 = rc:get_pwm(1)
        pwm2=rc:get_pwm(2)
        if pwm2 and pwm2>1600 then
          circle_speed=circle_speed+0.1
          gcs:send_text(0,circle_speed)
        elseif pwm2 and pwm2<1400 then
          circle_speed=circle_speed-0.1
          gcs:send_text(0,circle_speed)
        end
        if pwm1 and pwm1 > 1600 then
          circle_angle_increment=circle_angle_increment+0.1
          gcs:send_text(0,circle_angle_increment)
        elseif pwm1 and pwm1<1400 then
          circle_angle_increment=circle_angle_increment-0.1
          gcs:send_text(0,circle_angle_increment)
        end
          
        local target_vel = Vector3f()
        local vel_xy = math.cos(math.rad(circle_angle)) * circle_speed
        target_vel:x(yaw_sin * vel_xy)
        target_vel:y(yaw_cos * -vel_xy)
        target_vel:z(-math.sin(math.rad(circle_angle)) * circle_speed)
        -- local radius=circle_speed/circle_angle
        local radius=circle_speed/(math.rad(circle_angle_increment)*3.1415)
        gcs:send_text(0,radius)

        -- send velocity request
        if not (vehicle:set_target_velocity_NED(target_vel)) then
          gcs:send_text(0, "failed to execute velocity command")
        end
      end
    end
  end

  return update, 50
end
return update()