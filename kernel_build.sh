#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
#

# Needed Secret Variable
# KERNEL_NAME | Your kernel name
# KERNEL_SOURCE | Your kernel link source
# KERNEL_BRANCH  | Your needed kernel branch if needed with -b. eg -b eleven_eas
# DEVICE_CODENAME | Your device codename
# DEVICE_DEFCONFIG | Your device defconfig eg. lavender_defconfig
# ANYKERNEL | Your Anykernel link repository
# TG_TOKEN | Your telegram bot token
# TG_CHAT_ID | Your telegram private ci chat id
# BUILD_USER | Your username
# BUILD_HOST | Your hostname

echo "Downloading few Dependecies . . ."
# Kernel Sources
cd ~
git clone --depth=1 $KERNEL_SOURCE $KERNEL_BRANCH ~/lava
cd ~/lava
  mkdir "$OUTDIR"/clang-llvm
  mkdir "$OUTDIR"/gcc64-aosp
  mkdir "$OUTDIR"/gcc32-aosp
  ! [[ -f "$OUTDIR"/clang-r383902b1.tar.gz ]] && wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android11-qpr3-release/clang-r383902b1.tar.gz -P "$OUTDIR"
  tar -C "$OUTDIR"/clang-llvm/ -zxvf "$OUTDIR"/clang-r383902b1.tar.gz
  ! [[ -f "$OUTDIR"/android-11.0.0_r35.tar.gz ]] && wget https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/android-11.0.0_r35.tar.gz -P "$OUTDIR"
  tar -C "$OUTDIR"/gcc64-aosp/ -zxvf "$OUTDIR"/android-11.0.0_r35.tar.gz
  ! [[ -f "$OUTDIR"/android-11.0.0_r34.tar.gz ]] && wget http://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/android-11.0.0_r34.tar.gz -P "$OUTDIR"
  tar -C "$OUTDIR"/gcc32-aosp/ -zxvf "$OUTDIR"/android-11.0.0_r34.tar.gz
# clang set as Clang Default

# Main Declaration
export DEFCONFIG=lancelot_defconfig
export TZ="Asia/Jakarta"
export KERNEL_DIR=$(pwd)/lava
export ZIPNAME="KucingKernel"
export IMAGE="${OUTDIR}/arch/arm64/boot/Image.gz-dtb"
export DATE=$(date "+%m%d")
export BRANCH="$(git rev-parse --abbrev-ref HEAD)"
export PATH="${OUTDIR}/clang-llvm/bin:${OUTDIR}/gcc64-aosp/bin:${OUTDIR}/gcc32-aosp/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(${OUTDIR}/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
export ARCH=arm64
export KBUILD_BUILD_USER=kucingabu
export HASH_HEAD=$(git rev-parse --short HEAD)
export COMMIT_HEAD=$(git log --oneline -1)
export PROCS=$(nproc --all)
export DISTRO=$(cat /etc/issue)
export KERVER=$(make kernelversion)

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function check() {
echo ================================================
echo KernelCompiler
echo version : rev1.5 - gaspoll
echo ================================================
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo CLANG_ROOTDIR = ${CLANG_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Post Main Information
tg_post_msg "<b>xKernelCompiler</b>%0ABuilder Name : <code>${KBUILD_BUILD_USER}</code>%0ABuilder Host : <code>${KBUILD_BUILD_HOST}</code>%0ADevice Defconfig: <code>${DEVICE_DEFCONFIG}</code>%0AClang Version : <code>${KBUILD_COMPILER_STRING}</code>%0AClang Rootdir : <code>${CLANG_ROOTDIR}</code>%0AKernel Rootdir : <code>${KERNEL_ROOTDIR}</code>"

# Compile
compile(){
tg_post_msg "<b>xKernelCompiler:</b><code>Compilation has started</code>"
cd ${KERNEL_ROOTDIR}
  make O="$OUTDIR" ARCH=arm64 lancelot_defconfig
  make -j"$PROCS" O="$OUTDIR" \
                  ARCH=arm64 \
                  CC=clang \
                  CLANG_TRIPLE=aarch64-linux-gnu- \
                  CROSS_COMPILE=aarch64-linux-android- \
                  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                  LD=ld.lld \
                  NM=llvm-nm \
                  OBJCOPY=llvm-objcopy

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 $ANYKERNEL AnyKernel
	cp $IMAGE AnyKernel
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$DEVICE_CODENAME</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build throw an error(s)"
    exit 1
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 $KERNEL_NAME-$DEVICE_CODENAME-${DATE}.zip *
    cd ..
}
check
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
