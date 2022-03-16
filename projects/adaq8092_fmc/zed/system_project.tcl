# load script
source ../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

##--------------------------------------------------------------
# IMPORTANT: Set AD7616 operation and interface mode
#
# The get_env_param procedure retrieves parameter value from the environment if exists,
# other case returns the default value specified in its second parameter field.
#
#   How to use over-writable parameters from the environment:
#
#    e.g.
#      make OUTPUT_MODE=DDR_LVDS
#
#    OUTPUT_MODE  - Defines the output mode DDR_LVDS, DDR_CMOS or SDR_CMOS.
#
# NOTE : This switch is a 'hardware' switch. Please reimplenent the
# design if the variable has been changed.
#
##--------------------------------------------------------------

if {[info exists ::env(OUTPUT_MODE)]} {
  set S_OUTPUT_MODE [get_env_param OUTPUT_MODE DDR_LVDS]
} elseif {![info exists OUTPUT_MODE]} {
  set S_OUTPUT_MODE DDR_LVDS
}

adi_project adaq8092_fmc_zed 0 [list \
  OUTPUT_MODE  $S_OUTPUT_MODE \
]


adi_project_files adaq8092_fmc_zed [list \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/common/zed/zed_system_constr.xdc"]


switch $S_OUTPUT_MODE {
  DDR_LVDS {
    adi_project_files adaq8092_fmc_zed [list \
      "system_top_ddr_lvds.v" \
      "ddr_lvds_constr.xdc"]
  }
  DDR_CMOS {
    adi_project_files adaq8092_fmc_zed [list \
      "system_top_ddr_cmos.v" \
      "ddr_cmos_constr.xdc"]
  }
  SDR_CMOS {
    adi_project_files adaq8092_fmc_zed [list \
      "system_top_sdr_cmos.v" \
      "sdr_cmos_constr.xdc"]
  }
}

adi_project_run adaq8092_fmc_zed
