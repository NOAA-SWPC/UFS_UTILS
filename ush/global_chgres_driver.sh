#!/bin/ksh
set -ax
#-------------------------------------------------------------------------------------------------
# This is an adapted version of the below for generalized FV3 runs for the DAD modeling group
#-------------------------------------------------------------------------------------------------
# Makes ICs on fv3 globally uniform cubed-sphere grid using operational GFS initial conditions.
# Fanglin Yang, 09/30/2016
#  This script is created based on the C-shell scripts fv3_gfs_preproc/IC_scripts/DRIVER_CHGRES.csh
#  and submit_chgres.csh provided by GFDL.  APRUN and environment variables are added to run on
#  WCOSS CRAY.  Directory and file names are standaridized to follow NCEP global model convention.
#  This script calls fv3gfs_chgres.sh.
# Fanglin Yang and George Gayno, 02/08/2017
#  Modified to use the new CHGRES George Gayno developed.
# Fanglin Yang 03/08/2017
#  Generalized and streamlined the script and enabled to run on multiple platforms.
# Fanglin Yang 03/20/2017
#  Added option to process NEMS GFS initial condition which contains new land datasets.
#  Switch to use ush/global_chgres.sh.
#-------------------------------------------------------------------------------------------------

export OMP_NUM_THREADS_CH=${OMP_NUM_THREADS_CH:-1}
export APRUNC=${APRUNC:-"time"}

export CASE=${CASE:-C96}                     # resolution of tile: 48, 96, 192, 384, 768, 1152, 3072
export CRES=${CRES:-`echo $CASE | cut -c 2-`}
export CDATE=${CDATE:-${cdate:-2017031900}}  # format yyyymmddhh yyyymmddhh ...
export LEVS=${LEVS:-65}
export LSOIL=${LSOIL:-4}

export VERBOSE=YES
pwd=$(pwd)
export NWPROD=${NWPROD:-$pwd}
export BASE_GSM=${BASE_GSM:-$NWPROD/global_shared}
export FIXgsm=${FIXgsm:-$BASE_GSM/fix/fix_am}
export FIXfv3=${FIXfv3:-$BASE_GSM/fix/fix_fv3}
export CHGRESEXEC=${CHGRESEXEC:-$BASE_GSM/exec/global_chgres}
export CHGRESSH=${CHGRESSH:-$BASE_GSM/ush/global_chgres.sh}

# Location of initial conditions for GFS (before chgres) and FV3 (after chgres)
export INIDIR=${IC_DIR:-$pwd}
export OUTDIR=${OUTDIR:-$IC_DIR/L${LEVS}/CASE_$CASE}
mkdir -p $OUTDIR

#---------------------------------------------------------
export gtype=${gtype:-uniform}	          # grid type = uniform, stretch, or nest

if [ $gtype = uniform ];  then
  echo "creating uniform ICs"
  export name=${CASE}
  export ntiles=6
elif [ $gtype = stretch ]; then
  export stetch_fac=       	                 # Stretching factor for the grid
  export rn=`expr $stetch_fac \* 10 `
  export name=${CASE}r${rn}       		 # identifier based on refined location (same as grid)
  export ntiles=6
  echo "creating stretched ICs"
elif [ $gtype = nest ]; then
  export stetch_fac=1.5  	                         # Stretching factor for the grid
  export rn=`expr $stetch_fac \* 10 `
  export refine_ratio=3   	                 # Specify the refinement ratio for nest grid
  export name=${CASE}r${rn}n${refine_ratio}      # identifier based on nest location (same as grid)
  export ntiles=7
  echo "creating nested ICs"
else
  echo "Error: please specify grid type with 'gtype' as uniform, stretch, or nest"
fi

#---------------------------------------------------------------

# Temporary rundirectory
export DATA=${DATA:-${RUNDIR:-$pwd/rundir$$}}
if [ ! -s $DATA ]; then mkdir -p $DATA; fi
cd $DATA || exit 8

export NVCOORD=${NVCOORD:-2}
export IDVC=${IDVC:-2}
export IDVM=${IDVM:-0}
export IDVT=${IDVT:-21}
export IDSL=${IDSL:-1}
export RI_LIST=${RI_LIST:-"295.3892,  461.50,     0.0, 173.2247,  519.674, 259.8370,"}
export CPI_LIST=${CPI_LIST:-"1031.1083, 1846.00,     0.0, 820.2391, 1299.185, 918.0969,"}

export CLIMO_FIELDS_OPT=3
export LANDICE_OPT=2
if [ $NVCOORD = 3 ] ; then export SIGLEVEL=${FIXgsm}/global_hyblev3.l${LEVS}.txt ; else export SIGLEVEL=${FIXgsm}/global_hyblev.l${LEVS}.txt ; fi
if [ $LEVS = 128 ]; then export SIGLEVEL=${FIXgsm}/global_hyblev.l${LEVS}B.txt; fi
export FNGLAC=${FNGLAC:-${FIXgsm}/global_glacier.2x2.grb}
export FNMXIC=${FNMXIC:-${FIXgsm}/global_maxice.2x2.grb}
export FNTSFC=${FNTSFC:-${FIXgsm}/cfs_oi2sst1x1monclim19822001.grb}
export FNSNOC=${FNSNOC:-${FIXgsm}/global_snoclim.1.875.grb}
export FNALBC=${FNALBC:-${FIXgsm}/global_albedo4.1x1.grb}
export FNALBC2=${FNALBC2:-${FIXgsm}/global_albedo4.1x1.grb}
export FNAISC=${FNAISC:-${FIXgsm}/cfs_ice1x1monclim19822001.grb}
export FNTG3C=${FNTG3C:-${FIXgsm}/global_tg3clim.2.6x1.5.grb}
export FNVEGC=${FNVEGC:-${FIXgsm}/global_vegfrac.0.144.decpercent.grb}
export FNVETC=${FNVETC:-${FIXgsm}/global_vegtype.1x1.grb}
export FNSOTC=${FNSOTC:-${FIXgsm}/global_soiltype.1x1.grb}
export FNSMCC=${FNSMCC:-${FIXgsm}/global_soilmcpc.1x1.grb}
export FNVMNC=${FNVMNC:-${FIXgsm}/global_shdmin.0.144x0.144.grb}
export FNVMXC=${FNVMXC:-${FIXgsm}/global_shdmax.0.144x0.144.grb}
export FNSLPC=${FNSLPC:-${FIXgsm}/global_slope.1x1.grb}
export FNABSC=${FNABSC:-${FIXgsm}/global_snoalb.1x1.grb}
export FNMSKH=${FNMSKH:-${FIXgsm}/seaice_newland.grb}


export ymd=`echo $CDATE | cut -c 1-8`
export cyc=`echo $CDATE | cut -c 9-10`

#------------------------------------------------
# Convert atmospheric file.
#------------------------------------------------
export CHGRESVARS="use_ufo=.false.,nst_anl=$nst_anl,idvc=$IDVC,idvt=$IDVT,idsl=$IDSL,IDVM=$IDVM,nopdpvv=$nopdpvv,mquick=0,nvcoord=$NVCOORD,ri=$RI_LIST,cpi=$CPI_LIST,"
export LATB=$LATB_ATM
export LONB=$LONB_ATM

$CHGRESSH
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "***ERROR*** rc= $rc"
  exit $rc
fi

mv ${DATA}/gfs_data.tile*.nc  $OUTDIR/.
mv ${DATA}/gfs_ctrl.nc        $OUTDIR/.

#---------------------------------------------------
# Convert surface and nst files one tile at a time.
#---------------------------------------------------
export CHGRESVARS="use_ufo=.true.,nst_anl=$nst_anl,idvc=$IDVC,idvt=$IDVT,idsl=$IDSL,IDVM=$IDVM,nopdpvv=$nopdpvv"
export SIGINP=NULL
export SFCINP=$SFCANL
export NSTINP=$NSTANL
export LATB=$LATB_SFC
export LONB=$LONB_SFC

tile=1
while [ $tile -le $ntiles ]; do
 export TILE_NUM=$tile
 $CHGRESSH
 rc=$?
 if [[ $rc -ne 0 ]] ; then
   echo "***ERROR*** rc= $rc"
   exit $rc
 fi
 mv ${DATA}/out.sfc.tile${tile}.nc $OUTDIR/sfc_data.tile${tile}.nc
 [[ $nst_anl = ".true." ]] && mv ${DATA}/out.nst.tile${tile}.nemsio $OUTDIR/nst_data.tile${tile}.nemsio
 tile=`expr $tile + 1 `
done

return 0

