# Updates: Miguel Pari Soto

# -----------------------------------------------------------------------------
#   Compiles Dlib for android and copy dlib/opencv libs to android project
# -----------------------------------------------------------------------------

min_bash_version=4
bash_version=${BASH_VERSION%%[^0-9]*}

if [ "$bash_version" -lt "$min_bash_version" ]
then
  echo ""
  echo "Oh, ... bugger. This script requires bash > "${min_bash_version}"."
  echo -e ${RED}"Your bash version is "${RESET}${BASH_VERSION}
  echo ""
  exit 1;
fi

# OpenCV library path (already compiled)
OPENCV_PATH=$HOME'/projects/opencv/build/OpenCV-android-sdk/sdk/native'

# Dlib library source path (to compile)
DLIB_PATH=$PWD'/dlib'

# Directory to copy native libraries
OUTPUT_NATIVE_DIR=$HOME'/idwall/android_libs'

# Needs $ANDROID_NDK pointing Android-ndk path
TOOLCHAIN="$ANDROID_NDK/build/cmake/android.toolchain.cmake"

# Minimum supported sdk (should be greater than 16)
MIN_SDK=16

# Paths cmake and strip tool
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    ANDROID_CMAKE=$HOME'/Android/Sdk/cmake/3.10.2.4988404/bin/cmake'
    STRIP_PATH=$ANDROID_NDK'/toolchains/llvm/prebuilt/linux-x86_64/bin'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    ANDROID_CMAKE=$HOME'/Library/Android/Sdk/cmake/3.10.2.4988404/bin/cmake'
    STRIP_PATH=$ANDROID_NDK'/toolchains/llvm/prebuilt/darwin-x86_64/bin'
fi

# Supported Android ABI: TAKE ONLY WHAT YOU NEED!
ABI=('armeabi-v7a' 'arm64-v8a' 'x86' 'x86_64')

# Array for lib strippers for all architectures
declare -A STRIP_TOOLS=(
    ['armeabi-v7a']=$STRIP_PATH/arm-linux-androideabi-strip
    ['arm64-v8a']=$STRIP_PATH/aarch64-linux-android-strip
    ['x86']=$STRIP_PATH/x86_64-linux-android-strip
    ['x86_64']=$STRIP_PATH/x86_64-linux-android-strip
)

# -----------------------------------------------------------------------------
#   Dlib compilation
# -----------------------------------------------------------------------------

function compile_dlib {
    echo '=> Compiling Dlib...'

    for abi in "${ABI[@]}"
    do
        echo
        echo "=> Compiling Dlib for ABI: '$abi'..."

        mkdir -p "$DLIB_PATH/build/$abi"
        cd "$DLIB_PATH/build/$abi"

        $ANDROID_CMAKE -DBUILD_SHARED_LIBS=1 \
                       -DANDROID_NDK=$ANDROID_NDK \
                       -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN \
                       -DCMAKE_BUILD_TYPE=Release \
                       -DCMAKE_CXX_FLAGS="-std=c++11 -frtti -fexceptions" \
                       -DCMAKE_C_FLAGS=-O3 \
                       -DANDROID_ABI=$abi \
                       -DANDROID_PLATFORM="android-$MIN_SDK" \
                       -DANDROID_TOOLCHAIN=clang \
                       -DANDROID_STL=c++_shared \
                       -DANDROID_CPP_FEATURES=rtti exceptions \
                       -DCMAKE_PREFIX_PATH=../../ \
                       ../../

        echo "=> Generating the 'dlib/libdlib.so' for ABI: '$abi'..."
        $ANDROID_CMAKE --build .
    done
}

# -----------------------------------------------------------------------------
#   Copy/strip/setup Dlib lib
# -----------------------------------------------------------------------------

function dlib_setup {
    echo
    mkdir -p "$OUTPUT_NATIVE_DIR/dlib/include"

    echo "=> Copying dlib headers"
    cp -r "$DLIB_PATH/dlib/." "$OUTPUT_NATIVE_DIR/dlib/include/."

    echo "=> Copying and stripping 'libdlib.so' for each ABI..."
    for abi in "${ABI[@]}"
    do
        echo " > ABI: '$abi' "
        mkdir -p "$OUTPUT_NATIVE_DIR/dlib/lib/$abi"
        cp "$DLIB_PATH/build/$abi/dlib/libdlib.so" "$OUTPUT_NATIVE_DIR/dlib/lib/$abi"
        cd "$OUTPUT_NATIVE_DIR/dlib/lib/$abi"
        ${STRIP_TOOLS[$abi]} --strip-unneeded libdlib.so
    done
}

# -----------------------------------------------------------------------------
#   Copy/setup OpenCV lib
# -----------------------------------------------------------------------------

function opencv_setup {
    echo
    mkdir -p "$OUTPUT_NATIVE_DIR/opencv/include"

    echo "=> Copying opencv headers"
    cp -r "$OPENCV_PATH/jni/include" "$OUTPUT_NATIVE_DIR/opencv/."

    echo "=> Copying 'libopencv_java4.so' for each ABI..."
    for abi in "${ABI[@]}"
    do
        echo " > ABI: '$abi' "
        mkdir -p "$OUTPUT_NATIVE_DIR/opencv/lib/$abi"
        cp "$OPENCV_PATH/libs/$abi/libopencv_java4.so" "$OUTPUT_NATIVE_DIR/opencv/lib/$abi"
    done
}

# -----------------------------------------------------------------------------
#   Project setup
# -----------------------------------------------------------------------------

compile_dlib

dlib_setup

opencv_setup

echo
echo "=> Project configuration completed."

# -----------------------------------------------------------------------------
