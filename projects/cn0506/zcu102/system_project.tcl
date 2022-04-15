
source ../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

##--------------------------------------------------------------
# IMPORTANT: Set CN0506 interface mode
#
# The get_env_param procedure retrieves parameter value from the environment if exists,
# other case returns the default value specified in its second parameter field.
#
#   How to use over-writable parameters from the environment:
#
#    e.g.
#      make INTF_CFG=0
#
#    INTF_CFG  - Defines the interface type (MII, RGMII or RMII)
#
# LEGEND: MII    - 0
#         RGMII  - 1
#         RMII   - 2
#
##--------------------------------------------------------------

if {[info exists ::env(INTF_CFG)]} {
  set INTF_CFG [get_env_param INTF_CFG 0]
} elseif {![info exists INTF_CFG]} {
  set INTF_CFG 0
}

adi_project cn0506_zc706 0 [list \
  INTF_CFG  $INTF_CFG \
]

adi_project_files  cn0506_zcu102 [list \
  "$ad_hdl_dir/projects/common/zcu102/zcu102_system_constr.xdc" ]

switch $INTF_CFG {
  0 {
    adi_project_files cn0506_zcu102 [list \
      "system_top_mii.v" \
      "mii_if_constr.xdc"
    ]
  }
  1 {
    adi_project_files cn0506_zcu102 [list \
      "system_top_rgmii.v" \
      "rgmii_if_constr.xdc"
    ]
  }
  2 {
    adi_project_files cn0506_zcu102 [list \
      "system_top_rmii.v" \
      "rmii_if_constr.xdc"
    ]
  }
}

adi_project_run cn0506_zcu102
