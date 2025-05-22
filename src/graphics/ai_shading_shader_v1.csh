#!/bin/csh

set width = 1920
set height = 1080
set maxSteps = 100
set epsilon = 0.001
set maxDist = 100.0
set ambient = 0.1

alias sin 'perl -e "print sin($ARGV[1])"'
alias cos 'perl -e "print cos($ARGV[1])"'
alias tan 'perl -e "print tan($ARGV[1])"'
alias pow 'perl -e "print $ARGV[1]**$ARGV[2]"'
alias sqrt 'perl -e "print sqrt($ARGV[1])"'
alias abs 'perl -e "print abs($ARGV[1])"'
alias dot 'perl -e "my (\$x1,\$y1,\$z1,\$x2,\$y2,\$z2)=@ARGV; print \$x1*\$x2 + \$y1*\$y2 + \$z1*\$z2"'
alias length 'perl -e "my (\$x,\$y,\$z)=@ARGV; print sqrt(\$x*\$x + \$y*\$y + \$z*\$z)"'
alias normalize 'perl -e "my (\$x,\$y,\$z)=@ARGV; my \$len = sqrt(\$x*\$x+\$y*\$y+\$z*\$z); print \$x/\$len, ' ', \$y/\$len, ' ', \$z/\$len"'
alias cross 'perl -e "my (\$ax,\$ay,\$az,\$bx,\$by,\$bz)=@ARGV; print (\$ay*\$bz - \$az*\$by), ' ', (\$az*\$bx - \$ax*\$bz), ' ', (\$ax*\$by - \$ay*\$bx)"'

set PI = 3.141592653589793

proc sphere_sdf { p r } {
    set dist = length $p
    return `perl -e "print \$dist - $r"`
}

proc plane_sdf { p n d } {
    set numerator = dot $p $n
    set dist = `perl -e "print (\$numerator + $d)"`
    return $dist
}

proc scene_sdf { p } {
    # Sphere at origin radius 1.0
    set sphereDist = [sphere_sdf $p 1.0]
    # Plane y = -1
    set planeDist = [plane_sdf $p "0 1 0" -1]
    if ( $sphereDist < $planeDist ) then
        return $sphereDist
    else
        return $planeDist
    endif
}

proc get_normal { p } {
    set h = 0.001
    set dx = [scene_sdf [list [expr {$p[0] + $h}] $p[1] $p[2]]]
    set dy = [scene_sdf [list $p[0] [expr {$p[1] + $h}] $p[2]]]
    set dz = [scene_sdf [list $p[0] $p[1] [expr {$p[2] + $h}]]]
    set nx = [expr {$dx - [scene_sdf $p]}]
    set ny = [expr {$dy - [scene_sdf $p]}]
    set nz = [expr {$dz - [scene_sdf $p]}]
    set n = [normalize $nx $ny $nz]
    return $n
}

proc ray_march { ro rd } {
    set distTotal = 0.0
    set i = 0
    while ( $i < $maxSteps && $distTotal < $maxDist ) do
        set p = [list [expr {$ro[0] + $rd[0]*$distTotal}] [expr {$ro[1] + $rd[1]*$distTotal}] [expr {$ro[2] + $rd[2]*$distTotal}]]
        set dist = [scene_sdf $p]
        if ( $dist < $epsilon ) then
            return [list $p $dist]
        endif
        @ distTotal += $dist
        @ i++
    end
    return ""
}

proc compute_lighting { p n lightPos } {
    set lightDir = [normalize [list [expr {$lightPos[0] - $p[0]}] [expr {$lightPos[1] - $p[1]}] [expr {$lightPos[2] - $p[2]}]]]
    set diff = [dot $n $lightDir]
    if ( $diff < 0 ) then
        set diff = 0
    endif
    set viewDir = [normalize [list [expr {0 - $p[0]}] [expr {1 - $p[1]}] [expr {0 - $p[2]}]]]
    set reflectDir = [list
        [expr {2 * $diff * [dot $n $lightDir] - $lightDir[0]}]
        [expr {2 * $diff * [dot $n $lightDir] - $lightDir[1]}]
        [expr {2 * $diff * [dot $n $lightDir] - $lightDir[2]}]
    ]
    set spec = 0.0
    set specStrength = 0.5
    set shininess = 32
    set viewReflectDot = [dot $reflectDir $viewDir]
    if ( $viewReflectDot > 0 ) then
        set spec = [pow $viewReflectDot $shininess]
    endif
    set ambientComponent = $ambient
    set diffuseComponent = $diff
    set specularComponent = [expr {$specStrength * $spec}]
    set lighting = [expr {$ambientComponent + $diffuseComponent + $specularComponent}]
    return $lighting
}

set filename = "shader_output.ppm"
set file = `open $filename "w"`

printf $file "P3\n$width $height\n255\n"

set cameraPos = [list 0 0 3]
set lightPos = [list 5 5 5]

@ px = 0
while ( $px < $width ) do
    @ py = 0
    while ( $py < $height ) do
        set u = [expr {($px / $width) * 2 - 1}]
        set v = [expr {($py / $height) * 2 - 1}]
        set aspect = [expr {$width / $height}]
        set dirX = $u
        set dirY = [expr {$v}]
        set dirZ = -1
        set dir = [normalize $dirX $dirY $dirZ]
        set rayResult = [ray_march $cameraPos $dir]
        if ( "$rayResult" != "" ) then
            set hitPoint = `[lindex $rayResult 0]`
            set normal = [get_normal $hitPoint]
            set colorR = 0.0
            set colorG = 0.0
            set colorB = 0.0
            # Simple shading with a single light source
            set lighting = [compute_lighting $hitPoint $normal $lightPos]
            set colorR = [expr {255 * $lighting}]
            set colorG = [expr {255 * $lighting}]
            set colorB = [expr {255 * $lighting}]
        else
            set colorR = 0
            set colorG = 0
            set colorB = 0
        endif
        printf $file "%d %d %d\n" $colorR $colorG $colorB
        @ py++
    end
    @ px++
end

close $file