!!!    This program sloves Lid Driven Cavity Flow problem using Lattice Boltzmann Method
!!!    Lattice Boltzmann Equation with BGK approximation
!!!    Copyright (C) 2012  Ao Xu
!!!    This work is licensed under the Creative Commons Attribution-NonCommercial 3.0 Unported License.
!!!    Ao Xu, Profiles: <http://www.linkedin.com/pub/ao-xu/30/a72/a29>


!!!                  Moving Wall
!!!               |---------------|
!!!               |               |
!!!               |               |
!!!    Stationary |               | Stationary
!!!       Wall    |               |    Wall
!!!               |               |
!!!               |               |
!!!               |---------------|
!!!                Stationary Wall


        program main
        implicit none
        integer, parameter :: N=129,M=129
        integer :: i, j, itc, itc_max, k
        integer :: iwall(N,M)
        real(8) :: Re, cs2, U_ref, dx, dy, dt, tau
        real(8) :: eps, error
        real(8) :: X(N), Y(M), u(N,M), v(N,M), up(N,M), vp(N,M), rho(N,M), p(N,M), psi(N,M)
        real(8) :: omega(0:8), f(0:8,N,M), un(0:8)
        real(8) :: ex(0:8), ey(0:8)
        data ex/0.0d0,1.0d0,0.0d0, -1.0d0, 0.0d0, 1.0d0, -1.0d0, -1.0d0, 1.0d0/
        data ey/0.0d0,0.0d0,1.0d0, 0.0d0, -1.0d0, 1.0d0, 1.0d0, -1.0d0, -1.0d0/

!!!     D2Q9 Lattice Vector Properties:
!!!              6   2   5
!!!                \ | /
!!!              3 - 0 - 1
!!!                / | \
!!!              7   4   8

!!! input initial data
        Re = 10.0d0
        cs2 = 1.0d0/3.0d0
        U_ref = 0.1d0
        dx = 1.0d0/float(N-1)
        dy = 1.0d0/float(M-1)
        dt = dx
        tau = 3.0d0*U_ref/Re/dt+0.5d0
        itc = 0
        itc_max = 5*1e5
        eps = 1e-5
        k = 0
        error = 100.0d0

!!! set up initial flow field
        call initial(N,M,dx,dy,X,Y,u,v,rho,psi,U_ref,cs2,omega,ex,ey,un,f)

        do while((error.GT.eps).AND.(itc.LT.itc_max))

!!! collision step
            call collision(N,M,u,v,ex,ey,rho,f,omega,cs2,tau)

!!! streaming step
            call streaming(N,M,f)

!!! boundary condition
            call bounceback(N,M,f)

!!! check convergence
            call check(N,M,u,v,up,vp,itc,error)

!!! output preliminary results
            if(MOD(itc,1000).EQ.0) then
                call calp(N,M,cs2,rho,p)
                call calpsi(N,M,dx,dy,up,vp,psi)
                k = k+1
                call output(N,M,X,Y,up,vp,psi,p,k)
            endif

        enddo

!!! compute pressure field
        call calp(N,M,cs2,rho,p)

!!! compute streamfunction
        call calpsi(N,M,dx,dy,up,vp,psi)

!!! output data file
        k = k+1
        call output(N,M,X,Y,up,vp,psi,p,k)

        write(*,*)
        write(*,*) '************************************************************'
        write(*,*) 'This program sloves Lid Driven Cavity Flow problem using Lattice Boltzmann Method'
        write(*,*) 'Lattice Boltzmann Equation with BGK approximation'
        write(*,*) 'Consider D2Q9 Particle Discrete Velocity model'
        write(*,*) 'N =',N,',       M =',M
        write(*,*) 'Re =',Re
        write(*,*) 'eps =',eps
        write(*,*) 'itc =',itc
        write(*,*) '************************************************************'
        write(*,*)

        stop
        end program main

!!! set up initial flow field
        subroutine initial(N,M,dx,dy,X,Y,u,v,rho,psi,U_ref,cs2,omega,ex,ey,un,f)
        implicit none
        integer :: N, M, i, j
        integer :: alpha
        real(8) :: dx, dy
        real(8) :: U_ref, cs2, us2
        real(8) :: X(N), Y(M)
        real(8) :: omega(0:8), u(N,M), v(N,M), rho(N,M), psi(N,M), ex(0:8), ey(0:8), un(0:8)
        real(8) :: f(0:8,N,M)

        do i=1,N
            X(i) = (i-1)*dx
        enddo
        do j=1,M
            Y(j) = (j-1)*dy
        enddo
        psi = 0.0d0

        omega(0) = 4.0d0/9.0d0
        do alpha=1,4
            omega(alpha) = 1.0d0/9.0d0
        enddo
        do alpha=5,8
            omega(alpha) = 1.0d0/36.0d0
        enddo

        u = 0.0d0
        v = 0.0d0
        rho = 1.0d0
        do i=1,N
            u(i,M) = U_ref
        enddo

        do i=1,N
            do j=1,M
                us2 = u(i,j)*u(i,j)+v(i,j)*v(i,j)
                do alpha=0,8
                    un(alpha) = u(i,j)*ex(alpha)+v(i,j)*ey(alpha)
                    f(alpha,i,j) = omega(alpha)*(1.0d0+un(alpha)/cs2+un(alpha)*un(alpha)/(2.0d0*cs2*cs2)-us2/(2.0d0*cs2))
                enddo
            enddo
        enddo

        return
        end subroutine initial



!!! collision step
        subroutine collision(N,M,u,v,ex,ey,rho,f,omega,cs2,tau)
        implicit none
        integer :: N, M, i, j
        integer :: alpha
        real(8) :: cs2, tau
        !real(8) :: us2
        real(8) :: u(N,M), v(N,M), ex(0:8), ey(0:8), rho(N,M), f(0:8,N,M), omega(0:8)
        real(8) :: un(0:8), feq(0:8,N,M)
        real(8) :: g(0:8,N,M), geq(0:8,N,M), s(0:8)

        do i=1,N
            do j=1,M-1

                    rho(i,j) = 0.0d0
                    do alpha=0,8
                        rho(i,j) = rho(i,j)+f(alpha,i,j)
                    enddo

                    !data ex/0.0d0,1.0d0,0.0d0, -1.0d0, 0.0d0, 1.0d0, -1.0d0, -1.0d0, 1.0d0/
                    !data ey/0.0d0,0.0d0,1.0d0, 0.0d0, -1.0d0, 1.0d0, 1.0d0, -1.0d0, -1.0d0/
                    u(i,j) = (f(1,i,j)-f(3,i,j)+f(5,i,j)-f(6,i,j)-f(7,i,j)+f(8,i,j))/rho(i,j)
                    v(i,j) = (f(2,i,j)-f(4,i,j)+f(5,i,j)+f(6,i,j)-f(7,i,j)-f(8,i,j))/rho(i,j)

!!!-----------------------------------------------------------------
    g(0,i,j) = f(0,i,j)+f(1,i,j)+f(2,i,j)+f(3,i,j)+f(4,i,j)+f(5,i,j)+f(6,i,j)+f(7,i,j)+f(8,i,j)
    g(1,i,j) = -4.0d0*f(0,i,j)-f(1,i,j)-f(2,i,j)-f(3,i,j)-f(4,i,j)+2.0d0*f(5,i,j)+2.0d0*f(6,i,j)+2.0d0*f(7,i,j)+2.0d0*f(8,i,j)
    g(2,i,j) = 4.0d0*f(0,i,j)-2.0d0*f(1,i,j)-2.0d0*f(2,i,j)-2.0d0*f(3,i,j)-2.0d0*f(4,i,j)+f(5,i,j)+f(6,i,j)+f(7,i,j)+f(8,i,j)
    g(3,i,j) = f(1,i,j)-f(3,i,j)+f(5,i,j)-f(6,i,j)-f(7,i,j)+f(8,i,j)
    g(4,i,j) = -2.0d0*f(1,i,j)+2.0d0*f(3,i,j)+f(5,i,j)-f(6,i,j)-f(7,i,j)+f(8,i,j)
    g(5,i,j) = f(2,i,j)-f(4,i,j)+f(5,i,j)+f(6,i,j)-f(7,i,j)-f(8,i,j)
    g(6,i,j) = -2.0d0*f(2,i,j)+2.0d0*f(4,i,j)+f(5,i,j)+f(6,i,j)-f(7,i,j)-f(8,i,j)
    g(7,i,j) = f(1,i,j)-f(2,i,j)+f(3,i,j)-f(4,i,j)
    g(8,i,j) = f(5,i,j)-f(6,i,j)+f(7,i,j)-f(8,i,j)

    geq(0,i,j) = rho(i,j)
    geq(1,i,j) = rho(i,j)*( -2.0d0+3.0d0*(u(i,j)*u(i,j)+v(i,j)*v(i,j)) )
    geq(2,i,j) = rho(i,j)*( 1.0d0-3.0d0*(u(i,j)*u(i,j)+v(i,j)*v(i,j)) )
    geq(3,i,j) = rho(i,j)*u(i,j)
    geq(4,i,j) = -rho(i,j)*u(i,j)
    geq(5,i,j) = rho(i,j)*v(i,j)
    geq(6,i,j) = -rho(i,j)*v(i,j)
    geq(7,i,j) = rho(i,j)*( u(i,j)*u(i,j)-v(i,j)*v(i,j) )
    geq(8,i,j) = rho(i,j)*( u(i,j)*v(i,j) )

    s(0) = 0.0d0
    s(1) = 1.1d0
    s(2) = 1.0d0
    s(3) = 0.0d0
    s(4) = 1.2d0
    s(5) = 0.0d0
    s(6) = 1.2d0
    s(7) = 1.0d0/tau
    s(8) = 1.0d0/tau

    do alpha=0,8
        g(alpha,i,j) = g(alpha,i,j)-s(alpha)*(g(alpha,i,j)-geq(alpha,i,j))
    enddo

    f(0,i,j) = 4.0d0*g(0,i,j)-4.0d0*g(1,i,j)+4.0d0*g(2,i,j)
    f(1,i,j) = 4.0d0*g(0,i,j)-g(1,i,j)-2.0d0*g(2,i,j)+6.0d0*g(3,i,j)-6.0d0*g(4,i,j)+9.0d0*g(7,i,j)
    f(2,i,j) = 4.0d0*g(0,i,j)-g(1,i,j)-2.0d0*g(2,i,j)+6.0d0*g(5,i,j)-6.0d0*g(6,i,j)-9.0d0*g(7,i,j)
    f(3,i,j) = 4.0d0*g(0,i,j)-g(1,i,j)-2.0d0*g(2,i,j)-6.0d0*g(3,i,j)+6.0d0*g(4,i,j)+9.0d0*g(7,i,j)
    f(4,i,j) = 4.0d0*g(0,i,j)-g(1,i,j)-2.0d0*g(2,i,j)-6.0d0*g(5,i,j)+6.0d0*g(6,i,j)-9.0d0*g(7,i,j)
    f(5,i,j) = 4.0d0*g(0,i,j)+2.0d0*g(1,i,j)+g(2,i,j)+6.0d0*g(3,i,j)+3.0d0*g(4,i,j)+6.0d0*g(5,i,j)+3.0d0*g(6,i,j)+9.0d0*g(8,i,j)
    f(6,i,j) = 4.0d0*g(0,i,j)+2.0d0*g(1,i,j)+g(2,i,j)-6.0d0*g(3,i,j)-3.0d0*g(4,i,j)+6.0d0*g(5,i,j)+3.0d0*g(6,i,j)-9.0d0*g(8,i,j)
    f(7,i,j) = 4.0d0*g(0,i,j)+2.0d0*g(1,i,j)+g(2,i,j)-6.0d0*g(3,i,j)-3.0d0*g(4,i,j)-6.0d0*g(5,i,j)-3.0d0*g(6,i,j)+9.0d0*g(8,i,j)
    f(8,i,j) = 4.0d0*g(0,i,j)+2.0d0*g(1,i,j)+g(2,i,j)+6.0d0*g(3,i,j)+3.0d0*g(4,i,j)-6.0d0*g(5,i,j)-3.0d0*g(6,i,j)-9.0d0*g(8,i,j)

    do alpha=0,8
        f(alpha,i,j) = f(alpha,i,j)/36.0d0
    enddo

!!!--------------------------------------------
!                    us2 = u(i,j)*u(i,j)+v(i,j)*v(i,j)
!                    do alpha=0,8
!                        un(alpha) = u(i,j)*ex(alpha) + v(i,j)*ey(alpha)
!                        feq(alpha,i,j) = omega(alpha)*rho(i,j) &
!                                       *(1.0d0+un(alpha)/cs2+un(alpha)*un(alpha)/(2.0d0*cs2*cs2)-us2/(2.0d0*cs2))
!                        f(alpha,i,j) = f(alpha,i,j)-1.0d0/tau*(f(alpha,i,j)-feq(alpha,i,j))
!                    enddo

            enddo
        enddo

!        !Left bottom corner
!        f(6,1,1) = feq(6,1,1)
!        f(8,1,1) = feq(8,1,1)
!
!        !Right bottom corner
!        f(5,N,1) = feq(5,N,1)
!        f(7,N,1) = feq(7,N,1)

        return
        end subroutine collision


!!! streaming step
        subroutine streaming(N,M,f)
        implicit none
        integer :: i, j, N, M
        real(8) :: f(0:8,N,M)

        do i=1,N
            do j=1,M-1
                f(0,i,j) = f(0,i,j)
            enddo
        enddo
        do i=N,2,-1
            do j=1,M-1
                f(1,i,j) = f(1,i-1,j)
            enddo
        enddo
        do i=1,N
            do j=M-1,2,-1
                f(2,i,j) = f(2,i,j-1)
            enddo
        enddo
        do i=1,N-1
            do j=1,M-1
                f(3,i,j) = f(3,i+1,j)
            enddo
        enddo
        do i=1,N
            do j=1,M-1
                f(4,i,j) = f(4,i,j+1)
            enddo
        enddo
        do i=N,2,-1
            do j=M-1,2,-1
                f(5,i,j) = f(5,i-1,j-1)
            enddo
        enddo
        do i=1,N-1
            do j=M-1,2,-1
                f(6,i,j) = f(6,i+1,j-1)
            enddo
        enddo
        do i=1,N-1
            do j=1,M-1
                f(7,i,j) = f(7,i+1,j+1)
            enddo
        enddo
        do i=N,2,-1
            do j=1,M-1
                f(8,i,j) = f(8,i-1,j+1)
            enddo
        enddo

        return
        end subroutine streaming

!!! boundary condition
        subroutine bounceback(N,M,f)
        implicit none
        integer :: N, M, i, j
        real(8) :: f(0:8,N,M)

        do j=2,M-1
            !Left side
            f(1,1,j) = f(3,1,j)
            f(5,1,j) = f(7,1,j)
            f(8,1,j) = f(6,1,j)

            !Right side
            f(3,N,j) = f(1,N,j)
            f(6,N,j) = f(8,N,j)
            f(7,N,j) = f(5,N,j)
        enddo

        do i=2,N-1
            !Bottom side
            f(2,i,1) = f(4,i,1)
            f(5,i,1) = f(7,i,1)
            f(6,i,1) = f(8,i,1)
        enddo

        !Left-Bottom corner
        f(1,1,1) = f(3,1,1)
        f(2,1,1) = f(4,1,1)
        f(5,1,1) = f(7,1,j)

        !Right-Bottom corner
        f(3,N,1) = f(1,N,1)
        f(6,N,1) = f(8,N,1)
        f(2,N,1) = f(4,N,1)

        return
        end subroutine bounceback

!!! check convergence
        subroutine check(N,M,u,v,up,vp,itc,error)
        implicit none
        integer :: N, M, i, j
        integer :: alpha
        integer :: itc
        integer :: iwall(N,M)
        real(8) :: error
        real(8) :: u(N,M), v(N,M), up(N,M), vp(N,M)

        itc = itc+1
        error = 0.0d0
        if(itc.EQ.1) error = 10.0d0
        if(itc.EQ.2) error = 10.0d0
        if(itc.EQ.3) error = 10.0d0

        if(itc.GT.3) then
            do i=1,N
                do j=1,M-1
                    if(iwall(i,j).NE.2) then
                        error  = error+SQRT((u(i,j)-up(i,j))*(u(i,j)-up(i,j))+(v(i,j)-vp(i,j))*(v(i,j)-vp(i,j))) &
                                        /SQRT((u(i,j)+0.00001)*(u(i,j)+0.00001)+(v(i,j)+0.00001)*(v(i,j)+0.00001))
                    endif
                enddo
            enddo
        endif

        up = u
        vp = v

        if(MOD(itc,50).EQ.0) write(*,*) itc,' ',error

!!!        open(unit=01,file='error.dat',status='unknown',position='append')
!!!        if (MOD(itc,2000).EQ.0) then
!!!            write(01,*) itc,' ',error
!!!        endif
!!!        close(01)

        return
        end subroutine check

!!! compute pressure field
        subroutine calp(N,M,cs2,rho,p)
        implicit none
        integer :: N, M, i, j
        real(8) :: cs2
        real(8) :: rho(N,M), p(N,M)

        do i=1,N
            do j=1,M-1
                p(i,j) = rho(i,j)*cs2
            enddo
        enddo

        do i=1,N
            p(i,M) = cs2
        enddo

        return
        end subroutine calp

!!! compute Streamfunction
        subroutine calpsi(N,M,dx,dy,u,v,psi)
        implicit none
        integer :: N, M, i, j
        real(8) :: dx, dy
        real(8) :: u(N,M), v(N,M), psi(N,M)

!        do j=1,M
!            psi(1,j) = 0.0d0
!            psi(N,j) = 0.0d0
!        enddo
!        do i=1,N
!            psi(i,1) = 0.0d0
!            psi(i,M) = 0.0d0
!        enddo

        do i=3,N-2
            do j=2,M-3
            psi(i,j+1) = u(i,j)*2.0d0*dy+psi(i,j-1)
            !psi(i+1,j) = -v(i-1,j)*2.0d0*dx+psi(i-1,j) ! Alternative and equivalent psi formulae
            enddo
        enddo

        do j=2,M-1
            psi(2,j) = 0.25d0*psi(3,j)
            psi(N-1,j) = 0.25d0*psi(N-2,j)
        enddo
        do i=2,N-1
            psi(i,2) = 0.25d0*psi(i,3)
            psi(i,M-1) = 0.25d0*(psi(i,M-2)-0.2d0*dy)
        enddo

        return
        end subroutine calpsi

!!! output data file
        subroutine output(N,M,X,Y,up,vp,psi,p,k)
        implicit none
        integer :: N, M, i, j, k
        real(8) :: X(N), Y(M), up(N,M), vp(N,M), psi(N,M), p(N,M)

        character*16 filename

        filename='0000cavity.dat'
        filename(1:1) = CHAR(ICHAR('0')+MOD(k/1000,10))
        filename(2:2) = CHAR(ICHAR('0')+MOD(k/100,10))
        filename(3:3) = CHAR(ICHAR('0')+MOD(k/10,10))
        filename(4:4) = CHAR(ICHAR('0')+MOD(k,10))

        open(unit=02,file=filename,status='unknown')
        write(02,101)
        write(02,102)
        write(02,103) N, M

        do j=1,M
            do i=1,N
                write(02,100) X(i), Y(j), up(i,j), vp(i,j)!, psi(i,j)!, p(i,j)
            enddo
        enddo

100     format(2x,10(e12.6,'      '))
101     format('Title="Lid Driven Cavity Flow"')
102     format('Variables=x,y,u,v')
103     format('zone',1x,'i=',1x,i5,2x,'j=',1x,i5,1x,'f=point')

        close(02)

        return
        end subroutine output
