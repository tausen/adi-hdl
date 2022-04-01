
package require qsys 14.0
source ../scripts/adi_env.tcl
source ../scripts/adi_ip_intel.tcl

set_module_property NAME axi_pwm_gen
set_module_property DESCRIPTION "ADI AXI PWM Generator"
set_module_property VERSION 1.0
set_module_property GROUP "Analog Devices"
set_module_property DISPLAY_NAME axi_pwm_gen

# source files

ad_ip_files axi_pwm_gen [list \
  "$ad_hdl_dir/library/common/ad_rst.v" \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "axi_pwm_gen_constr.sdc" \
  "axi_pwm_gen_regmap.v" \
  "axi_pwm_gen_1.v" \
  "axi_pwm_gen.v"]

# IP parameters

ad_ip_parameter ASYNC_CLK_EN BOOLEAN 1 true [list \
  DISPLAY_NAME "ASYNC_CLK_EN" \
  GROUP $group \
]

ad_ip_parameter EXT_ASYNC_SYNC BOOLEAN 0 true [list \
  DISPLAY_NAME "EXT_ASYNC_SYNC" \
  GROUP $group \
]

ad_ip_parameter PWM_EXT_SYNC BOOLEAN 0 true [list \
  DISPLAY_NAME "PWM_EXT_SYNC" \
  GROUP $group \
]

ad_ip_parameter N_PWMS INTEGER 1 true [list \
  DISPLAY_NAME "N_PWMS" \
  ALLOWED_RANGES {1 2 3 4} \
  GROUP $group \
]

for {set i 0} {$i < 4} {incr i} {
  ad_ip_parameter "PULSE_${i}_WIDTH" INTEGER 1 true [list \
  DISPLAY_NAME "PULSE_${i}_WIDTH" \
  GROUP $group ]

  ad_ip_parameter "PULSE_${i}_PERIOD" INTEGER 1 true [list \
  DISPLAY_NAME "PULSE_${i}_PERIOD" \
  GROUP $group ]

  ad_ip_parameter "PULSE_${i}_OFFSET" INTEGER 1 true [list \
  DISPLAY_NAME "PULSE_${i}_OFFSET" \
  GROUP $group ]
}

# AXI4 Memory Mapped Interface

ad_ip_intf_s_axi s_axi_aclk s_axi_aresetn 15

# external clock and control/status ports

ad_interface clock  ext_clk           input  1  
ad_interface signal ext_sync          input  1

ad_interface signal pwm_0             output 1  
ad_interface signal pwm_1             output 1 	
ad_interface signal pwm_2             output 1 	
ad_interface signal pwm_3             output 1 	

