module demin_command
use pointer_lattice
implicit none
private
integer :: mr=5,mw=6,posr
type(mad_universe),pointer:: d_u=> null()
type(layout),pointer:: d_line=> null()


logical :: ptc_exist =.false.,verbose =.true.
type(internal_state), target :: d_state,d_default
real(dp) :: Sj(6,6) =0,deltar
integer :: d_pos=1,d_np=0,d_no=1
type(fibre), pointer :: fib,d_fib
real(dp) :: epsc=1.d-6, d_delta=0.0_dp,d_closed_orbit(6)
type(probe) d_probe_a,d_probe_b
logical :: compute_fix =.true., d_init_fpp_ptc=.true.
real(dp) d_phase(3),d_damping(3)
real(dp)  d_spin_tune(2),prec
type(c_linear_map) d_q_cs,d_q_as,d_q_rot,d_q_orb 
type(array_of_fibres),pointer :: d_af(:) => null()
logical :: common_twiss_name=.true.
integer :: d_ntot,ntime,ndelta,n_lat_print=0,print_title=20
integer, parameter :: nlat=10
character(11) latname(9,6,0:6) 
integer(2) ilatname(9,6,0:6), i_lat(0:nlat),j_lat(0:nlat),k_lat(0:nlat),l_lat(0:nlat),iformats
character(255) line_twiss,line_twiss_title
integer :: d_layout = 1,lib4
integer d_ndt,d_ndpt,d_nd2
!public d_field_for_demin
logical :: warning
integer d_mf
 
public d_mf
!#   2    First block saved for TeX
!  Routine to read and run the script
public d_read_script
! Routine to execute a single command of the script
public d_execute_one_command
! fibre used and its position in the array.  
!tex See \cm{c:position}
public d_resonance
! Routine to create a c_universal_taylor for a single resonance
public d_get_lattice_matrix
! Prints or gets a de Moivre matrix
public d_print_matrix
! Prints a matrix on screen or file
public d_fib,d_pos 
! state used, closed orbit at d_fib
!tex For closed orbit see \cm{c:dpcod}. For d_state see \sec{app:states}. 
public d_state,d_closed_orbit
! value of energy if no cavities in d_state%nocavity=true
!tex See \cm{c:delta} and the related states \ref{c:+delta} and \ref{c:+nocavity}.
public d_delta
! d_ndpt=position of energy:  =5 if PTC and 6 if BMAD.
! d_ndt=time position (5 in BMAD, 6 in PTC)
!tex  See \cm{c:bmad} and \ref{c:ptc}.
 public d_ndpt,d_ndt
! size of phase space (2,4,6 in PTC). 
public d_nd2 
! Order of TPSA, number of TPSA knobs 
public d_no,d_np
! true if real damping lattice functions are used
public d_do_damping
! routine to print d_state
public d_print_state ! 
! tracking routines using array of fibre in d_line
! probe and probe_8 routine
public d_track_array,d_track_array_8 
! d_line is present layout, d_u is the used universe
public d_line ,d_u
! integer index of d_line in d_u (typically 1)
! d_u is normally m_u of PTC unless a complex structure is read.
!tex See \cm{c:usedatabaseuniverse} and \ref{c:usetrackinguniverse}.
public d_layout 
! d_mod(k,size(d_line%a)) to fix k correctly
public d_mod
! kills all maps in lf's in all layouts
public d_kill_all_tpsa
! various formats 
public formats,formatl,formatld,formatd,formatdl6 
character(18) ::         formats=  "(1(1x,f9.2,1x))"
character(18) ::         formatl=  "(1(2x,f9.5,2x))"
character(18) ::         formatld= "(1(2x,f9.6,2x))"
character(18) ::         formatd=  "(1(2x,es9.2,2x))"
character(18) ::         formatdl6="(6(es12.4,1x))"
!##


logical :: d_do_damping=.true.,set_default_twiss=.true.


integer, parameter :: nlprogram=2, clprogram=70
character(132) ::  lprogram(nlprogram,clprogram)
integer :: iprog(nlprogram) =0
contains 
!!!! Main reading program  !!!!
subroutine read_flat_file(filename)
implicit none
CHARACTER(*)  filename 
          call read_lattice_append(M_U,filename)
          WRITE(mr,*) M_U%END%N, M_U%END%END%POS
          write(mr,*) "file read"

end subroutine read_flat_file


 subroutine d_read_script(ptc_fichier)
 implicit none
 CHARACTER(*)  ptc_fichier
 CHARACTER*(120) comt
logical ex,old
 integer i,mf,i_layout_temp,posr
 old=.true.
lprogram=" "
iprog=0
!call print_for_tex
warning=.false.

sj=0
do i=1,3
 sj(2*i-1,2*i)=1
 sj(2*i,2*i-1)=-1
enddo

lib4=lielib_print(4)

    if(ptc_fichier/="screen") then
      call KanalNummer(mf,ptc_fichier,old)
    else
     mf=5
    endif


    do i=1,10000
       read(mf,'(a120)') comT
       call d_execute_multiple_command(comt,mf,ex,ij=i)
       if(warning) write(6,*) "Watch a warning was issued "
      if(ex) goto 100
   enddo
100 continue

     write(6,'(a)') " Exiting Command File ", ptc_fichier(1:len_trim(ptc_fichier))

    if(mf/=5) close(mf)
       if(warning) then
       do i=1,20
          write(6,*) "A warning was issued : please inspect!"
       enddo
     endif

end subroutine d_read_script
  
  subroutine d_execute_one_command(comti)
  implicit none
   character(*) comti
    logical :: ex=.false.
    call d_execute_multiple_command(comti,6,ex,0)
 end subroutine d_execute_one_command


  subroutine  d_execute_multiple_command(comti,mf,ex,ij)
  implicit none
character(*) comti
 CHARACTER*(120) comt,com
 CHARACTER*(255) filename
 logical skip,old,ex
 integer i,mf,i_layout_temp,posr,j,perm
  type(fibre), pointer :: p
integer, optional :: ij

i=0
if(present(ij) )i=ij
 comt=comti
 ex=.false.
 
      if(comt==" ") return !cycle
       COM=COMT
       call context(com)



       com=com(1:len_trim(com))
       if(index(com,'!')/=0) then
         if(index(com,'!')/=1) then
!          comt=com(1:index(com,'!')-1)
           com=comt
           com(index(com,'!'):120)=" "
!          COM=COMT
          call context(com)
         endif
       endif


       !! if(com(1:1)==' ') THEN    ! do not understand!
      !    WRITE(6,*) ' '
       !    cycle
       ! ENDIF
 
       if(com(1:1)=='!') THEN
          return !cycle
       ENDIF
       if(com(1:5)=='PAUSE') THEN
          com=com(1:5)
       ENDIF
       if(.not.skip) then
          if(com(1:2)=="/*") then
             skip=.true.
             return !cycle
          endif
       endif
       if(skip) then !1
          if(com(1:2)=="*/") then
             skip=.false.
          endif
          return !cycle
       endif         ! 1
       write(6,*) "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
       write(6,*) " "
       if(i==0) write(6,*) '            ',comT(1:LEN_TRIM(COMT))
       if(i/=0) write(6,*) '            ',i,comT(1:LEN_TRIM(COMT))
       write(6,*) " "
       write(6,*) "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
! start here

!$ The following variable and routines are public and can be used in the main program
!$
!@ \section{The public routines of the script}\label{app:pubrou}

!^  2

!@ \section{Command to initialize the code with a lattice}\label{app:initlat}
       select case(com)
       case('INITPTC','INITIALIZEPTC','INITIALIZE')
!$ This is initializes PTC and puts the d_u universe in m_u. 

           call ptc_ini_no_append
           d_u=>m_u
           call d_make_default
           if(.not.ptc_exist) then 
              call make_twiss_name
              call default_twiss 
          endif
           ptc_exist=.true.


       case('BMAD','BMADUNITS')
!$ Bmad units are used $(x,p_x,y,p_y,\beta (\delta )ct,d_p/dp_0 )$.
!n
!$ d_default=default0+time0 is consistent with above units and  it can be changed look at MAKEDEFAULT.
        call in_bmad_units()
        ntime=5
        ndelta=6
        compute_fix=.true. ;d_init_fpp_ptc=.true.;
        call make_twiss_name
        call default_twiss


       case('PTC','PTCUNITS')
!$ PTC units are used $(x,p_x,y,p_y,d_p/dp_0, ct )$
!n
!$ d_default=default0+time0 is consistent with above units and  it can be changed look at MAKEDEFAULT.
        call in_ptc_units()
        ntime=6
        ndelta=5
        if(ndpt_bmad==1) ntime=5
        compute_fix=.true. ;d_init_fpp_ptc=.true.;
        call make_twiss_name
        call default_twiss
!!!!!!!!!!!!!!    Read lattices and layouts !!!!!!!!!!!!!!!!!!!

       case('READFLAT','READNEWFLATFILE','READFLATFILE')
!$ Reads an ordinary isolated layout. You can read as many as you want.
!$ Complex structures require a diffferent command (not implemented yet).
!i  Input:  
!r  FILENAME


if(.not.ptc_exist)     then
       call ptc_ini_no_append
           d_u=>m_u
           ptc_exist=.true.
            call d_make_default 
            call make_twiss_name  
            call default_twiss
  
     
endif
          READ(MF,*) FILENAME
          call read_lattice_append(d_U,filename)
          d_line=>d_U%end
          WRITE(6,*) M_U%END%N, M_U%END%END%POS
          WRITE(6,*) "Flat file read"
 

         call d_even_line

       case('MAKEFULLARRAY')
!$ Turns the active layout into an array completely.
!$  All fibres are array entries of d_line\%a(:)
 
         d_ntot=d_line%n
         call reset_d_line_a
      !   call alloc_array_of_fibres(d_line%a,d_line%n)
          d_af=>d_line%a
         call fill_array_full 
         write(6,'(a55,1x,i4,a8)') " The associated array of fibres is the full line with ",d_ntot," entries"
         compute_fix=.true. ;d_init_fpp_ptc=.true.;
       case('MAKEARRAYOFN')
!$ Slices the layout into d_ntot slices, 
!$ Turns the active layout into an array of d_ntot entries.
!$  Thefore  d_line\%a(:) has d_ntot entries
!i  Input:  
!r  d_ntot  
         read(mf,*) d_ntot
         call reset_d_line_a
       
   !      call alloc_array_of_fibres(d_line%a,d_ntot)
        
         d_af=>d_line%a
         call fill_array_n 
         write(6,'(a26,1x,i4,a9)') " The associated array of fibres has",  d_ntot," sections"
         compute_fix=.true. ;d_init_fpp_ptc=.true.;
       case('MAKEARRAYOFS')
!$ Slices the layout into slices at "s" read from a file,.
!i  Input:  
!r  d_ntot  
         READ(MF,*) filename
         call select_s(filename)
!         call reset_d_line_a  inside select_s
               
         d_af=>d_line%a
!         call fill_array_n 
         !write(6,'(a26,1x,i4,a9)') " The associated array of fibres has",  d_ntot," sections"
         !compute_fix=.true. ;d_init_fpp_ptc=.true.;
!@ \section{Command to select a lattice and a position}\label{app:select}
       case('USEDATABASEUNIVERSE','M_U')
!$ Selects the data base universe m_u for tracking and uses d_u=>m_u.
!$ This is the default for simple structures.
!$  The layouts are stored in the linked list m_u starting at m_u\%start

        d_u=>m_u
       case('USETRACKINGUNIVERSE','M_T')
!$ Selects the tracking universe m_t for tracking and uses d_u=>m_t.
!$ This is the default for complex structures.
!$  The layouts are stored in the linked list m_y syarting at m_t\%start
!$  IGNORE THIS FOR THE MOMENT

        d_u=>m_t
       case('SELECTLAYOUT','SELECTLATTICE')
!$ Selects the active layout within d_u.
!$ This is 1 if you have only 1 lattice! Therefore d_layout is defaulted to 1.
!i  Input:  
!r  d_layout : position of the layout  

          read(mf,*) i_layout_temp
          if(i_layout_temp>d_u%n) then
             write(6,*) " Universe Size ", d_u%n

             write(6,*) " Selected Layout does not exist "
          else
             d_layout=i_layout_temp
             call move_to_layout_i(d_u,d_line,d_layout)
             write(6,*) "Selected Layout",d_layout,"  called  ---> ",d_line%name
          endif
compute_fix=.true. ; 
       case('POSITION','TRACKINGPOSITION')
!$ Reads into d_pos the tracking position in the array d_line\%a(:)
!i  Input:  
!r  d_pos
        read(mf,*) d_pos  
        write(6,*) " default position is now ",d_pos
        if(d_pos<1.or.d_pos>size(d_line%a)) then
          write(6,*) " Position does not exist  in array ",d_pos,size(d_line%a)
          stop 1000
        endif
        write(6,*) "Tracking at position",d_pos,"of array "
compute_fix=.true. ; 
!$ Makes permfringe =0,3 
!
!+  The code will skip if  different from 0 or 3

       case('PERMFRINGE')
    read(mf,*) perm
     if(perm==0.or.perm==3) then
      p=>d_line%start
      do j=1,d_line%n
       p%mag%p%permfringe=perm
       p%magp%p%permfringe=perm
       p=>p%next
      enddo
     else
      write(6,*) "permfringe = ",perm
      write(6,*) " command skipped "
     endif
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      case('CENTRE','FORCEMIDDLETRACKING')
!$ This tracks from the centre of the first fibre of a slice to the middle of the first fibre of the 
!$ next slice.   
!$ Normally the code tracks from the begin of the first fibre of a slice to 
!$ the end of the last fibre the slice.
!
!+  The code will stop if you do not use an even number of steps. (See MAKEEVEN just below)

       case('MAKEALLEVEN')
!$ Inforces that all the magnets have an even number of steps.
!$ This permits tracking to the middle of a magnet.
!$ It is better to do via the fancy code that produced the flat file if you are an expert of user of that code; 
!$ By fancy code, we mean some thing like BMAD or MAD-X. 

 
           call d_line_force_middle
       case('FRONT','IGNOREMIDDLETRACKING')
!$ Normally the code tracks from the begin of the first fibre of a slice to 
!$ the end of the last fibre the slice.
!$ It is restored by this command.

           call d_line_remove_middle
!!!!!!!!!!!!!!!!!!!!!! STATES !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!@ \section{The states of FPP-PTC}\label{app:states}
!$ These states determine the type of tracking and also
!$ as a consequence, the type of perturbative calculations one is allowed to do.
!n
!$ First we describe the ``default'' state of PTC.
!$ \begin{verbatim}
!$       TOTALPATH   =     0
!$       RADIATION   =  FALSE
!$       STOCHASTIC  =  FALSE
!$       ENVELOPE    =  FALSE
!$       NOCAVITY    =  FALSE
!$       TIME        =  FALSE
!$       PARA_IN     =  FALSE
!$       ONLY_2D     =  FALSE
!$       ONLY_4D     =  FALSE
!$       DELTA       =  FALSE
!$       SPIN        =  FALSE
!$       MODULATION  =  FALSE
!$       FRINGE      =  FALSE
!$\end{verbatim}
!n
!$ The default of the interface is called d_default. It is identical to the default of PTC 
!$ except that 
!$ \begin{verbatim}
!$       TIME        =  TRUE
!$\end{verbatim}
!$ This insures compatibility with BMAD.
!$ 
!$ The defaults of PTC are set intially by the following subroutine:
!^    1

!@ \subsection{The states that affect PTC and FPP}\label{app:statesptcfpp}


       case('MAKEDEFAULT')
!$ d_default = d_state
!$ the active state ``d_state''  becomes the new default.
           d_default=d_state
              compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);
         case('PRINTSTATE') 
!$ Print the current state : d_state
         call d_print_state(d_state);
       case('DEFAULT')
!$ d_state = d_defaut
!$ The active state is set to value default
          d_state=d_default
              compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);
       case('+NOCAVITY')
!$ Turns off RF 
          d_state=d_state+NOCAVITY0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);  
       case('-NOCAVITY')
!$ Turns on RF  
          d_state=d_state-NOCAVITY0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+ENVELOPE')
!$ Turns on quadratic moment stochastic  kick for electrons. 
          lielib_print(4)=0
          d_state=d_state+ENVELOPE0
           if(verbose ) call d_print_state(d_state);        
       case('-ENVELOPE')
!$ Removes quadratic moment stochastic.
          lielib_print(4)=lib4
          d_state=d_state-ENVELOPE0
           if(verbose ) call d_print_state(d_state);        
       case('+CAVITY')
!$ Turns on RF  
          d_state=d_state-NOCAVITY0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-CAVITY')
!$ Turns off RF  
          d_state=d_state+NOCAVITY0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+FRINGE')
!$ Turns on hard fringe in multipoles to order HIGHEST_FRINGE (defaulted to 2,i.e., quadrupoles).
          d_state=d_state+FRINGE0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-FRINGE')
!$ Turns off hard fringe in multipoles
          d_state=d_state-FRINGE0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+TIME')
!$ Uses $ct$ in PTC units and ${\beta }(\delta ) t$ if in BMAD units. 
          d_state=d_state+TIME0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-TIME')
!$ Uses path length $l$ if in PTC units. This is not a true 3-d-f variables if a cavity is present.  
          d_state=d_state-TIME0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+TOTALPATH')
!$ Uses the total time or pathlength 
          d_state=d_state+TOTALPATH0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-TOTALPATH')
!$ Uses the relative total time or pathlength 
          d_state=d_state-TOTALPATH0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+RADIATION')
!$ Turn on classical radiation 
          lielib_print(4)=0
          d_state=d_state+RADIATION0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-RADIATION')
!$ Turn off classical radiation 
          lielib_print(4)=lib4
          d_state=d_state-RADIATION0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+MODULATION')
!$ Turn on modulation of element strength
!$ This must have been set by user (later)
          d_state=d_state+MODULATION0
           if(verbose ) call d_print_state(d_state);        
       case('-MODULATION',"+NOMODULATION")
!$ Turn off modulation of element strength
          d_state=d_state-MODULATION0
          if(verbose ) call d_print_state(d_state);        
       case('+SPIN')
!$ Turn on spin tracking
          d_state=d_state+SPIN0
          if(verbose ) call d_print_state(d_state);        
       case('-SPIN')
!$ Turn off spin tracking
          d_state=d_state-SPIN0
          if(verbose ) call d_print_state(d_state); 
!@ \subsection{The states that affect FPP only}\label{app:statesptcfpp}

!$ For example a state like ``+ONLY_4d'' still tracks the longitutinal variables.
!$ However the Taylor map, if produced, is 4-dimentional.
!  Etienne that explantion sucks. Demin
       case('+ONLY_4D')
!$ Treats only the transverse phase space in a TPSA calculation
          d_state=d_state+ONLY_4D0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-ONLY_4D')
!$ Goes back to 6 dimensions in TPSA calculations.
          d_state=d_state-ONLY_4D0
       case('+ONLY_2D')
!$ Goes back to 2 dimensions in TPSA calculations.
          d_state=d_state+ONLY_2D0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);  
!$ Goes back to 6 dimensions in TPSA calculations.      
       case('-ONLY_2D')
          d_state=d_state-ONLY_2D0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('+DELTA')
!$ Treats  the transverse phase space in a TPSA calculation and $\delta p/p_0$ as a parameter. 
          d_state=d_state+DELTA0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        
       case('-DELTA')
!$  $\delta p/p_0$ as a parameter is removed. Phase space becomes transverse only in TPSA
          d_state=d_state-DELTA0
          compute_fix=.true. ;d_init_fpp_ptc=.true.;if(verbose ) call d_print_state(d_state);        

!!!!!!!!!!!!!!!!!!!!!!  FPP  Stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!
!@ \section{Command to setting up FPP}\label{app:fppc}
       case('INITFPP','INIT')
!$ This allows you to initialize FPP within PTC by yourself
!$ It is often not necessary in this interface.
!$ By default the tpsa order is 1 and the number of ``knobs'' is 0.
!$ The rest is decided by the internal states.
         call d_init
       case('NO','ORDEROFTPSA')
!$ Reads the order of TPSA
!i Input:
!r d_no

         read(mf,*) d_no
         d_init_fpp_ptc=.true.
       case('NP','NUMBEROFKNOBS')
!$ Reads the number of TPSA KNOBS
!i Input:
!r d_np
       case('NUMBEROFTAYLOR','NUMBEROFPOLYNOMIALS')
!$ Reads the number of TPSA  in complex package
!i Input:
!r c_lda_used
         read(mf,*) c_lda_used
write(6,*) c_lda_used," complex Taylors used in Berz Package"
         d_init_fpp_ptc=.true.
       case('DELTA')
!$ Reads $\delta p/p_0$ (BMAD units) or $\delta E/(p_0c)$ (PTC units).
!+ Important for state where energy is a constant. 
!i Input:
!r d_delta
        read(mf,*) d_delta
!@ \section{Computations of Linear Lattice Functions}\label{app:states}
       case('USUALTWISSNAME')
!$ See lectures.  
!$ By default all the lattice functions are defined in dependence of averages
!$ over the invariants.  For example
!%
!%]|Expr|[#b @`b___})%# b'4" Helvetica|: ;bP8&c0!*,D$^"!Symbol^:!&c0  b|
!%|^""*|:"&c0!*x_,]<2(":!&c0  .V<c!,Q^$^:"&c0!*x_^2}}(":!&c0  .V|
!%|$^:"&c0!*J^1_}}: ,D}& b!( b"0 b#8 b$@ b%H b&P!WW}]|[
!$ ${\beta }_{x}={\partial \left\langle{{x}^{2}}\right\rangle \over \partial {J}_{1}}$
!$ and
!%
!%]|Expr|[#b @`b___})%# b'4" Helvetica|: ;bP8&c0!*,D$^"!Symbol^:!&c0  h|
!%|^""*|:"&c0!*x_,]<2(":!&c0  .V$^<c!,Q^:"&c0!*x}^3_}(":!&c0  .V|
!%|d}}: &c0!*,D}& b!( b"0 b#8 b$@ b%H b&P!WW}]|[
!$ ${\eta }_{x}={\partial {\left\langle{x}\right\rangle}_{3} \over \partial \delta }$.
!$ where the average for $\eta $ is only performed over the third phase.
!$ Compare the names of the lattice functions with 'GENERALTWISSNAME'
!$ \begin{verbatim}
!$ s         betax        alphax       <z2*z4>_1    D_11         zeta_1       eta_1
!$ 6.75      3.258960     1.810617     0.482275     0.633222     0.000015     0.237071
!$10.10      2.845463     2.194714    -1.413402     1.660329    -0.000016     0.215641
!$12.68      5.329811    -4.397931     1.331260     3.692280    -0.000001     0.012232
!$ \end{verbatim}
!$ Here $\zeta $ is a lattice function first introduced by Ohmi, Hirata and Oide. It is a
!$ dipersion with respect of time. (longitudinal phase).
!$ Here $D_{11} $  measures the coupling between the $x$ and $y$ plane. It is reminiscent of 
!$ a lattice function due to Teng and Edwards.
!$ <z2*z4>_1 has no special name and thus the general name is kept.
         common_twiss_name=.true.
         call make_twiss_name
       case('GENERALTWISSNAME')
!$ See lectures.  
!$ By default all the lattice functions are defined in dependence of averages
!$ over the invariants.  
!$ Compare the names of the lattice functions with 'USUALTWISSNAME'
!$ {\bf  Notice that ${\alpha }_{x}$  changed sign: ${\alpha }_{x}=
!$ -{\partial \left\langle{x{p}_{x}}\right\rangle \over \partial {J}_{1}} $ }
!$ \begin{verbatim}
!$ s         <z1*z1>_1    <z1*z2>_1    <z2*z4>_1    <z1>_1/z3    <z1>_3/z5    <z1>_3/z6
!$ 6.75      3.258960    -1.810617     0.482275     0.633222     0.000015     0.237071
!$10.10      2.845463    -2.194714    -1.413402     1.660329    -0.000016     0.215641
!$12.68      5.329811     4.397931     1.331260     3.692280    -0.000001     0.012232
!$ \end{verbatim}




         common_twiss_name=.false.
         call make_twiss_name

       case('DPCOD','DEFAULTPOSITIONCLOSEDORBIT')
!$ Computes the closed orbit in d_state at d_pos in the array for d_delta
            call d_compute_closed()
       case('CLOSEDORBIT','FINDCLOSEDORBIT')
          read(mf,*) posr,deltar
         if(posr>0.and.posr<=size(d_line%a)) then
            call d_compute_closed(posr,deltar)
         else
            call d_compute_closed()
         endif

       case('FILLCLOSEDORBIT')
          if(compute_fix) call d_compute_closed()
          call d_trackfill
         case('TWISS','LATTICEFUNCTIONS')
!$ Computes the lattice functions related to the de Moivre representation
!$ The names are describe in \app{app:states}.
!$ They are defined as follows. 
!$ {\bf If }
 
!$ {\bf then }
 

         call twiss_1()
         case('SELECTTWISS','SELECTLATTICEFUNCTIONS')
         READ(MF,*) filename
         call select_twiss(filename)
         call set_title_line_twiss
         case('PRINTTWISS','PRINTLATTICEFUNCTIONS')
!$ Prints lattice functions
!i Input:
!r  frequency to print the tile 
!$
!$  number of lines you skip before printing
!$
!r   filename   
!$
!$  If the filename is ``screen'' or ``terminal'', then the output
!$  is the terminal. (unit 6 in fortran)
           read(mf,*) print_title
           read(mf,*) filename
         CALL print_twiss(filename)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       case('RETURN')
          goto 100
       case('STOP')
          CALL PTC_END()
          stop
       case('ENDPTC')
          CALL PTC_END()
           ptc_exist=.false.
          goto 100

         case('A1IM01A0')
         read(mf,*) prec
         CALL twiss_no(prec)
         case('UNIVERSALA1IM01A0','A1IM01A0NOMAP')
         read(mf,*) prec
         CALL twiss_no_map(prec)

       case default
        write(6,*) com
        write(6,*) "not recognized "
        stop 476
      end select
! end here
    return
   100   ex=.true.
   return

   end subroutine d_execute_multiple_command

!#   1    First routine saved for TeX
   subroutine  d_make_default
   implicit none
      d_default=default0+time0
      d_state=d_default
     force_spin_input_normal=.true.
      call in_bmad_units()
       n_cai=-i_
       ntime=5
       ndelta=6
      use_quaternion=.true.
      use_radiation_inverse=.true.
      common_twiss_name=.true.
  end  subroutine  d_make_default
!##
   subroutine print_for_tex 
    implicit none
    character(255) filename
    integer mf,mfo,ind
    character*(132) line,line1,label
    logical :: printf = .false.
    logical :: store = .false.
    integer c,n,i
    integer i1,i2
    call kanalnummer(mf)
   !  open(unit=mf,file="C:\document\basic\demin_read\Sw_demin_command.f90",status='OLD',READONLY)
     open(unit=mf,file="C:\document\basic\demin_read\Sw_demin_command.f90")   
c=0
n=0
store=.false.
    do while (.true.)     
     read(mf,('(a132)'),end=100) line
     if(store) then
      if(line(1:3)/="!##") then
       if(line(1:4)=="!tex") then
            line1=" "
           line1(1:19) =  "{\textcolor{w}{    "
 if(19+len_trim(line(5:132))+1>132) stop 888
           line1(20:19+len_trim(line(5:132)))=line(5:132)
 

           line1(len_trim(line1)+1:len_trim(line1)+2)="}}"
 
           line=line1
       lprogram(n,c)=line
       elseif(line(1:1)/="!") then
        lprogram(n,c)(1:14)="\hskip 1.0 cm }"
        lprogram(n,c)(15:132) =line(1:132-15+1)
       else
              lprogram(n,c)=line
       endif

        iprog(n)=c
        c=c+1
       else
        n=n-1
       endif

      endif ! store

     if(line(1:3)=="!# ") then
      store=.true.
      read(line(4:132),*) n
      c=1
     endif 

     if(line(1:3)=="!##") then
      store=.false.
      c=0
     endif 

     if(c>clprogram) stop 200
     if(n>nlprogram) stop 201
      enddo
100 rewind mf
  
    call kanalnummer(mfo,"C:\document\basic\demin_read\summary_command.f90")


  write(mfo,'(a)') "{\small  "
    do while (.true.)
     read(mf,('(a132)'),end=101) line
 
     line1=line
     call context(line1)
     
     if(line1(1:10)=="!STARTHERE") printf=.true.

     if(line1(1:8)=="!ENDHERE") printf=.false.

     if(line(1:2)=="!$") then
         line(1:2)= " "
         write(mfo,'(a132)') line
     endif 
     if(line(1:2)=="!N") then
         write(mfo,*) " "
     endif 

     if(line(1:2)=="!@") then
         line(1:2)= " "
         write(mfo,'(a132)') line
     endif  
     if(line(1:2)=="!R") then
         line(1:2)= " "
         line1(1:39) =  "{\large \textcolor{q}{    \hskip 1.0 cm "
 
         line1(40:39+len_trim(line)) = line(1:len_trim(line))
 
         line1(1+len_trim(line1):2+len_trim(line1))="}}"
         write(mfo,'(a132)') line1
         write(mfo,*) " "
     endif 
     if(line(1:2)=="!+") then
         line(1:2)= " "
         line1(1:33) =  "{\textcolor{w}{\bf \hskip 0.0 cm "
 
         line1(34:33+len_trim(line)) = line(1:len_trim(line))
 
         line1(1+len_trim(line1):2+len_trim(line1))="}}"
         write(mfo,'(a132)') line1
         write(mfo,*) " "
     endif   
     if(line(1:2)=="!?") then
         line(1:2)= " "
         line1(1:39) =  "{\large \textcolor{d}{\bf \hskip 1.0cm "
 
         line1(40:39+len_trim(line)) = line(1:len_trim(line))
 
         line1(1+len_trim(line1):2+len_trim(line1))="}}"
         write(mfo,'(a132)') line1
         write(mfo,*) " "
     endif  
     if(line(1:2)=="!I") then
        write(mfo,*) " "
         line(1:2)= " "
         line1(1:27) =  "{\normalsize \textcolor{p}{"
 
         line1(28:27+len_trim(line1)) = line(1:len_trim(line1))
 
         line1(1+len_trim(line1):2+len_trim(line1))="}}"
         write(mfo,'(a132)') line1
         write(mfo,*) " "
     endif 
!   lprogram(nlprogram,clprogram,132) 
       if(line(1:2)=="!^") then   
!write(mfo,'(a132)') " \begin{verbatim} "
 !write(6,'(a132)')  line1 
 !write(6,'(a132)')  line  
         read(line(3:132),*)  n
         c=0
         do i=1,iprog(n)
          c=c+1
!           write(6,'(a132)')  lprogram(n,c) 
           write(mfo,'(a132)') lprogram(n,c)
             write(mfo,'(a132)')
         enddo
!write(mfo,'(a132)') " \end{verbatim} "
        endif  
    if(printf)  then
 
      ind=index(line1,"CASE(")
      if(ind/=0.and.index(line1,"SELECTCASE(COM)")==0) then
         write(mfo,*) " "
         line1(ind:ind+4)=" "
        ind=index(line1,")")
        line1(ind:ind)=" "
        call context(line1)
        i1=index(line1,"'")+1
        i2=index(line1(i1:132),"'")
 
        label=' '
        label(1:9)="\label{c:"
        label(9+1:10+i2-i1)=line1(i1:i2) 
        label(11+i2-i1:11+i2-i1)="}"
        call contextlc(label)
 
        line=" "
         line(1:46) =  "{\normalsize \textcolor{h}{\begin{equation}\rm"
 
         line(47:46+len_trim(line1)) = line1(1:len_trim(line1))
           line(1+len_trim(line):11+i2-i1+len_trim(line)+1)=label(1:11+i2-i1)
        
         line(1+len_trim(line):16+len_trim(line))="\end{equation}}}"
            call underscore(line,1)
         write(mfo,'(a132)') line
         write(mfo,*) " "
      endif
    endif

    enddo
101  continue
  write(mfo,'(a)') "}"
    close(mf)
    close(mfo)
 
    end subroutine print_for_tex

    subroutine underscore(line,j)
!    removes j underscores
    implicit none
    integer i1,i2,j,k
    character(255) line1
    character(*) line

    line1= " "
            line1(1:len_trim(line))=line(1:len_trim(line))
            line=" "
              i2=1
               k=0
             do i1=1,len_trim(line1)
               if(line1(i1:i1)=="_".and.k<j) then
                  line(i2:i2+1)="\_"
                   i2=i2+2
                   k=k+1
                 else
                 line(i2:i2)=line1(i1:i1)
                  i2=i2+1
               endif
             enddo
    end subroutine underscore

  subroutine d_print_state(S,MFr)
    implicit none
    type (INTERNAL_STATE) S
    INTEGER,optional :: MFr
    integer mf
    mf=6
    if(present(mfr)) mf=mfr
    if(S%TOTALPATH<0) then
      write(6,*) "state not set "
      return
    endif
    write(mf, '((1X,a20,1x,i4))' )"      TOTALPATH   = ", S%TOTALPATH
    write(mf,'((1X,a20,1x,a5))' ) "      RADIATION   = ", CONV(S%RADIATION  )
    write(mf,'((1X,a20,1x,a5))' ) "      STOCHASTIC  = ", CONV(S%STOCHASTIC  )
    write(mf,'((1X,a20,1x,a5))' ) "      ENVELOPE    = ", CONV(S%ENVELOPE  )
    write(mf,'((1X,a20,1x,a5))' ) "      NOCAVITY    = ", CONV(S%NOCAVITY )
    write(mf,'((1X,a20,1x,a5))' ) "      TIME        = ", CONV(S%TIME )

    write(mf,'((1X,a20,1x,a5))' ) "      PARA_IN     = ", CONV(S%PARA_IN  )
    write(mf,'((1X,a20,1x,a5))' ) "      ONLY_2D     = ", CONV(S%ONLY_2D   )
    write(mf,'((1X,a20,1x,a5))' ) "      ONLY_4D     = ", CONV(S%ONLY_4D   )
    write(mf,'((1X,a20,1x,a5))' ) "      DELTA       = ", CONV(S%DELTA    )
    write(mf,'((1X,a20,1x,a5))' ) "      SPIN        = ", CONV(S%SPIN    )
    write(mf,'((1X,a20,1x,a5))' ) "      MODULATION  = ", CONV(S%MODULATION    )
    write(mf,'((1X,a20,1x,a5))' ) "      FRINGE      = ", CONV(S%FRINGE   )
 
  end subroutine d_print_state

  FUNCTION CONV(LOG)
    IMPLICIT NONE
    CHARACTER(5) CONV
    logical(lp) LOG
    CONV="FALSE"
    IF(LOG) CONV="TRUE "
  END FUNCTION CONV

  subroutine reset_d_line_a
  implicit none
         if(associated(d_line%a))call kill_array_of_fibres(d_line%a)
         if(associated(d_line%lf0)) call kill_d_lattice_functions(d_line%lf0)
         
         allocate(d_line%lf0)
         call zero_d_lattice_function(d_line%lf0)
         call alloc_array_of_fibres(d_line%a,d_ntot)

  end subroutine reset_d_line_a

!!!!!!!!!!!!! alloc, kill, allocate, deallocate for m in d_line
  subroutine allocate_m_array_full
!!!! only good for closed structures 
  implicit none
   integer i
 
       allocate(d_line%lf0%m)

    do i=1,size(d_line%a)
       allocate(d_line%a(i)%lf%m)
   enddo
   
  end   subroutine allocate_m_array_full

  subroutine alloc_m_array_full
!!!! only good for closed structures 
  implicit none
   integer i
 

      call alloc(d_line%lf0%m)
    do i=1,size(d_line%a)
      call alloc(d_line%a(i)%lf%m)
   enddo
   
  end   subroutine alloc_m_array_full

  subroutine deallocate_m_array_full 
  implicit none
   integer i
 
      deallocate(d_line%lf0%m)

    do i=1,size(d_line%a)
      deallocate(d_line%a(i)%lf%m)
   enddo
   
  end   subroutine deallocate_m_array_full

  subroutine kill_m_array_full 
  implicit none
   integer i
      call kill(d_line%lf0%m)

    do i=1,size(d_line%a)
      call kill(d_line%a(i)%lf%m)
   enddo
   
  end   subroutine kill_m_array_full


subroutine select_s(filename)
implicit none
character(*) filename
 integer mfi,i,n,count_change
 real(dp) dl
 real(dp), allocatable :: s(:)

 call kanalnummer(mfi,filename)
   read(mfi,*) n,dl
allocate(s(n))

  do i=1,n
    read(mfi,*) s(i)
  enddo

  write(6,*) s
d_ntot=n

call reset_d_line_a

  close(mfi)
call fill_array_s(s,dl)

deallocate(s)

end subroutine select_s

  subroutine fill_array_full
!!!! only good for closed structures 
  implicit none
   integer i
   fib=>d_line%start


    do i=1,d_line%n
     d_line%a(i)%fib1=>fib
     d_line%a(i)%fib2=>fib
    fib=>fib%next
   enddo
   
  end   subroutine fill_array_full


  subroutine fill_array_n
!!!! only good for closed structures 
  implicit none
   integer i,j,fib_per,count

   fib=>d_line%start
    
    fib_per=d_line%n/d_ntot

    
count=0
    do i=1,d_ntot
      d_line%a(i)%fib1=>fib
     do j=1,fib_per
 !     d_line%a(i)%fib1=>fib
      count=count+1
      d_line%a(i)%fib2=>fib
     fib=>fib%next
    enddo
   enddo
    j= count     
   do i=j+1,d_line%n
      d_line%a(d_ntot)%fib2=>fib  
     count=count+1  
     fib=>fib%next
   enddo

! write(6,*) count,d_line%n,d_line%a(d_ntot)%fib2%pos
! pause 6
 
   if(count>d_line%n) then
     write(6,*) "Error in fill_array_n"
     stop 667
   endif

  end   subroutine fill_array_n

  subroutine fill_array_s(s,dl)
!!!! only good for closed structures 
  implicit none
   integer i,j,count
   real(dp)  s(:),dl
  
 
   fib=>d_line%start
   count=1   
   do i=1,2*d_line%n
     if(abs(fib%t1%s(1)-s(count))<=dl) then
       d_line%a(count)%fib1=>fib
       write(6,*) fib%t1%s(1),s(count)
       if(count==size(s)) exit
       count=count+1
     endif
    fib=>fib%next
   enddo 
    d_fib=>d_line%a(1)%fib1 

   do i=1,size(s)-1
    d_line%a(i)%fib2=>d_line%a(i+1)%fib1%previous
   enddo
    d_line%a(count)%fib2=>d_line%a(1)%fib1%previous

   !do i=1,count
   ! write(6,*) d_line%a(i)%fib1%t1%s(1)
   ! write(6,*) d_line%a(i)%fib2%t2%s(1)
   !enddo

   if(count>size(s)) then
     write(6,*) "Error in fill_array_s"
     stop 667
   endif

  end   subroutine fill_array_s

  subroutine d_track_array(xs0,i,di)
!!!! only good for closed structures 
  implicit none
  type(probe), intent(inout):: xs0
  integer i,di,k,j1,j2,ms
  type(fibre),pointer :: p

   if(di==0) return
   do k=i,i+di-1
    j1=d_mod(k,size(d_line%a))
    j2=d_mod(k+1,size(d_line%a))
       p=>d_line%a(j1)%fib1
       ms=d_line%a(j1)%centre+2*d_line%a(j2)%centre
      select case(ms)
       case(0)
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs0,d_state,fibre1=p,fibre2=p%next)
       p=>p%next
      enddo
       case(1)
       call propagate(xs0,d_state,node1=p%tm,fibre2=p%next)
        p=>p%next
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs0,d_state,fibre1=p,fibre2=p%next)
       p=>p%next
      enddo
       case(2)
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs0,d_state,fibre1=p,fibre2=p%next)
       p=>p%next
      enddo
       call propagate(xs0,d_state,fibre1=p,node2=p%tm)
       case(3)
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs0,d_state,node1=p%tm,node2=p%next%tm)
       p=>p%next
      enddo
      case default
        stop 500
     end select
   enddo
  end   subroutine d_track_array

  
  subroutine d_track_array_8(xs,i,di)
!!!! only good for closed structures 
  implicit none
  type(probe_8), intent(inout):: xs
  integer i,di,k,j1,j2,ms
  type(fibre),pointer :: p

   if(di==0) return

 
   do k=i,i+di-1
    j1=d_mod(k,size(d_line%a))
    j2=d_mod(k+1,size(d_line%a))
       p=>d_line%a(j1)%fib1
       ms=d_line%a(j1)%centre+2*d_line%a(j2)%centre
   if(ms/=0) stop 999
      select case(ms)
       case(0)
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs,d_state,fibre1=p,fibre2=p%next)
       p=>p%next
      enddo
       case(1)
       call propagate(xs,d_state,node1=p%tm,fibre2=p%next)
        p=>p%next
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs,d_state,fibre1=p,fibre2=p%next)
       p=>p%next
      enddo
       case(2)
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs,d_state,fibre1=p,fibre2=p%next)
       p=>p%next
      enddo
       call propagate(xs,d_state,fibre1=p,node2=p%tm)
       case(3)
      do while(.not.associated(p,d_line%a(j2)%fib1)) 
       call propagate(xs,d_state,node1=p%tm,node2=p%next%tm)
       p=>p%next
      enddo
      case default
        stop 501
     end select
      if(xs%u) exit
   enddo
    if(xs%u) then

      write(6,*) "0 unstable in d_track_array_8"
      call print(xs)
      write(6,*) "1 unstable in d_track_array_8"

    endif
  end   subroutine d_track_array_8


  integer function d_mod(i,n)
  implicit none
  integer i,n
  d_mod=mod(i,n) 
  if(d_mod==0) d_mod=n
  

  end  function d_mod

subroutine d_compute_closed(pos,delta)
implicit none
integer, optional :: pos
real(dp), optional :: delta
real(dp) closed_orbit(6)
type(fibre), pointer :: p

if(present(pos)) then
          if(d_state%nocavity) then
            write(6,*) " closed orbit at  ", posr, " and delta =",delta 
          else
            write(6,*) " closed orbit at  ", posr 
          endif
          closed_orbit=0
          closed_orbit(5+ndpt_bmad)=delta
          p=>d_line%a(pos)%fib1
          call FIND_ORBIT_x(closed_orbit,d_STATE,epsc,fibre1=p)
          write(6,formatdl6) closed_orbit
          d_probe_b=closed_orbit 
          call propagate(d_probe_b,d_STATE,fibre1=p,fibre2=p)
          write(6,*) "Checking closed orbit "
          write(6,formatdl6) d_probe_b%x
else
          if(d_state%nocavity) then
            write(6,*) " closed orbit at d_pos = ", d_pos, " and d_delta =",d_delta 
          else
            write(6,*) " closed orbit at  ", d_pos 
          endif
          d_closed_orbit=0
          d_closed_orbit(5+ndpt_bmad)=d_delta
          d_fib=>d_line%a(d_pos)%fib1
          call FIND_ORBIT_x(d_closed_orbit,d_STATE,epsc,fibre1=d_fib)
          write(6,formatdl6) d_closed_orbit
          d_probe_b=d_closed_orbit 
          call propagate(d_probe_b,d_STATE,fibre1=d_fib,fibre2=d_fib)
          write(6,*) "Checking closed orbit "
          write(6,formatdl6) d_probe_b%x
          compute_fix=.false. ;
endif
  end   subroutine d_compute_closed

subroutine d_trackfill()
implicit none
integer k,j1

d_probe_a=d_closed_orbit
do k=d_pos,size(d_line%a)+d_pos-1
    j1=d_mod(k,size(d_line%a))
     d_line%a(j1)%lf%fixa=d_probe_a%x
   if(d_state%nocavity)  d_probe_a%x(ntime)=0 
    d_line%a(j1)%lf%fixa=d_probe_a%x
    d_probe_a=d_probe_b
    call d_track_array(d_probe_b,j1,1)
    d_line%a(j1)%lf%fixb=0
    d_line%a(j1)%lf%fixb=d_probe_b%x
enddo

end subroutine d_trackfill


subroutine twiss_1()
implicit none
integer k,j1,je(6),kk,jnext
type(c_damap) id,c_map,u_c,a_cs
real(dp) mat(6,6),sp1,sigmas0(6,6)
type(c_linear_map) d_q_cs,d_q_as,d_q_rot,d_q_orb 
type(c_taylor) sp 
type(taylor) tt 
type(c_normal_form) normal_form
type(probe_8) d_probe_8


if(compute_fix) call d_compute_closed()
 
 if(d_init_fpp_ptc) call d_init()
  d_init_fpp_ptc=.false.
 
  call alloc(normal_form)

call alloc(id,c_map,u_c,a_cs)
call alloc(sp)
call alloc(tt)
call alloc(d_probe_8)

call d_compute_closed(d_pos,d_delta)

id=1
d_probe_a=d_closed_orbit
d_probe_8=d_probe_a + id

!write(6,*) " one-turn "
call d_track_array_8(d_probe_8,d_pos,d_ntot)
    if(d_probe_8%u) then
      write(6,*) "unstable in d_track_array_8 computing one-turn map"
        call kill(sp)
        call kill(tt)
        call kill(id,c_map,u_c)
        return
    endif
 c_map=d_probe_8


call c_normal(c_map,normal_form,dospin=d_state%spin,nu_spin=sp)

je=0; je(ndelta)=1;
sp1=sp.sub.je
 
     call c_fast_canonise(normal_form%atot,a_cs,dospin=d_state%spin)

d_spin_tune=0
d_damping=0
d_phase=0
     call d_compute_lattice_functions(a_cs,d_line%lf0,a_l=d_line%lf0%a0,a_li=d_line%lf0%a1i)
     d_line%lf0%A0=a_cs
     d_line%lf0%A1i=a_cs**(-1)

       d_line%lf0%phase=d_phase
      d_line%lf0%damping=d_damping
      d_line%lf0%spin=d_spin_tune
      d_line%lf0%fixa=d_probe_a%x
      d_line%lf0%fixb=d_probe_a%x
    if(d_state%envelope) d_line%lf0%sigmas=real(normal_form%s_ij0)
 

d_probe_8=d_probe_a +  a_cs


!  write(6,*) " one-element at a time "
do k=d_pos,d_pos+d_ntot-1
    jnext=d_mod(k+1,d_ntot)
    j1=d_mod(k,d_ntot)
 
    d_probe_a=d_probe_8
   if(d_state%nocavity)  d_probe_a%x(ntime)=0 

    call d_track_array_8(d_probe_8,j1,1)


    if(d_probe_8%u) then
      write(6,*) "unstable in d_track_array_8 at pos ",k,"doing Twiss"
        call kill(sp)
        call kill(tt)
        call kill(id,c_map,u_c)
        return
    endif
    c_map=d_probe_8
    d_probe_b=d_probe_8
    call c_fast_canonise(c_map,a_cs,d_phase,d_damping,d_q_cs,d_q_as,d_q_orb,d_q_rot,d_spin_tune,dospin=d_state%spin)
  !a_cs=c_map
    call d_compute_lattice_functions(a_cs,d_line%a(j1)%lf,a_l=d_line%a(jnext)%lf%a0,a_li=d_line%a(j1)%lf%a1i)
      d_line%a(j1)%lf%phase=d_phase
      d_line%a(j1)%lf%damping=d_damping
      d_line%a(j1)%lf%spin=d_spin_tune
      d_line%a(j1)%lf%fixa=d_probe_a%x
      d_line%a(j1)%lf%fixb=d_probe_a%x
      d_probe_8 = a_cs + d_probe_b 
  enddo
 


if(d_state%envelope) then
d_line%lf0%sigmas=normal_form%s_ij0
d_line%lf0%emittance=normal_form%emittance
 
id=1
d_probe_a=d_closed_orbit
d_probe_8=d_probe_a + id
 
do k=d_pos,d_ntot+d_pos-1
    j1=d_mod(k,d_ntot)
    call d_track_array_8(d_probe_8,j1,1)
    d_line%a(j1)%lf%sigmas=d_line%lf0%sigmas+d_probe_8%E_ij
    id=d_probe_8
    mat=id
    d_line%a(j1)%lf%sigmas=matmul(matmul(mat,d_line%a(j1)%lf%sigmas),transpose(mat))
enddo
endif 


!   write(6,*) " done"

write(6,*) " Fractional part from Normal Form on the one-turn map"
write(6,"(a8,3(1x,g23.16,1x))") "orbital ", normal_form%tune(1:3)
if(d_state%radiation) write(6,"(a8,3(1x,g23.16,1x))") "damping ",  normal_form%damping(1:3)
if(d_state%spin) write(6,"(a24,2(1x,g23.16,1x))") " spin and chromaticity  ",normal_form%spin_tune,sp1
if(d_state%envelope) then
    write(6,*) " Beam sizes "
    write(6,"( 6(1x,g23.16,1x))") real(normal_form%s_ij0(1,1:6))
    write(6,"( (25x),5(1x,g23.16,1x))")  real(normal_form%s_ij0(2,2:6))
    write(6,"( 2(25x),4(1x,g23.16,1x))") real(normal_form%s_ij0(3,3:6))
    write(6,"( 3(25x),3(1x,g23.16,1x))") real(normal_form%s_ij0(4,4:6))
    write(6,"( 4(25x),2(1x,g23.16,1x))") real(normal_form%s_ij0(5,5:6))
    write(6,"( 5(25x),1(1x,g23.16,1x))") real(normal_form%s_ij0(6,6:6))
endif

write(6,*) " Using phase advances"
k=d_mod(d_pos,d_ntot)-1
if(k==0) k=d_ntot
write(6,"(a8,3(1x,g23.16,1x))") "orbital ",d_line%a(k)%lf%phase 
if(d_state%radiation) write(6,"(a8,3(1x,g23.16,1x))") "damping ",  d_line%a(k)%lf%damping 
if(d_state%spin) write(6,"(a24,2(1x,g23.16,1x))") " spin and chromaticity  ", d_line%a(k)%lf%spin
mat=d_line%a(d_ntot)%lf%sigmas
if(d_state%envelope) then
    write(6,*) " Beam sizes propagated"
    write(6,"( 6(1x,g23.16,1x))")  mat(1,1:6) 
    write(6,"( (25x),5(1x,g23.16,1x))")   mat(2,2:6) 
    write(6,"( 2(25x),4(1x,g23.16,1x))")  mat(3,3:6) 
    write(6,"( 3(25x),3(1x,g23.16,1x))")  mat(4,4:6) 
    write(6,"( 4(25x),2(1x,g23.16,1x))")  mat(5,5:6) 
    write(6,"( 5(25x),1(1x,g23.16,1x))")  mat(6,6:6) 
endif
 
 call kill(sp)
 call kill(tt)
 call kill(id,c_map,u_c,a_cs)
 call kill(normal_form)
 call kill(d_probe_8)

end subroutine twiss_1

 

subroutine twiss_no(prec)
implicit none
integer k,j1
type(c_damap) id,c_map,u_c,a_cs
type(probe_8) d_probe_8
real(dp) prec,norm
logical did_twiss

!if(compute_fix) call d_compute_closed()

 did_twiss=.true.
 norm=0
 do j1=1,2
 do k=1,2
  norm=abs(d_line%lf0%a0%mat(j1,k))+norm
 enddo
 enddo
if(norm==2.0_dp) then 
did_twiss=.false.
warning=.true.
write(6,*) "Maybe you forgot a twiss : suspicious"
endif
 if(d_init_fpp_ptc) call d_init()
 if(.not.associated(d_line%lf0%m)) then
  call allocate_m_array_full
  call alloc_m_array_full
endif
  d_init_fpp_ptc=.false.

call alloc(id,c_map,a_cs)
call alloc(d_probe_8)

!call d_compute_closed(d_pos,d_delta)
d_closed_orbit=d_line%a(d_pos)%lf%fixa
id=1
d_probe_a=d_closed_orbit
d_probe_8=d_probe_a + id

     d_line%lf0%m=1


!  write(6,*) " one-element at a time "
do k=d_pos,d_pos+d_ntot-1
     j1=d_mod(k,d_ntot)
 
    d_probe_a=d_probe_8
 
 
    call d_track_array_8(d_probe_8,j1,1)


 
 
    c_map=d_probe_8

    a_cs=d_line%a(j1)%lf%a0
    c_map=c_map*a_cs
    a_cs=d_line%a(j1)%lf%a1i
    c_map=a_cs*c_map
    c_map=ci_phasor()*c_map*c_phasor()
 
call clean(c_map,c_map,prec)
 
    d_line%a(j1)%lf%m=c_map
    d_line%lf0%m= c_map*d_line%lf0%m
    d_probe_b=d_probe_8
       d_probe_8 = id + d_probe_b 
  enddo



 call kill(id,c_map,a_cs)
 call kill(d_probe_8)
if(.not.did_twiss) write(6,*) "Maybe you forgot a twiss : suspicious"

end subroutine twiss_no


subroutine twiss_no_map(prec)
implicit none
integer k,j1
type(c_damap) id,c_map,u_c,a_cs,d_linelf0m,L
type(probe_8) d_probe_8
real(dp) prec,norm
type(c_vector_field) vf
!if(compute_fix) call d_compute_closed()
!type(universal_taylor), pointer :: re,im
type(c_universal_taylor), pointer :: ut
logical did_twiss


  did_twiss=.true.
 norm=0
 do j1=1,2
 do k=1,2
  norm=abs(d_line%lf0%a0%mat(j1,k))+norm
 enddo
 enddo
if(norm==2.0_dp) then 
did_twiss=.false.
write(6,*) "Maybe you forgot a twiss : suspicious"
warning=.true.
endif
 if(d_init_fpp_ptc) call d_init()

  d_init_fpp_ptc=.false.

call alloc(id,c_map,a_cs,d_linelf0m,L)
call alloc(d_probe_8)
call alloc(vf)

!call d_compute_closed(d_pos,d_delta)
d_closed_orbit=d_line%a(d_pos)%lf%fixa
id=1
d_probe_a=d_closed_orbit
d_probe_8=d_probe_a + id

     d_linelf0m=1


!  write(6,*) " one-element at a time "
do k=d_pos,d_pos+d_ntot-1
     j1=d_mod(k,d_ntot)
 
    d_probe_a=d_probe_8
 

 
    call d_track_array_8(d_probe_8,j1,1)
 
 

 
    c_map=d_probe_8

    a_cs=d_line%a(j1)%lf%a0
    c_map=c_map*a_cs
    a_cs=d_line%a(j1)%lf%a1i
    c_map=a_cs*c_map
    c_map=ci_phasor()*c_map*c_phasor()

call clean(c_map,c_map,prec)

 
 call c_factor_map(c_map,L,vf,1)  
 
 

 if(associated(d_line%a(j1)%lf%ut)) then
   call kill(d_line%a(j1)%lf%ut)
 endif
 
 allocate(d_line%a(j1)%lf%ut)
 
 ut=>d_line%a(j1)%lf%ut

! call d_field_for_demin(vf,re,im,ut)
 call d_field_for_demin(vf,ut)
 if(k==d_pos) then
  call print(ut,d_mf)
  call print(vf%v(1),d_mf)
endif
 !   d_line%a(j1)%lf%m=c_map
    d_linelf0m= c_map*d_linelf0m
    d_probe_b=d_probe_8
       d_probe_8 = id + d_probe_b 
  enddo



 call kill(id,c_map,a_cs,d_linelf0m,L)
 call kill(vf)
 call kill(d_probe_8)
if(.not.did_twiss) write(6,*) "Maybe you forgot a twiss : suspicious"

end subroutine twiss_no_map

!!!!!!!!!!!!!!!!!!!!!!!    does not work  !!!!!!1
subroutine compute_emittance_from_formula(sigma,emit)
implicit none
real(dp) emit(3),sigma(6,6),sig4(6,6),sig2(6,6),i2,i4,i6,p,q
integer i
 
sig4=matmul(sigma,sj)
sig2=matmul(sig4,sig4)
i2=0
do i=1,6
i2=sig2(i,i)+i2
enddo
sig4=matmul(sig2,sig2)
i4=0
do i=1,6
i4=sig4(i,i)+i4
enddo
sig4=matmul(sig2,sig4)
i6=0
do i=1,6
i6=sig4(i,i)+i6
enddo

p=i2**2/24-i4/4

q=(-18*i6+9*i2*i4 -i2**3)/108

do i=1,3
 emit(i)=  ( 2*sqrt(-p/3.d0)* cos( ( acos(3.d0*q/2.d0/p*sqrt(-3.d0/p)) -i*twopi )/3.d0 ) + i2**2/6.d0 )

enddo
 
end subroutine compute_emittance_from_formula


     subroutine d_init()
         implicit none
         integer n(11)
          call d_kill_all_tpsa
         call init(d_state,d_no,d_np)
          d_init_fpp_ptc=.false.
          call c_get_indices(n,6)
d_ndt=n(6)
d_ndpt=n(5)
d_nd2=n(3)
d_do_damping=d_state%radiation
  !n(1)=NO
  !n(2)=ND
  !n(3)=ND2
  !n(4)=NV
  !n(5)=Ndpt
  !n(6)=ndptb
  !n(7)=np
  !n(8)=rf*2
  !n(9)=ndc2t
  !n(10)=nd2t
  !n(11)=nd2harm

      end subroutine d_init 

     subroutine d_kill_all_tpsa()
      implicit none
      integer i
      type(layout), pointer :: dline
        dline=>d_line
        d_line=>m_u%start
       do while(.true.) 
        if(associated(d_line)) then
         if(associated(d_line%a)) then
          if(associated(d_line%lf0%m)) then
            call kill_m_array_full
            call deallocate_m_array_full
           endif
         endif
        else
          exit
        endif
        d_line=>d_line%next
       enddo
            d_line=>m_t%start
       do while(.true.) 
        if(associated(d_line)) then
          if(associated(d_line%lf0%m)) then
            call kill_m_array_full
            call deallocate_m_array_full
           endif

        else
          exit
        endif
        d_line=>d_line%next
       enddo  
       d_line=>dline
     end subroutine d_kill_all_tpsa

  SUBROUTINE d_even_line
  implicit none
  integer i,n
  type(fibre), pointer :: p
  type(layout), pointer :: l
  n=0
  p=>d_line%start
  do i=1,d_line%n
    if(p%mag%L/=0.and.mod(p%mag%p%nst,2)==1) then
     n=n+1
     p%mag%p%nst=p%mag%p%nst+1
     p%magp%p%nst=p%magp%p%nst+1
                call add(p,p%MAG%P%nmul,1,0.0_dp)
    endif
   p=>p%next
  enddo
  if(n>0)  then
             l=>d_line%parent_universe%start
             do i=1,d_line%parent_universe%n
                call make_node_layout(l)
                 call survey(l)
                l=>l%next
             enddo
endif
write(6,*) n, "fibre(s) made even"
  end SUBROUTINE d_even_line

 
  SUBROUTINE d_line_force_middle
  implicit none
  integer i,n
  type(fibre), pointer :: p
  n=0
  if(.not.associated(d_line%a)) then
    write(6,*) "Ignored array of fibres not initialized "
   return
 endif
  do i=1,d_line%n
  p=>d_line%a(i)%fib1
   if(p%mag%L/=0) then
     if(mod(p%mag%p%nst,2)/=0) n=n+1
   endif 
  p=>d_line%a(i)%fib2
   if(p%mag%L/=0) then
     if(mod(p%mag%p%nst,2)/=0) n=n+1
   endif 
  enddo
 
 if(n>0) then
  Write(6,*) "Command ignored! "
  Write(6,*) n, " magnets cannot be split: number of integration steps must be even"
  Write(6,*) ' Try command  makealleven: be careful it changes the lattice. '
  stop
else
 do i=1,d_line%n
  d_line%a(i)%centre=1
 enddo
endif

 
  end SUBROUTINE d_line_force_middle

 
  SUBROUTINE d_line_remove_middle
  implicit none
  integer i
 
  if(.not.associated(d_line%a)) then
    write(6,*) "Ignored array of fibres not initialized "
   return
 endif

 do i=1,d_line%n
  d_line%a(i)%centre=1
 enddo

  end SUBROUTINE d_line_remove_middle

subroutine make_twiss_name
implicit none
character(120) line
integer i,j,k,js
character(2) s(3),z(3)
ilatname=1

z(1)="x"
z(2)="y"
z(3)="z"
latname=" "
 
do i=1,3
do j=1,6
do k=1,6
write(line,*) "<z",j,"*z",k,">_",i
call context(line,maj=.false.)
latname(i,j,k)=line(1:11)
write(line,*) "<z",j,">_",i,"/z",k
call context(line,maj=.false.)
latname(i+3,j,k)=line(1:11)
!write(6,*) latname(i,j,k),"   ", latname(i+3,j,k)


 enddo
enddo
enddo
 
s(1)="l "
s(2)="n "
s(3)="m "

do i=1,3
do j=1,3
do k=0,6
if(k/=0) then
 write(line,*) "d",s(i),"_",z(j),"/dz",k
 call context(line,maj=.false.)
 latname(i+5,j,k)=line(1:11)
! write(6,*) line(1:11)
else
 write(line,*) s(i),"0_",z(j)
 call context(line,maj=.false.)
 latname(i+5,j,k)=line(1:11)
 !write(6,*) line(1:11)

endif  

 enddo
enddo
enddo
 

if(common_twiss_name) then
latname(1,1,1)="betax"
latname(2,3,3)="betay"
latname(3,ntime,ntime)="betat"

latname(1,2,2)="gammax"
latname(2,4,4)="gammay"
latname(3,ndelta,ndelta)="gammat"

latname(1,1,2)="alphax"
latname(2,3,4)="alphay"
latname(3,5,6)="alphat"
latname(1,2,1)="alphax"
latname(2,4,3)="alphay"
latname(3,6,5)="alphat"

ilatname(1,1,2)=-1
ilatname(2,3,4)=-1
ilatname(3,5,6)=-1
ilatname(1,2,1)=-1
ilatname(2,4,3)=-1
ilatname(3,6,5)=-1





do k=1,4
write(line,*) "zeta_",k
call context(line,maj=.false.)
latname(6,k,ntime)=line(1:11)
write(line,*) "eta_",k
call context(line,maj=.false.)
latname(6,k,ndelta)=line(1:11)
enddo
latname(4,1,3)="D_11"
latname(4,1,4)="D_12"
latname(4,2,3)="D_21"
latname(4,2,4)="D_22"
latname(5,1,3)="-D_11"
latname(5,1,4)="-D_12"
latname(5,2,3)="-D_21"
latname(5,2,4)="-D_22"


endif

end subroutine make_twiss_name

subroutine default_twiss
implicit none
iformats=0

n_lat_print=0
i_lat(n_lat_print)=1;     j_lat(n_lat_print)=1;     k_lat(n_lat_print)=1 ;l_lat(n_lat_print)=0;
n_lat_print=1
i_lat(n_lat_print)=1;     j_lat(n_lat_print)=1;     k_lat(n_lat_print)=1 ;l_lat(n_lat_print)=0;
n_lat_print=2
i_lat(n_lat_print)=1;     j_lat(n_lat_print)=1;     k_lat(n_lat_print)=2 ;l_lat(n_lat_print)=0;

n_lat_print=3
i_lat(n_lat_print)=2;     j_lat(n_lat_print)=3;     k_lat(n_lat_print)=3 ;l_lat(n_lat_print)=0;
n_lat_print=4
i_lat(n_lat_print)=2;     j_lat(n_lat_print)=3;     k_lat(n_lat_print)=4 ;l_lat(n_lat_print)=0;
 
n_lat_print=5
i_lat(n_lat_print)=6;     j_lat(n_lat_print)=1;     k_lat(n_lat_print)=5+ndpt_bmad ;l_lat(n_lat_print)=0;
n_lat_print=6
i_lat(n_lat_print)=6;     j_lat(n_lat_print)=2;     k_lat(n_lat_print)=5+ndpt_bmad ;l_lat(n_lat_print)=0;
!common_twiss_name=.true.
call  set_title_line_twiss
set_default_twiss=.false.

end subroutine default_twiss

subroutine select_twiss(filename)
implicit none
character(*) filename
character(1) c
character(120) formats
integer mfi,i,j,k,l
  
n_lat_print=0
iformats=0
 call kanalnummer(mfi,filename)
read(mfi,'(A)') formats 

call context(formats)
 if(formats(1:4)=="FULL") iformats=0
 if(formats(1:5)=="ONLYS") iformats=1
write(6,*) formats

     read(mfi,* ) i,j,k,l
i_lat(n_lat_print)=i;     j_lat(n_lat_print)=j;     k_lat(n_lat_print)=k ;l_lat(n_lat_print)=l;

   do while(.true.)
     read(mfi,*,end=100) c,i,j,k
 
     n_lat_print=n_lat_print+1
     if(c=="e".or.c=="E") then
       i_lat(n_lat_print)=i;     j_lat(n_lat_print)=j;     k_lat(n_lat_print)=k
      elseif(c=="h".or.c=="H") then
       i_lat(n_lat_print)=i+3;     j_lat(n_lat_print)=j;     k_lat(n_lat_print)=k
       elseif(c=="s".or.c=="S") then
       i_lat(n_lat_print)=i+5;     j_lat(n_lat_print)=j;     k_lat(n_lat_print)=k
        else
          n_lat_print=n_lat_print-1
          goto 100
      endif
     if(n_lat_print>nlat) stop 999
   enddo

100 continue
  write(6,*) n_lat_print,"Lattice functions selected "
  close(mfi)
end subroutine select_twiss

subroutine print_twiss(filename)
implicit none
character(*) filename
integer mfi,i,nbuf,k,nnum,pos,j1,j2,ms,ip
real(dp) s





nnum=11

  nbuf=18+nnum+3+(iiabs(i_lat(0))+iiabs(j_lat(0))+iiabs(k_lat(0))+iiabs(l_lat(0)))*13 

 if(filename=="screen".or.filename=="terminal") then
  mfi=6
 else
 call kanalnummer(mfi,filename)
 endif
write(mfi,'(a)') line_twiss_title(1:len_trim(line_twiss_title))

!!!!!!!!!!!!!!  lf0 stuff here
 i=d_mod(d_pos,size(d_line%a))
 line_twiss=' '
 
 if(iformats==0) line_twiss(2:9)=d_line%a(i)%fib1%mag%name(1:8)

    s=d_line%a(i)%fib1%t1%s(1)
    if(iformats==0) line_twiss(len_trim(line_twiss(1:10))+1:len_trim(line_twiss(1:10))+1) = "["
 
    if(iformats==0) line_twiss(12:19)=" "    !d_line%a(i)%fib1%next%mag%name(1:8)

  write(line_twiss(19:29),formats) s
  if(iformats==0) then  
    write(line_twiss(30:32),"(a3)") "! "
  endif
pos=nbuf-(iiabs(i_lat(0))+iiabs(j_lat(0))+iiabs(k_lat(0))+iiabs(l_lat(0)))*13+1
pos=pos-13
 if(i_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%lf0%phase(1)
 endif
 if(i_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%damping(1)
 endif
 if(i_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%lf0%phase(1)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%damping(1)
 endif
  if(j_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%lf0%phase(2)
 endif
  if(j_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%damping(2)
 endif
 if(j_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%lf0%phase(2)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%damping(2)
 endif
  if(k_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%phase(3)
 endif
  if(k_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%damping(3)
 endif
 if(k_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%phase(3)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%lf0%damping(3)
 endif
  if(l_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%lf0%spin(1)
 endif
  if(l_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%lf0%spin(2)
 endif
  if(l_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%lf0%spin(1)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%lf0%spin(2)
 endif
    do k=1,n_lat_print
        if(i_lat(k)<=3) then
          s=d_line%lf0%e(i_lat(k),j_lat(k),k_lat(k))
        elseif(i_lat(k)>3.and.i_lat(k)<=6) then
         s=d_line%lf0%h(i_lat(k)-3,j_lat(k),k_lat(k))
        else  
write(6,*) i_lat(k)-5
         s=d_line%lf0%spin_lat(i_lat(k)-5,j_lat(k),k_lat(k))
        endif
         s=s*ilatname(i_lat(k),j_lat(k),k_lat(k))
        write(line_twiss(nbuf+(k-1)*13:nbuf+k*13-1),formatld) s
    enddo
 write(mfi,'(a)') line_twiss(1:len_trim(line_twiss))
!!!!!!!!!!!!!!!!!!!!!!!!!!!

 do ip=d_pos,d_pos+size(d_line%a)-1
 i=d_mod(ip,size(d_line%a))

if(mod(ip-d_pos+1,print_title)==0.and.iformats==0) write(mfi,'(a)') line_twiss_title(1:len_trim(line_twiss_title))

    j1=d_mod(i,size(d_line%a))
    j2=d_mod(i+1,size(d_line%a))

       ms=d_line%a(j1)%centre+2*d_line%a(j2)%centre

 if(iformats==0)  then
  line_twiss=' '
  if(ms>1) then 
   line_twiss(3:10)=d_line%a(i)%fib2%mag%name(1:8)
   s=d_line%a(i)%fib2%next%tm%s(1)
    line_twiss(11:11)="*"
    line_twiss(12:19)=d_line%a(i)%fib2%next%mag%name(1:8)

 else

 line_twiss(2:9)=d_line%a(i)%fib2%mag%name(1:8)

    s=d_line%a(i)%fib2%t1%s(1)+d_line%a(i)%fib2%MAG%P%LD 
          line_twiss(len_trim(line_twiss(1:10))+1:len_trim(line_twiss(1:10))+1) = "]"
 !   line_twiss(11:11)="]"
    line_twiss(12:19)=d_line%a(i)%fib2%next%mag%name(1:8)
  endif
else ! ==1
  line_twiss=' '
  if(ms>1) then 
   s=d_line%a(i)%fib2%next%tm%s(1)
 else
    s=d_line%a(i)%fib2%t1%s(1)+d_line%a(i)%fib2%MAG%P%LD 
  endif
 endif  ! iformats = 0

 write(line_twiss(19:29),formats) s
  if(iformats==0) write(line_twiss(30:32),"(a3)") "! "
 
pos=nbuf-(iiabs(i_lat(0))+iiabs(j_lat(0))+iiabs(k_lat(0))+iiabs(l_lat(0)))*13+1
pos=pos-13
 if(i_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%a(i)%lf%phase(1)
 endif
 if(i_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%damping(1)
 endif
 if(i_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%a(i)%lf%phase(1)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%damping(1)
 endif
  if(j_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%a(i)%lf%phase(2)
 endif
  if(j_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%damping(2)
 endif
 if(j_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatl)  d_line%a(i)%lf%phase(2)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%damping(2)
 endif
  if(k_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%phase(3)
 endif
  if(k_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%damping(3)
 endif
 if(k_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%phase(3)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatd)  d_line%a(i)%lf%damping(3)
 endif
  if(l_lat(0)==1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%a(i)%lf%spin(1)
 endif
  if(l_lat(0)==-1) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%a(i)%lf%spin(2)
 endif
  if(l_lat(0)==2) then
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%a(i)%lf%spin(1)
  pos=pos+13
  write(line_twiss(pos:pos+nnum-1),formatld)  d_line%a(i)%lf%spin(2)
 endif
    do k=1,n_lat_print
        if(i_lat(k)<=3) then
          s=d_line%a(i)%lf%e(i_lat(k),j_lat(k),k_lat(k))
        elseif(i_lat(k)>3.and.i_lat(k)<=6) then
         s=d_line%a(i)%lf%h(i_lat(k)-3,j_lat(k),k_lat(k))
        else  
         s=d_line%a(i)%lf%spin_lat(i_lat(k)-5,j_lat(k),k_lat(k))
        endif
         s=s*ilatname(i_lat(k),j_lat(k),k_lat(k))
        write(line_twiss(nbuf+(k-1)*13:nbuf+k*13-1),formatld) s
    enddo
 write(mfi,'(a)') line_twiss(1:len_trim(line_twiss))

 enddo
100 continue
  if(mfi/=6) close(mfi)
end subroutine print_twiss

integer function iiabs(i)
 implicit none
 integer(2) i
iiabs=i
 if(iiabs<0) iiabs=-iiabs

 return
 end  function iiabs

subroutine set_title_line_twiss 
implicit none

integer  k,nbuf ,dn,pos,nnum 
dn=2
line_twiss_title=" "
nnum=11
 nbuf=18+nnum+3+(iiabs(i_lat(0))+iiabs(j_lat(0))+iiabs(k_lat(0))+iiabs(l_lat(0)))*13 +dn

 if(iformats==0) line_twiss_title(1:10)=  "  Name    "
 line_twiss_title(19:29)=  "      s   "
pos=18+nnum+1+dn
pos=pos-13
 if(i_lat(0)==1) then
  pos=pos+13
  line_twiss_title(pos:pos+13-1)= "    Phase x  "  
 endif
 if(i_lat(0)==-1) then
  pos=pos+13
  line_twiss_title(pos:pos+13-1)= "  Damping x  "  
 endif
 if(i_lat(0)==2) then
  pos=pos+13
  line_twiss_title(pos:pos+13-1)= "    Phase x  "  
  pos=pos+13
  line_twiss_title(pos:pos+13-1)= "  Damping x  "  
 endif
 if(j_lat(0)==1) then
  pos=pos+13
  line_twiss_title(pos:pos+13-1)=  "    Phase y  "  
 endif
 if(j_lat(0)==-1) then
  pos=pos+13
  line_twiss_title(pos:pos+13-1)=  "  Damping y  "   
 endif
 if(j_lat(0)==2) then
  pos=pos+13
  line_twiss_title(pos:pos+13-1)=  "    Phase y  "  
  pos=pos+13
  line_twiss_title(pos:pos+13-1)=  "  Damping y  "   
 endif
 if(k_lat(0)==1) then
  pos=pos+13
   if(d_state%nocavity ) then
   line_twiss_title(pos:pos+13-1)= "   Time Slip "  
  else
   line_twiss_title(pos:pos+13-1)= "    Phase t  "  
  endif
 endif
 if(k_lat(0)==-1) then
  pos=pos+13
   line_twiss_title(pos:pos+13-1)= "  Damping t  "   
 endif
 
 if(k_lat(0)==2) then
  pos=pos+13
   if(d_state%nocavity ) then
   line_twiss_title(pos:pos+13-1)= "   Time Slip "  
  else
   line_twiss_title(pos:pos+13-1)= "    Phase t  "  
  endif

  pos=pos+13
   line_twiss_title(pos:pos+13-1)= "  Damping t  "   
 endif



 if(l_lat(0)==1) then
  pos=pos+13

   line_twiss_title(pos:pos+13-1)= "  Spin Phase "  
 
 endif
 if(l_lat(0)==-1) then
  pos=pos+13

   line_twiss_title(pos:pos+13-1)= "  Spin Chrom "  
 
 endif
 if(l_lat(0)==2) then
  pos=pos+13
   line_twiss_title(pos:pos+13-1)= "  Spin Phase "  
  pos=pos+13
   line_twiss_title(pos:pos+13-1)= "  Spin Chrom "  
 
 endif
do k=1,n_lat_print
write(line_twiss_title(nbuf+(k-1)*13:nbuf+k*13-1),"(1x,a11,1x)") latname(i_lat(k),j_lat(k),k_lat(k))
enddo
 
 
!write(6,'(a)') line_twiss_title(1:len_trim(line_twiss_title))
 

end subroutine set_title_line_twiss

subroutine d_get_lattice_matrix(mat,lf,filename,mfo,L,spinv,H,B)
implicit none
type(d_lattice_function),intent(IN):: lf
character(*),optional :: filename
integer,optional :: mfo
real(dp),optional :: L(6,6),spinv(3,0:6),H(3,1:6,1:6),B(3,1:6,1:6)
character(2) mat
integer mf,i,j
real(dp) M(6,6)
logical closef,printf,spinf

if(present(filename).and.present(mfo)) then
  write(6,*) "error: filename and mfo both present as optionals"
  stop 100
endif

closef=.false.
 printf=.true.
  spinf=.false.
if(present(filename)) then
    if(filename/="screen") then
      call KanalNummer(mf,filename)
      closef=.true.
    else
     mf=5
    endif
elseif(present(mfo)) then
 mf=mfo
else
 printf=.false.
if(.not.present(L).and.(.not.present(H)).and.(.not.present(B))) then
  write(6,*) "Nothing to output in "
  stop 101
endif
endif

select case(mat)

case("B1")
 m = matmul(lf%E(1,1:6,1:6),jt_mat)
case("E1") 
 m = lf%E(1,1:6,1:6)
case("K1") 
 m = -matmul(jt_mat,matmul(lf%E(1,1:6,1:6),jt_mat))
case("B2")
 m = matmul(lf%E(2,1:6,1:6),jt_mat)
case("E2") 
 m = lf%E(2,1:6,1:6)
case("K2")
 m = -matmul(jt_mat,matmul(lf%E(2,1:6,1:6),jt_mat))
case("B3")
 m = matmul(lf%E(3,1:6,1:6),jt_mat)
case("E3")
 m = lf%E(3,1:6,1:6)
case("K3")  
 m = -matmul(jt_mat,matmul(lf%E(3,1:6,1:6),jt_mat))

case("H1") 
 m =lf%H(1,1:6,1:6)
case("H2") 
 m =lf%H(2,1:6,1:6)
case("H3") 
  m =lf%H(3,1:6,1:6)

case("S1","l ") 
  i=1
spinf=.true.
 case("S2","n ") 
  i=2
spinf=.true.
 case("S3","m ") 
  i=3
spinf=.true.

case default
  
end select

if(printf) then
write(mf,*) mat
if(spinf) then
 do j=1,3
 write(mf,format7) lf%Spin_lat(i,j,0:6)
enddo 
else
do j=1,6
 write(mf,format6) m(j,1:6)
enddo
endif
endif  !printf

if(spinf) then
  spinv=lf%Spin_lat(i,1:3,0:6)
endif
if(present(L)) then
 L=m
endif
if(present(B)) then
 do i=1,3 
  B(i,1:6,1:6) = matmul(lf%E(i,1:6,1:6),jt_mat)
 enddo
endif
if(present(H)) then
 do i=1,3 
  H(i,1:6,1:6) = lf%H(i,1:6,1:6) 
 enddo
endif
if(closef) close(mf)

end subroutine d_get_lattice_matrix

subroutine d_print_matrix(ma,filename,mfo,prec)
implicit none
character(*),optional :: filename
integer,optional :: mfo
real(dp),optional :: prec
real(dp),intent(inout) ::  ma(:,:)
integer mf,i,j
real(dp),allocatable :: mat(:,:)
logical closef 

allocate(mat(1:size(ma,1),1:size(ma,2)))
mat=ma

if(present(prec)) then
 do i=1,size(mat,1)
 do j=1,size(mat,2)
   if(abs(mat(i,j))<prec) mat(i,j)=0
 enddo
 enddo
endif


if(present(filename).and.present(mfo)) then
  write(6,*) "error: filename and mfo both present as optionals"
  stop 100
endif

closef=.false.




if(present(filename)) then
    if(filename/="screen") then
      call KanalNummer(mf,filename)
      closef=.true.
    else
     mf=5
    endif
elseif(present(mfo)) then
 mf=mfo
 
else
 mf=6
endif



 do i=1,size(mat,1)
   write(mf,format6) mat(i,1:size(mat,2))
 enddo

 

 deallocate(mat)

if(closef) close(mf)

end subroutine d_print_matrix


  SUBROUTINE CONTEXTlc( STRING )
    IMPLICIT NONE
    CHARACTER(*) STRING
    CHARACTER(1) C1

    integer I,J,K,nb0,count
     logical(lp) dol,ma,mi
    nb0=0
    dol=.false.

    J = 0
    count=0
    DO I = 1, LEN (STRING)
       C1 = STRING(I:I)
       if(dol) then
        if(c1=='$') c1="_"
       endif
       STRING(I:I) = ' '
       IF( C1 .NE. ' ' ) THEN
          if(count/=0.and.nb0==1) then
             J = J + 1
             STRING(J:J) = ' '
             count=0
          endif
          J = J + 1
          K = ICHAR( C1 )
      !    IF( K .GE. ICHAR('a') .AND. K .LE. ICHAR('z').and.ma ) THEN
      !       C1 = CHAR( K - ICHAR('a') + ICHAR('A') )
      !    ENDIF
          IF( K .GE. ICHAR('A') .AND. K .LE. ICHAR('Z') ) THEN
             C1 = CHAR( K - ICHAR('A') + ICHAR('a') )
          ENDIF
          STRING(J:J) = C1
       else
          count=count+1
       ENDIF
    ENDDO
    string=string(1:len_trim(string))
    RETURN
  END  SUBROUTINE CONTEXTlc
      
subroutine d_resonance(mres,ut,res)
implicit none
type(c_universal_taylor), intent(in) :: ut
type(c_universal_taylor), intent(inout) :: res
integer Mres(:)
integer i,j,nr,ir1,ir2

nr=0

do i=1,ut%n
ir1=0
ir2=0
 do j=1,ut%nd2/2
   ir1=iabs((ut%J(i,2*j-1)-ut%J(i,2*j)+mres(j)))+ir1
   ir2=iabs((ut%J(i,2*j-1)-ut%J(i,2*j)-mres(j)))+ir2
 enddo
  if(ir1==0.or.ir2==0) then
    nr=nr+1
   endif
enddo

 if(associated(res%c)) call kill(res)

call alloc(res,nr,ut%nv,ut%nd2)

nr=0

do i=1,ut%n
ir1=0
ir2=0
 do j=1,ut%nd2/2
   ir1=iabs((ut%J(i,2*j-1)-ut%J(i,2*j)+mres(j)))+ir1
   ir2=iabs((ut%J(i,2*j-1)-ut%J(i,2*j)-mres(j)))+ir2
 enddo
  if(ir1==0.or.ir2==0) then
    nr=nr+1
    res%c(nr)=ut%c(i)
    res%j(nr,1:ut%nv)=ut%j(i,1:ut%nv)
   endif
enddo

end subroutine d_resonance


!subroutine d_field_for_demin(f,re,im,ut)

end module demin_command