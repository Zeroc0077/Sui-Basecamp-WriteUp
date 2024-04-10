set -eux

cd framework/chall && sui move build
#&& ./build.sh
cd .. 
cargo r --release
