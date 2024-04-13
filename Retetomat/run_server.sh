set -eux

cd framework/chall && ./build.sh
cd .. 
cargo r --release
