      SUBROUTINE UMESHMOTION(UREF,ULOCAL,NODE,NNDOF,
     *    LNODETYPE,ALOCAL,NDIM,TIME,DTIME,PNEWDT,
     *    KSTEP,KINC,KMESHSWEEP,JMATYP,JGVBLOCK,LSMOOTH)
C
      INCLUDE 'ABA_PARAM.INC'
C
      CHARACTER*80 PARTNAME
      DIMENSION ARRAY(1000),JPOS(15)
      DIMENSION OLDSLIPZ(700000),TEMPSLIPZ(700000)
      COMMON OLDSLIPZ,TEMPSLIPZ
      DIMENSION WVLOCAL(3),WVGLOBAL(3)
      DIMENSION ULOCAL(*)
      DIMENSION JGVBLOCK(*),JMATYP(*)
      DIMENSION ALOCAL(NDIM,*),TIME(2)
      PARAMETER (NELEMMAX=1000)
      DIMENSION JELEMLIST(NELEMMAX),JELEMTYPE(NELEMMAX)
      PARAMETER(cof=1.0D-7)
      REAL::current_x,current_y,current_x1,current_y1
      REAL::current_z1,current_x2,current_y2,current_z2
      REAL::CPRESS,CSHEAR,CSLIP,w_dist

      OPEN(unit=16,file='c:\output\test4.txt',status='unknown')
      
      OLDSLIPZ(1:30000) = 0
      TEMPSLIPZ(1:30000) = 0
      JTYP = 0
      JRCD = 0
      
      LOCNUM = 0
      LOCNUM1 = 0
      LOCNUM2 = 0
      PARTNAME=''
      wear_k = 8.0D-8
      !dist_n = 0
      
      CALL GETPARTINFO(NODE,JTYP,PARTNAME,LOCNUM,JRCD)
      NELEMS = NELEMMAX
      CALL GETNODETOELEMCONN(NODE,NELEMS,JELEMLIST,JELEMTYPE,JRCD,
     1     JGVBLOCK)
      LTRN = 0
      
      CALL GETVRN(NODE,'COORD',ARRAY,JRCD,JGVBLOCK,LTRN)
      current_x=ARRAY(1)
      current_y=ARRAY(2)
      current_z=ARRAY(3)
      
      CALL GETVRMAVGATNODE(NODE,JTYP,'CSTRESS',ARRAY,JRCD,JELEMLIST,
     1     NELEMS,JMATYP,JGVBLOCK)      
      CPRESS = ARRAY(1)
      CSHEAR = SQRT(ARRAY(2)**2+ARRAY(3)**2)
      CALL GETVRMAVGATNODE(NODE,JTYP,'CDISP',ARRAY,JRCD,JELEMLIST,
     1     NELEMS,JMATYP,JGVBLOCK)         
      CSLIP = SQRT(ARRAY(2)**2+ARRAY(3)**2)
      TEMPSLIPZ(NODE)=CSLIP-OLDSLIPZ(NODE)
      OLDSLIPZ(NODE)=CSLIP
     ! 
     !! CALL GETVRMAVGATNODE(NODE,JTYP,'CDISP',ARRAY,JRCD,JELEMLIST,
     !!1     NELEMS,JMATYP,JGVBLOCK)         
     !! CSLIP = SQRT(ARRAY(2)**2+ARRAY(3)**2)      
      
      !w_dist = CPRESS*TEMPSLIPZ(NODE)*wear_k
      w_dist = 0.005
      WRITE(16,101),NODE,CPRESS,CSLIP,TEMPSLIPZ(NODE),JRCD        
      IF(NODE.GT.12220) THEN
    
      IF(LNODETYPE.eq.3.or.LNODETYPE.eq.4) THEN
          current_x1=100.0
          current_y1=current_y
          current_z1=current_z
          dist_n1=SQRT((current_x1-current_x)**2+(current_y1-current_y)
     1    **2+(current_z1-current_z)**2)
          WVGLOBAL(1) = w_dist*(current_x1-current_x)/dist_n1
          WVGLOBAL(2) = w_dist*(current_y1-current_y)/dist_n1
          WVGLOBAL(3) = w_dist*(current_z1-current_z)/dist_n1
          DO k1=1,NDIM
              WVLOCAL(k1) = 0
                  DO k2=1,NDIM
                      WVLOCAL(k1)=WVLOCAL(k1)+WVGLOBAL(k2)*ALOCAL(k2,k1)
                  END DO
          END DO
          DO k1=1,NDIM
              ULOCAL(k1) = ULOCAL(k1) + WVLOCAL(k1)
          END DO          
      ELSE
          ULOCAL(1) = 0
          ULOCAL(2) = 0      
          ULOCAL(3) = ULOCAL(3) - w_dist
      ENDIF    

      



C      LTRN = 0      
      
101   FORMAT(1x,5(1pg11.4))
      RETURN
      END