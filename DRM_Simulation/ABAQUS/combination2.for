	 SUBROUTINE UMESHMOTION(UREF,ULOCAL,NODE,NNDOF,
     1    LNODETYPE,ALOCAL,NDIM,TIME,DTIME,PNEWDT,
     2    KSTEP,KINC,KMESHSWEEP,JMATYP,JGVBLOCK,LSMOOTH)
!
      INCLUDE 'ABA_PARAM.INC'
!
!----- 声明区 -----------------------------------------------------------
      CHARACTER*80 PARTNAME
      DIMENSION ARRAY(1000)
      DIMENSION OLDSLIPZ(700000), TEMPSLIPZ(700000)
      ! SAVE变量替代COMMON来存储变量
      SAVE OLDSLIPZ, TEMPSLIPZ
      DIMENSION WVLOCAL(3), WVGLOBAL(3)
      DIMENSION ULOCAL(*)
      DIMENSION JGVBLOCK(*), JMATYP(*)
      DIMENSION ALOCAL(NDIM,*), TIME(2)
      PARAMETER (NELEMMAX=1000)
      DIMENSION JELEMLIST(NELEMMAX), JELEMTYPE(NELEMMAX)
      PARAMETER(cof=1.0D-7)
      
      ! 声明为REAL*8以提高精度
      REAL*8 current_x, current_y, current_z
      REAL*8 current_x1, current_y1, current_z1
      REAL*8 CPRESS, CSHEAR, CSLIP, w_dist,r_dist, wear_k, dist_n1
	  REAL*8 PRESS_THRESHOLD
      INTEGER JTYP, JRCD, LOCNUM, NELEMS, LTRN
      CHARACTER*80 FILENAME
      
      ! 烧蚀参数
      DOUBLE PRECISION T_NODE, T_CRIT, EROSION_RATE
      ! 模式判断变量 - 声明移到此处
      INTEGER IS_ARC_STEP
!
!----- 参数设定 ---------------------------------------------------------
      ! 模型参数设定
      T_CRIT = 1200.0D0               ! 烧蚀开始的温度阈值 (示例值 500K)
      EROSION_RATE = 2.8D-3           ! 烧蚀速率系数1.0/1.5E-3
      wear_k = 7.0D-7                 ! 磨损系数
	  PRESS_THRESHOLD = 4000.0D0      ! 接触应力阈值
!
!----- 初始化步骤 -------------------------------------------------------
      ! 在第一步初始化变量
      IF(KSTEP.EQ.1 .AND. KINC.EQ.1) THEN
          OLDSLIPZ(1:700000) = 0.0D0
          TEMPSLIPZ(1:700000) = 0.0D0
      ENDIF

      ! 设置输出文件名
      WRITE(FILENAME, '(a,i3.3,a)') 'c:\output\wear_step', KSTEP, '.txt'
      OPEN(unit=16, file=FILENAME, position='append')
      
!----- 获取节点信息 -----------------------------------------------------
      JTYP = 0
      JRCD = 0
      LOCNUM = 0
      PARTNAME = ''
      
      CALL GETPARTINFO(NODE, JTYP, PARTNAME, LOCNUM, JRCD)
      NELEMS = NELEMMAX
      CALL GETNODETOELEMCONN(NODE, NELEMS, JELEMLIST, JELEMTYPE, JRCD,
     1     JGVBLOCK)
      
      ! 获取节点坐标
      LTRN = 0
      CALL GETVRN(NODE, 'COORD', ARRAY, JRCD, JGVBLOCK, LTRN)
      current_x = ARRAY(1)
      current_y = ARRAY(2)
      current_z = ARRAY(3)
      
!----- 根据步骤类型执行不同的网格变形 ----------------------------------
      ! 根据步骤序号判断当前是否为Arc步骤
      ! 规则：假设每3个步骤为一个循环，第2个步骤为Arc步骤
      ! 例如：Step1-Open, Step2-Arc, Step3-Close, Step4-Open, Step5-Arc, ...
      IS_ARC_STEP = 0
      IF (MOD(KSTEP, 3) .EQ. 2) THEN
          IS_ARC_STEP = 1
      ENDIF

      ! 根据步骤类型执行不同的网格变形
      IF (IS_ARC_STEP .EQ. 1) THEN
          ! 执行烧蚀变形
          LSMOOTH = 1  ! 关闭或减少全局网格光顺
          
          ! 读取节点温度
          LTRN = 0
          CALL GETVRN(NODE, 'NT', ARRAY, JRCD, JGVBLOCK, LTRN)
          T_NODE = ARRAY(1)
          
          ! 当温度超过阈值时进行烧蚀
          IF (T_NODE .GT. T_CRIT) THEN
		      r_dist = EROSION_RATE*(T_NODE - T_CRIT)*DTIME		      
		      current_x1=current_x
			  current_y1=0
			  current_z1=current_z
			  dist_n1=SQRT((current_x1-current_x)**2+(current_y1-current_y)**2+(current_z1-current_z)**2)
              WVGLOBAL(1) = r_dist*(current_x1-current_x)/dist_n1
              WVGLOBAL(2) = r_dist*(current_y1-current_y)/dist_n1
              WVGLOBAL(3) = r_dist*(current_z1-current_z)/dist_n1
              DO k1=1,NDIM
                  WVLOCAL(k1) = 0
                      DO k2=1,NDIM
                          WVLOCAL(k1)=WVLOCAL(k1)+WVGLOBAL(k2)*ALOCAL(k2,k1)
                      END DO
              END DO
              DO k1=1,NDIM
                  ULOCAL(k1) = ULOCAL(k1) + WVLOCAL(k1)
              END DO          
              
              ! 将烧蚀信息写入文件
              WRITE(16, 101) NODE, T_NODE, T_CRIT, r_dist
          ENDIF
          
      ELSE
          ! 执行磨损变形 (Open或Close步骤)
          
          ! 获取接触应力
      CALL GETVRMAVGATNODE(NODE, JTYP, 'CSTRESS', ARRAY, JRCD, 
     1     JELEMLIST, NELEMS, JMATYP, JGVBLOCK)      
      CPRESS = ABS(ARRAY(1))
      CSHEAR = SQRT(ARRAY(2)**2+ARRAY(3)**2)

      ! 在这里添加接触应力阈值判断
      ! 注意：PARAMETER语句应该移到前面的声明区
      IF (CPRESS .GT. PRESS_THRESHOLD) THEN
          ! 获取相对滑移量
          CALL GETVRMAVGATNODE(NODE, JTYP, 'CDISP', ARRAY, JRCD, 
     1         JELEMLIST, NELEMS, JMATYP, JGVBLOCK)         
          CSLIP = SQRT(ARRAY(2)**2+ARRAY(3)**2)
          TEMPSLIPZ(NODE) = CSLIP - OLDSLIPZ(NODE)
          OLDSLIPZ(NODE) = CSLIP
          
          ! 计算磨损量
          w_dist = CPRESS*ABS(TEMPSLIPZ(NODE))*wear_k
          
          ! 输出磨损历史
          WRITE(16, 102) NODE, CPRESS, CSLIP, TEMPSLIPZ(NODE), w_dist
          
          ! 应用磨损的网格变形 (简化为Z方向)
          ULOCAL(1) = 0.0D0
          ULOCAL(2) = 0.0D0      
          ULOCAL(3) = ULOCAL(3) - w_dist
      ELSE
          ! 接触应力低于阈值，不计算磨损
          ULOCAL(1) = 0.0D0
          ULOCAL(2) = 0.0D0
          ULOCAL(3) = ULOCAL(3)  ! 不变形
          
          ! 可选：输出低于阈值的记录
          WRITE(16, 103) NODE, CPRESS, PRESS_THRESHOLD
      ENDIF
	  ENDIF
!
! 关闭文件
      IF(NODE .EQ. 1) THEN
          CLOSE(16)
      ENDIF
!
101   FORMAT(1x,'烧蚀:',I8,3(1pg11.4))
102   FORMAT(1x,'磨损:',I8,4(1pg11.4))
103   FORMAT(1x,'低压不磨损:',I8,2(1pg11.4))
      RETURN
      END