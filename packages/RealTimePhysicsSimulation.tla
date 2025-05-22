------------------------------ MODULE PhysicsSim ------------------------------
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    dt \in Real,                \* Time step duration
    gravity \in Real,           \* Gravitational acceleration
    frictionCoefficient \in Real, \* Friction coefficient
    elasticity \in Real,        \* Collision restitution coefficient
    airResistance \in Real,     \* Air resistance coefficient
    gravityVector \in [1..3 -> Real], \* Gravity vector components
    boundaryMin \in [1..3 -> Real], \* Minimum boundary box
    boundaryMax \in [1..3 -> Real], \* Maximum boundary box

VARIABLES
    objects,                   \* Set of objects
    velocities,                \* Mapping objectId -> velocity vector
    positions,                 \* Mapping objectId -> position vector
    masses,                    \* Mapping objectId -> mass
    forces,                    \* Mapping objectId -> accumulated force vector
    collisionPairs,            \* Set of pairs of objectIds currently colliding
    time                       \* Current simulation time

TypeInvariant ==
    /\ objects \subset DOMAIN velocities
    /\ objects \subset DOMAIN positions
    /\ objects \subset DOMAIN masses
    /\ objects \subset DOMAIN forces
    /\ collisionPairs \subset SUBSET { [o1, o2] \in [objects \times objects] : o1 # o2 }
    /\ time \in Real
    /\ \A o \in objects : 
        velocities[o] \in [1..3 -> Real] /\
        positions[o] \in [1..3 -> Real] /\
        forces[o] \in [1..3 -> Real] /\
        masses[o] \in Real /\ masses[o] > 0

Init ==
    /\ objects = {"obj1", "obj2", "obj3"}
    /\ velocities = [o \in objects |-> [x |-> 0.0, y |-> 0.0, z |-> 0.0]]
    /\ positions = [o \in objects |-> [x |-> 0.0, y |-> 0.0, z |-> 0.0]]
    /\ forces = [o \in objects |-> [x |-> 0.0, y |-> 0.0, z |-> 0.0]]
    /\ masses = [o \in objects |-> 1.0]
    /\ collisionPairs = {}
    /\ time = 0.0

Next ==
    \E obj \in objects :
        let
            newVel := velocities[obj] + (forces[obj] /\ masses[obj]) * (dt / 1.0)
            newPos := positions[obj] + newVel * dt
            boundaryCheckX == 
                IF newPos[x] < boundaryMin[x] \/ newPos[x] > boundaryMax[x] THEN 
                    newVel[x] := -newVel[x] * elasticity
                    newPos[x] := 
                        IF newPos[x] < boundaryMin[x] THEN boundaryMin[x] ELSE boundaryMax[x]
                ELSE newVel[x]
            boundaryCheckY == 
                IF newPos[y] < boundaryMin[y] \/ newPos[y] > boundaryMax[y] THEN 
                    newVel[y] := -newVel[y] * elasticity
                    newPos[y] := 
                        IF newPos[y] < boundaryMin[y] THEN boundaryMin[y] ELSE boundaryMax[y]
                ELSE newVel[y]
            boundaryCheckZ == 
                IF newPos[z] < boundaryMin[z] \/ newPos[z] > boundaryMax[z] THEN 
                    newVel[z] := -newVel[z] * elasticity
                    newPos[z] := 
                        IF newPos[z] < boundaryMin[z] THEN boundaryMin[z] ELSE boundaryMax[z]
                ELSE newVel[z]
            updatedVel := [x \in 1..3 |-> CASE x = 1 -> boundaryCheckX[x]
                                              [] x = 2 -> boundaryCheckY[x]
                                              [] x = 3 -> boundaryCheckZ[x]]
        IN
        velocities' = [velocities EXCEPT ![obj] = updatedVel]
        positions' = [positions EXCEPT ![obj] = newPos]
        forces' = [o \in objects |-> [x |-> 0.0, y |-> 0.0, z |-> 0.0]]
    \Else
        velocities' = velocities
        positions' = positions
        forces' = forces
    collisionDetection =
        \E pair \in SUBSET objects : Cardinal(pair) = 2 /\ (pair \in collisionPairs) 
            OR
            LET
                o1 = pair[1]
                o2 = pair[2]
                deltaPos == positions[o1] - positions[o2]
                dist == Sqrt(deltaPos[x]*deltaPos[x] + deltaPos[y]*deltaPos[y] + deltaPos[z]*deltaPos[z])
                radiusSum == 0.5 + 0.5
            IN
                IF dist < radiusSum THEN
                    collisionPairs' = collisionPairs \cup {pair}
                ELSE
                    collisionPairs' = collisionPairs \ {pair}
    handleCollisions ==
        \A pair \in collisionPairs :
            LET
                o1 = pair[1]
                o2 = pair[2]
                deltaPos == positions[o1] - positions[o2]
                deltaVel == velocities[o1] - velocities[o2]
                dist == Sqrt(deltaPos[x]*deltaPos[x] + deltaPos[y]*deltaPos[y] + deltaPos[z]*deltaPos[z])
                normal == IF dist = 0 THEN [x |-> 0.0, y |-> 0.0, z |-> 1.0] ELSE deltaPos / dist
                v1n == Dot(velocities[o1], normal)
                v2n == Dot(velocities[o2], normal)
                m1 == masses[o1]
                m2 == masses[o2]
                v1n' == (v1n * (m1 - elasticity * m2) + (1 + elasticity) * m2 * v2n) / (m1 + m2)
                v2n' == (v2n * (m2 - elasticity * m1) + (1 + elasticity) * m1 * v1n) / (m1 + m2)
                deltaV1 == (v1n' - v1n) * normal
                deltaV2 == (v2n' - v2n) * normal
                velocities' == [velocities EXCEPT ![o1] = velocities[o1] + deltaV1]
                velocities' == [velocities' EXCEPT ![o2] = velocities[o2] + deltaV2]
            IN
                TRUE
    updateVelocities ==
        velocities'' = [o \in objects |-> 
            velocities[o] + (forces[o] /\ masses[o]) * (dt / 1.0) + airResistance * velocities[o]]
    applyFriction ==
        velocities''' = [o \in objects |-> 
            velocities''[o] * (1 - frictionCoefficient)]
    updateTime ==
        time' = time + dt
    UNCHANGED <<>>
    Next ==
        Init /\ TypeInvariant /\ 
        \E _ \in 1..100 : 
            \LET
                _1 = [Next]_1
            IN
                TRUE