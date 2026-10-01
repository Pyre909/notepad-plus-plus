#!/bin/sh
# final.sh: all the Stage 2 (search results, incremental search bar, Document Map, docked UDL) runs on the final binaries
#  1. setting OFF, normal builds: baseline (9fc893a, base-app), main checkout build, new build (new-app), Wine DPI 96 and 144,
#     wrapped and not wrapped main view: captures and geometry compared
#  2. throwaway test build (test-app, NPP_TEST_PMV2=1): synthetic WM_DPICHANGED 96 -> 144 -> 96 (+ WM_DPICHANGED_AFTERPARENT
#     to all the descendants, top-down), several scenarios
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
echo "######## 1. setting OFF"
./offcmp.sh 96 --size 1900 1150 --wrap 2>&1 | sed -n '/==== geometry/,$p'
rm -rf off96-wrap; mv off96 off96-wrap
./offcmp.sh 96 --size 1600 1000 2>&1 | sed -n '/==== geometry/,$p'
./offcmp.sh 144 --size 1900 1150 --wrap 2>&1 | sed -n '/==== geometry/,$p'
echo "######## 2. synthetic DPI changes (test build)"
rm -rf syn; mkdir -p syn
NPP_TEST_PMV2=1 ./run.sh test-app syn/set-all syn 96 all --synthetic 144 --size 1900 1150 | grep -v launch
NPP_TEST_PMV2=1 ./run.sh test-app syn/set-wrap syn 96 wrap --synthetic 144 --size 1900 1150 --wrap | grep -v launch
NPP_TEST_PMV2=1 ./run.sh test-app syn/set-scroll syn 96 udlscroll --synthetic 144 --size 1900 800 --wrap --udl-scroll | grep -v launch
NPP_TEST_PMV2=1 ./run.sh test-app syn/set-finders syn 96 finders --synthetic 144 --size 1900 1150 --wrap --no-udl --finder2 | grep -v launch
NPP_TEST_PMV2=1 ./run.sh test-app syn/set-144 syn 144 from144 --synthetic 96 --size 1900 1150 --wrap | grep -v launch
