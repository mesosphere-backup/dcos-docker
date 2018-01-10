#!/usr/bin/env bash

set -o nounset -o pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE}")" && pwd -P)
cd "${project_dir}"

semverTest() {
local A=R1.3.2
local B=R2.3.2
local C=R1.4.2
local D=R1.3.3
local E=R1.3.2a
local F=R1.3.2b
local G=R1.2.3

echo "Equality comparisons"
./testver.sh $A -eq $A
echo "$A == $A -> $?. Expect 0."

./testver.sh $A -lt $A
echo "$A < $A -> $?. Expect 1."

./testver.sh $A -gt $A
echo "$A > $A -> $?. Expect 1."


echo "Major number comparisons"
./testver.sh $A -eq $B
echo "$A == $B -> $?. Expect 1."

./testver.sh $A -lt $B
echo "$A < $B -> $?. Expect 0."

./testver.sh $A -gt $B
echo "$A > $B -> $?. Expect 1."

./testver.sh $B -eq $A
echo "$B == $A -> $?. Expect 1."

./testver.sh $B -lt $A
echo "$B < $A -> $?. Expect 1."

./testver.sh $B -gt $A
echo "$B > $A -> $?. Expect 0."


echo "Minor number comparisons"
./testver.sh $A -eq $C
echo "$A == $C -> $?. Expect 1."

./testver.sh $A -lt $C
echo "$A < $C -> $?. Expect 0."

./testver.sh $A -gt $C
echo "$A > $C -> $?. Expect 1."

./testver.sh $C -eq $A
echo "$C == $A -> $?. Expect 1."

./testver.sh $C -lt $A
echo "$C < $A -> $?. Expect 1."

./testver.sh $C -gt $A
echo "$C > $A -> $?. Expect 0."

echo "patch number comparisons"
./testver.sh $A -eq $D
echo "$A == $D -> $?. Expect 1."

./testver.sh $A -lt $D
echo "$A < $D -> $?. Expect 0."

./testver.sh $A -gt $D
echo "$A > $D -> $?. Expect 1."

./testver.sh $D -eq $A
echo "$D == $A -> $?. Expect 1."

./testver.sh $D -lt $A
echo "$D < $A -> $?. Expect 1."

./testver.sh $D -gt $A
echo "$D > $A -> $?. Expect 0."

echo "special section vs no special comparisons"
./testver.sh $A -eq $E
echo "$A == $E -> $?. Expect 1."

./testver.sh $A -lt $E
echo "$A < $E -> $?. Expect 1."

./testver.sh $A -gt $E
echo "$A > $E -> $?. Expect 0."

./testver.sh $E -eq $A
echo "$E == $A -> $?. Expect 1."

./testver.sh $E -lt $A
echo "$E < $A -> $?. Expect 0."

./testver.sh $E -gt $A
echo "$E > $A -> $?. Expect 1."

echo "special section vs special comparisons"
./testver.sh $E -eq $F
echo "$E == $F -> $?. Expect 1."

./testver.sh $E -lt $F
echo "$E < $F -> $?. Expect 0."

./testver.sh $E -gt $F
echo "$E > $F -> $?. Expect 1."

./testver.sh $F -eq $E
echo "$F == $E -> $?. Expect 1."

./testver.sh $F -lt $E
echo "$F < $E -> $?. Expect 1."

./testver.sh $F -gt $E
echo "$F > $E -> $?. Expect 0."

echo "Minor and patch number comparisons"
./testver.sh $A -eq $G
echo "$A == $G -> $?. Expect 1."

./testver.sh $A -lt $G
echo "$A < $G -> $?. Expect 1."

./testver.sh $A -gt $G
echo "$A > $G -> $?. Expect 0."

./testver.sh $G -eq $A
echo "$G == $A -> $?. Expect 1."

./testver.sh $G -lt $A
echo "$G < $A -> $?. Expect 0."

./testver.sh $G -gt $A
echo "$G > $A -> $?. Expect 1."
}

semverTest
