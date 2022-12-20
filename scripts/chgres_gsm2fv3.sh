#!/bin/bash
####################################
export TYPE=SIGIO

export CASE=C48
export LEVS=150
export CDATE=2022110200

export IC_DIR=/scratch1/NCEPDEV/swpc/Adam.Kubaryk/prod
export OUTDIR=`pwd`/output_chgres
####################################
if [ $LEVS = 150 ] ; then
  export IDVT=${IDVT:-200}
  export IDVC=3
  export IDVM=32
  export NTRAC=${NTRAC:-5}
  export NVCOORD=${NVCOORD:-3}
fi

export RELEASEDIR=`pwd`/..

export CHGRES_WRAPPER=$RELEASEDIR/ush/global_chgres_driver.sh

export FIXgsm=/scratch1/NCEPDEV/swpc/WAM-IPE_DATA/WAM_FIX/GSM/fix_am
export FIXfv3=/scratch1/NCEPDEV/global/glopara/fix/orog/20220805

export CRES=`echo $CASE | cut -c 2-`

export CHGRESEXEC=$RELEASEDIR/exec/global_chgres_fv3
export CHGRESSH=$RELEASEDIR/ush/global_chgres.sh

if [[ $TYPE == "NEMSIO" ]] ; then
    export nemsio_get=/scratch1/NCEPDEV/swpc/Adam.Kubaryk/util/exec/nemsio_get

    export ATMANL=$IC_DIR/gfnanl.gdas.$CDATE
    export SFCANL=$IC_DIR/sfnanl.gdas.$CDATE
    export NSTANL=$IC_DIR/nsnanl.gdas.$CDATE

    export ATMJCAP=`$nemsio_get $ATMANL jcap | tr -s ' ' | cut -d' ' -f 3`
    export ATMNLON=`$nemsio_get $ATMANL dimx | tr -s ' ' | cut -d' ' -f 3`
    export ATMNLAT=`$nemsio_get $ATMANL dimy | tr -s ' ' | cut -d' ' -f 3`
    export nst_anl=.true.
    # to use new albedo, soil/veg type
    export IALB=1
    export SOILTYPE_INP=statsgo
    export SOILTYPE_OUT=statsgo
    export FNVETC=$FIXgsm/global_vegtype.igbp.t${ATMJCAP}.${ATMNLON}.${ATMNLAT}.rg.grb
    export FNSMCC=$FIXgsm/global_soilmgldas.t${ATMJCAP}.${ATMNLON}.${ATMNLAT}.grb
    export FNSOTC=$FIXgsm/global_soiltype.statsgo.t${ATMJCAP}.${ATMNLON}.${ATMNLAT}.rg.grb
    export FNABSC=$FIXgsm/global_mxsnoalb.uariz.t${ATMJCAP}.${ATMNLON}.${ATMNLAT}.rg.grb
    export FNALBC=$FIXgsm/global_snowfree_albedo.bosu.t${ATMJCAP}.${ATMNLON}.${ATMNLAT}.rg.grb
    export VEGTYPE_INP=igbp
    export VEGTYPE_OUT=igbp
    # needed for facsf and facwf
    export FNALBC2=$FIXgsm/global_albedo4.1x1.grb
    export FNZORC=igbp
    export nopdpvv=.true.
else
    pdy=${CDATE::8}
    cyc=${CDATE:8}
    export SIGINP=$IC_DIR/wdas.$pdy/$cyc/wdas.t${cyc}z.atmf06
    export SFCANL=$IC_DIR/wdas.$pdy/$cyc/wdas.t${cyc}z.sfcf06
    export nst_anl=.false.
    # albedo, soil/veg
    export SOILTYPE_INP=zobler
    export SOILTYPE_OUT=zobler
    export VEGTYPE_INP=sib
    export VEGTYPE_OUT=sib
    export FNZORC=sib
    export nopdpvv=.false.
    # resolution settings
    export LONB_SFC=$CRES
    export LATB_SFC=$CRES
    export LONB_ATM=$((CRES*4))
    export LATB_ATM=$((CRES*2))
    if [ $CRES -gt 768 ]; then
        export LONB_ATM=3072
        export LATB_ATM=1536
    fi
fi

. $CHGRES_WRAPPER
