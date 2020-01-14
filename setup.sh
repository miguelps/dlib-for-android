#!/bin/bash
# Luca Anzalone
# Updates: Miguel Pari Soto

# -----------------------------------------------------------------------------
#   Compiles Dlib for android and copy dlib/opencv libs to android project
# -----------------------------------------------------------------------------

# OpenCV library path (compiled)
OPENCV_PATH=$HOME'/projects/opencv/build/OpenCV-android-sdk/sdk/native'

# Dlib library path (to compile)
DLIB_PATH=$HOME'/projects/dlib-for-android/dlib'

# Android project path (which will use these libs)
PROJECT_PATH=$HOME'/projects/android/android-face-landmarks'

# Directory to copy native libraries
NATIVE_DIR="$PROJECT_PATH/app/src/main/cppLibs"

# Android-cmake path
# ANDROID_CMAKE=$HOME'/Android/Sdk/cmake/3.10.2.4988404/bin/cmake'
ANDROID_CMAKE=$HOME'/Library/Android/Sdk/cmake/3.10.2.4988404/bin/cmake'

# Android-ndk path
NDK="${ANDROID_NDK:-$HOME/Android/Ndk}"

TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"

# Supported Android ABI: TAKE ONLY WHAT YOU NEED!
ABI=('armeabi-v7a' 'arm64-v8a' 'x86' 'x86_64')

# Minimum supported sdk (should be greater than 16)
MIN_SDK=16

# path to strip tool: REPLACE WITH YOURS, ACCORDING TO OS!!
STRIP_PATH="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"

# Declare the array
declare -a STRIP_TOOLS

STRIP_TOOLS=(
    ['armeabi-v7a']=$STRIP_PATH/arm-linux-androideabi-strip
    ['arm64-v8a']=$STRIP_PATH/aarch64-linux-android-strip
    ['x86']=$STRIP_PATH/x86_64-linux-android-strip
    ['x86_64']=$STRIP_PATH/x86_64-linux-android-strip
)

# -----------------------------------------------------------------------------
#   Dlib compilation
# -----------------------------------------------------------------------------

function compile_dlib {
    cd $DLIB_PATH

    echo '=> Compiling Dlib...'

    for abi in "${ABI[@]}"
    do
        echo
        echo "=> Compiling Dlib for ABI: '$abi'..."

        mkdir -p "build/$abi"
        cd "build/$abi"

        $ANDROID_CMAKE -DBUILD_SHARED_LIBS=1 \
                       -DANDROID_NDK=$NDK \
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

        echo "=> Stripping libdlib.so for ABI: '$abi'to reduce lib size..."
        ${STRIP_TOOLS[$abi]} --strip-unneeded dlib/libdlib.so

        echo '=> done.'
        cd ../../
    done
}

# -----------------------------------------------------------------------------
#   Copy/setup Dlib lib
# -----------------------------------------------------------------------------

function dlib_setup {
    echo
    echo '=> Making directory for dlib include (headers)'
    # mkdir "$NATIVE_DIR/dlib/include/dlib"
    # echo "=> '$NATIVE_DIR/dlib/include/dlib' created."
    mkdir -p "$NATIVE_DIR/dlib/include"
    echo "=> '$NATIVE_DIR/dlib/include' created."

    echo "=> Copying dlib headers..."
    # cp -v -r "$DLIB_PATH/dlib" "$NATIVE_DIR/dlib/include/dlib"
    cp -r "$DLIB_PATH/dlib/." "$NATIVE_DIR/dlib/include/."

    echo "=> Copying 'libdlib.so' for each ABI..."
    for abi in "${ABI[@]}"
    do
        mkdir -p "$NATIVE_DIR/dlib/lib/$abi"
        cp "$DLIB_PATH/build/$abi/dlib/libdlib.so" "$NATIVE_DIR/dlib/lib/$abi"
        echo " > Copied libdlib.so for $abi"
    done
}

# -----------------------------------------------------------------------------
#   Copy/setup OpenCV lib
# -----------------------------------------------------------------------------

function opencv_setup {
    echo
    echo '=> Making directory for opencv include (headers)'
    mkdir -p "$NATIVE_DIR/opencv/include"
    echo "=> '$NATIVE_DIR/opencv/include' created."

    echo "=> Copying opencv headers..."
    cp -r "$OPENCV_PATH/jni/include" "$NATIVE_DIR/opencv/."

    echo "=> Copying 'libopencv_java4.so' for each ABI..."
    for abi in "${ABI[@]}"
    do
        mkdir -p "$NATIVE_DIR/opencv/lib/$abi"
        cp "$OPENCV_PATH/libs/$abi/libopencv_java4.so" "$NATIVE_DIR/opencv/lib/$abi"
        echo " > Copied libopencv_java4.so for $abi"
    done
}

mkdir -p $NATIVE_DIR

# -----------------------------------------------------------------------------
#   Project setup
# -----------------------------------------------------------------------------

compile_dlib

dlib_setup

opencv_setup

echo
echo "=> Project configuration completed."

# -----------------------------------------------------------------------------
